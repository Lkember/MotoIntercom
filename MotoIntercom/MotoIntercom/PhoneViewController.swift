//
//  PhoneViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-12-18.
//  Copyright © 2016 Logan Kember. All rights reserved.
//
//  This may be helpful when trying to play from the livestream
//  https://developer.apple.com/library/content/samplecode/HLSCatalog/Introduction/Intro.html#//apple_ref/doc/uid/TP40017320-Intro-DontLinkElementID_2
//  http://stackoverflow.com/questions/33245063/swift-2-avfoundation-recoding-realtime-audio-samples

import UIKit
import AVFoundation
import MultipeerConnectivity
import JSQMessagesViewController

class PhoneViewController: UIViewController, AVAudioRecorderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, StreamDelegate, ConnectionManagerDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let incomingCall = "_incoming_call_"
    
    // MARK: - Properties
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var endCallButton: UIButton!
    var nilButton: UIButton = UIButton.init()
    
    // MC
    var peerID: MCPeerID?
    var sessionIndex: Int?
    var isConnecting: Bool = false
    
    // Streams
    var outputStream: OutputStream?
    var outputStreamIsSet: Bool = false
    var inputStream: InputStream?
    var inputStreamIsSet: Bool = false
    
    var testBufferCount = 0
    var testBuffer: [UInt8] = .init(repeating: 0, count: 0)
    
    // Timer
    var startTime = NSDate.timeIntervalSinceReferenceDate
    var timer: Timer?
    
    //Thread
    var recordingQueue = DispatchQueue(label: "recordingQueue", qos: DispatchQoS.userInteractive)
    var localPlayerQueue = DispatchQueue(label: "localPlayerQueue", qos: DispatchQoS.userInteractive)
    var receivingQueue = DispatchQueue(label: "receivingQueue", qos: DispatchQoS.userInteractive)
    var audioPlayerQueue = DispatchQueue(label: "audioPlayerQueue", qos: DispatchQoS.userInteractive)
    
    // Audio Capture and Playing
    var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    var localAudioEngine: AVAudioEngine = AVAudioEngine()
    var localAudioPlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    var localInput: AVAudioInputNode?
    var localInputFormat: AVAudioFormat?
    
    var peerAudioEngine: AVAudioEngine = AVAudioEngine()
    var peerAudioPlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    var peerInput: AVAudioInputNode?
    var peerInputFormat: AVAudioFormat?
    
    // Button Options
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    
    var muteIsOn = false
    var speakerIsOn = false
    
    // User ended call
    var userEndedCall = false
    
    // MARK: - View Methods
    
    override func viewDidLoad() {
        print("\(#file) > \(#function) > Entry")
        
        super.viewDidLoad()
        
        if (isConnecting) {
            timerLabel.text = "Connecting to \(peerID!.displayName)..."
        }
        else {
            timerLabel.text = "Calling \(peerID!.displayName)..."
        }
        
        // When the device is up to the ear, the screen will dim
        UIDevice.current.isProximityMonitoringEnabled = true
        
        // Stop advertising and browsing for peers when in a call
//        self.appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
//        self.appDelegate.connectionManager.browser.stopBrowsingForPeers()
        
        // Setting up AVAudioSession
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: [AVAudioSessionCategoryOptions.allowBluetooth])
            try audioSession.setPreferredIOBufferDuration(0.04)
            try audioSession.setPreferredInputNumberOfChannels(1)
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setMode(AVAudioSessionModeVoiceChat)
            try audioSession.setActive(true)
            
            print("\(#file) > \(#function) > audioSession \(audioSession)")
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > Error encountered: \(error)")
        }
        
        
        // Giving the background view a blur effect
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.insertSubview(blurEffectView, at: 0)
        
        // Making the buttons circular
//        muteButton.buttonType = UIButtonType.roundedRect
//        speakerButton.buttonType = UIButtonType.roundedRect
        let muteImage: UIImage = UIImage.init(named: "Mute-50.png")!
        muteButton.setImage(muteImage, for: UIControlState.normal)
        muteButton.layer.cornerRadius = muteButton.frame.width/2
        muteButton.layer.borderWidth = 1
        muteButton.layer.borderColor = UIColor.black.cgColor
        
        let speakerImage: UIImage = UIImage.init(named: "High Volume-50.png")!
        speakerButton.setImage(speakerImage, for: UIControlState.normal)
        speakerButton.layer.cornerRadius = speakerButton.frame.width/2
        speakerButton.layer.borderWidth = 1
        speakerButton.layer.borderColor = UIColor.black.cgColor
//        speakerButton.backgroundColor = UIColor.gray
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(errorReceivedWhileRecording), name: NSNotification.Name(rawValue: "AVCaptureSessionRuntimeError"), object: nil)
        
        // Setting the connectionManager delegate to self
        appDelegate.connectionManager.delegate = self
        
        //-------------------------------------------------------------------------------
        // Calling peer
        
        recordingQueue.sync {
        
            self.sessionIndex = self.appDelegate.connectionManager.findSinglePeerSession(peer: self.peerID!)
            
            // sessionIndex is -1 then we are not connected to peer, so send invite
            if (self.sessionIndex == -1) {
                print("\(#file) > \(#function) > Sending call invitation to peer.")
                self.sessionIndex = self.appDelegate.connectionManager.createNewSession()
                
                let isPhoneCall: Bool = true
                let dataToSend : Data = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
                
                self.appDelegate.connectionManager.browser.invitePeer(self.peerID!,
                                                                      to: self.appDelegate.connectionManager.sessions[self.sessionIndex!],
                                                                      withContext: dataToSend,
                                                                      timeout: 30)
            }
            else {
                print("\(#file) > \(#function) > Sending message to peer.")
                
                let jsqMessage = JSQMessage.init(senderId: self.appDelegate.connectionManager.uniqueID,
                                                 displayName: self.appDelegate.connectionManager.peer.displayName,
                                                 text: self.incomingCall)
                
                let phoneMessage = MessageObject.init(peerID: self.appDelegate.connectionManager.sessions[self.sessionIndex!].connectedPeers[0],
                                                      messages: [jsqMessage!])
                
                // Attempt to send phone message
                if (!self.appDelegate.connectionManager.sendData(message: phoneMessage, toPeer: self.appDelegate.connectionManager.sessions[self.sessionIndex!].connectedPeers[0])) {
                    
                    print("\(#file) > \(#function) > Failed to send call invitation to peer")
                    self.timerLabel.text = "Call Failed"
                    
                    //TODO: Play a beeping sound to let the user know the call failed
                    
                    // Wait 2 seconds and then end call
                    sleep(2)
                    self.endCallButtonIsClicked(self.nilButton)
                }
            }
        
            //-------------------------------------------------------------------------------
            // Attempting to create outputStream. This will only be called if the current peer is already connected to.
            // This code is necessary since the user may already be connected to because of chat.
            
            if (self.appDelegate.connectionManager.checkIfAlreadyConnected(peerID: self.peerID!)) {
                do {
                    self.outputStream = try self.appDelegate.connectionManager.sessions[self.sessionIndex!].startStream(withName: "motoIntercom", toPeer: self.peerID!)
                    self.outputStreamIsSet = true
                }
                catch let error as NSError {
                    print("\(#file) > \(#function) > Failed to create outputStream: \(error.localizedDescription)")
                    self.outputStreamIsSet = false
                }
            }
        }
        
        self.navigationController?.navigationBar.isHidden = true
        
        self.prepareAudio()
        
        // Setting up the AVRecorder (but not yet recording)
//        recordingQueue.async {
//            if (self.outputStreamIsSet) {
//                print("\(#file) > \(#function) > Stetting up recorder")
//                self.setupAVRecorder()
//            }
//        }
    
        print("\(#file) > \(#function) > Exit")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Dispatch Queue
    
    func currentQueueName() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)!
    }
    
    
    // MARK: - Recording/Playing
    
    func prepareAudio() {
        // Setting up audio engine for local recording and sounds
        recordingQueue.sync {
            self.localInput = self.localAudioEngine.inputNode
            self.localAudioEngine.attach(self.localAudioPlayer)
            self.localInputFormat = self.localInput?.inputFormat(forBus: 0)
            self.localInputFormat = AVAudioFormat.init(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)
            self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: self.localInputFormat)
            
            print("\(#file) > \(#function) > localInputFormat = \(self.localInputFormat.debugDescription)")
        }
        
        self.audioPlayerQueue.sync {
            self.peerInput = self.peerAudioEngine.inputNode
            self.peerAudioEngine.attach(self.peerAudioPlayer)
            self.peerInputFormat = self.peerInput?.inputFormat(forBus: 1)
            self.peerInputFormat = AVAudioFormat.init(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)
            self.peerAudioEngine.connect(self.peerAudioPlayer, to: self.peerAudioEngine.mainMixerNode, format: self.peerInputFormat)
            
            print("\(#file) > \(#function) > peerInputFormat = \(self.peerInputFormat.debugDescription)")
        }
        
        print("\(#file) > \(#function) > Starting localAudioEngine")
        localPlayerQueue.sync {
            do {
                try self.localAudioEngine.start()
            }
            catch let error as NSError {
                print("\(#file) > \(#function) > Error starting audio engine: \(error.localizedDescription)")
            }
            
            //            self.localAudioPlayer.volume = 0.75
            //            self.localAudioPlayer.play()
        }
    
        print("\(#file) > \(#function) > Setting up peerAudioEngine")
        if (!peerAudioEngine.isRunning) {
            do {
                try self.peerAudioEngine.start()
                self.peerAudioPlayer.play()
            }
            catch let error as NSError {
                print("\(#file) > \(#function) > error: \(error.localizedDescription)")
            }
        }
        
    }
    
    func recordAudio() {
        
        localPlayerQueue.sync {
            localInput?.installTap(onBus: 0, bufferSize: 4410, format: localInputFormat) {
                (buffer, when) -> Void in
                
                // the audio being sent will be played locally as well
                //            self.localPlayerQueue.async {
                //                self.localAudioPlayer.scheduleBuffer(buffer)
                //            }
                
                let data = self.audioBufferToNSData(PCMBuffer: buffer)
                
                print("\(#file) > \(#function) > frameLength = \(buffer.frameLength), frameCapacity = \(buffer.frameCapacity), data.length = \(data.length)")
                //            let output = self.outputStream!.write(data.bytes.assumingMemoryBound(to: UInt8.self), maxLength: data.length)
                let output = self.outputStream!.write(data.bytes.bindMemory(to: UInt8.self, capacity: data.length), maxLength: data.length)
                
                if output > 0 {
                    print("\(#file) > \(#function) > \(output) bytes written")
                }
                else if output == -1 {
                    let error = self.outputStream!.streamError
                    print("\(#file) > \(#function) > Error writing to stream: \(String(describing: error?.localizedDescription))")
                }
                else {
                    print("\(#file) > \(#function) > Cannot write to stream, stream is full")
                }
            }
        }
    }
    
    func audioBufferToNSData(PCMBuffer: AVAudioPCMBuffer) -> NSData {
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: channelCount)
//        let data = NSData(bytes: channels[0], length:Int(PCMBuffer.frameCapacity * PCMBuffer.frameLength))
        let data = NSData(bytes: channels[0], length:Int(PCMBuffer.frameLength * PCMBuffer.format.streamDescription.pointee.mBytesPerFrame))
        
//        print("\(#file) > \(#function) > data: \(data.length), frameLength: \(PCMBuffer.frameLength), frameCapacity: \(PCMBuffer.frameCapacity), bytes per frame: \(PCMBuffer.format.streamDescription.pointee.mBytesPerFrame)")
        
        return data
    }
    
    func errorReceivedWhileRecording() {
        print("\(#file) > \(#function) > Error")
    }
    
    func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        if recorder.isRecording {
            recorder.pause()
            // TODO: Stop timer
        }
    }
    
    func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        if (inputStreamIsSet && outputStreamIsSet) {
            recorder.record()
            // TODO: Resume timer
        }
    }
    
    
    // MARK: - Timer
    
    // Used to display how long the call has been going on for
    func updateTime() {
        print("\(#file) > \(#function) > Running...")
        if (outputStreamIsSet && inputStreamIsSet) {
            let currentTime = NSDate.timeIntervalSinceReferenceDate
            
            var elapsedTime = currentTime - startTime
            
            let minutes = UInt8(elapsedTime / 60)
            elapsedTime -= (TimeInterval(minutes) * 60)
            
            let seconds = UInt8(elapsedTime)
            
            let minuteString = String(format: "%02d", minutes)
            let secondString = String(format: "%02d", seconds)
            
            timerLabel.text = "\(minuteString):\(secondString)"
            
            let second = Int(secondString)
            
            if (second! % 10 == 0) {
                print("\(#file) > \(#function) > Timer updated to \(minuteString):\(secondString)")
            }
        }
    }
    
    
    // MARK: - Stream
    
    func setupStream() {
        print("\(#file) > \(#function) > Creating output stream")
        
        if (!outputStreamIsSet) {
            do {
                outputStream = try self.appDelegate.connectionManager.sessions[sessionIndex!].startStream(withName: "motoIntercom", toPeer: peerID!)
                outputStreamIsSet = true
            }
            catch let error as NSError {
                print("\(#file) > \(#function) > Failed to create outputStream: \(error.localizedDescription)")
                
                endCallButtonIsClicked(nilButton)
            }
        }
        
        print("\(#file) > \(#function) > Exit - Queue: \(currentQueueName()!)")
    }
    
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode) {
        case Stream.Event.errorOccurred:
            print("\(#file) > \(#function) > Error has occurred on input stream")
            
            
        case Stream.Event.hasBytesAvailable:
            DispatchQueue.global().sync {
                
                let availableCount = 8820-self.testBufferCount
                
                var tempBuffer: [UInt8] = .init(repeating: 0, count: availableCount)
                let length = self.inputStream!.read(&tempBuffer, maxLength: availableCount)
                
                if (tempBuffer.count != length) {
                    tempBuffer = [UInt8](tempBuffer.dropLast(tempBuffer.count - length))
                }
                
                self.testBufferCount += length
                self.testBuffer.append(contentsOf: tempBuffer)
                
                print("\(#file) > \(#function) > Size of buffer: \(self.testBufferCount), amount read: \(length), available: \(availableCount - length), buffer size = \(self.testBuffer.count)")
            
                if (self.testBufferCount >= 8820) {
//                    print("\(#file) > \(#function) > Test buffer full, testBuffer.count = \(self.testBuffer.count), testBufferCount = \(self.testBufferCount)")
                    let data = NSData.init(bytes: &self.testBuffer, length: self.testBufferCount)
                    let audioBuffer = self.dataToPCMBuffer(data: data)
                        
                    self.peerAudioPlayer.scheduleBuffer(audioBuffer, completionHandler: nil)
                    
                    self.testBuffer.removeAll()
                    self.testBufferCount = 0
                }
            }
        
        case Stream.Event.hasSpaceAvailable:
            print("\(#file) > \(#function) > Space available")
            
            
        case Stream.Event.endEncountered:
            print("\(#file) > \(#function) > End encountered")
//            endCallButtonIsClicked(nilButton)
            
            
        case Stream.Event.openCompleted:
            print("\(#file) > \(#function) > Open completed")
        
            
        default:
            print("\(#file) > \(#function) > Other")
        }
    }
    
    func dataToPCMBuffer(data: NSData) -> AVAudioPCMBuffer {
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)  // given NSData audio format
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(data.length) / audioFormat.streamDescription.pointee.mBytesPerFrame)
        
//        print("\(#file) > \(#function) > audioBuffer frameCapacity = \(audioBuffer.frameCapacity)")
        
        audioBuffer.frameLength = audioBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: audioBuffer.floatChannelData, count: Int(audioBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return audioBuffer
    }
    
    
    //MARK: - Button Actions
    
    @IBAction func muteButtonIsTouched(_ sender: Any) {
        if (!muteIsOn) {
            muteIsOn = true
            
            // Make the button look gray
            DispatchQueue.main.sync {
                self.muteButton.backgroundColor = UIColor.gray
                self.muteButton.backgroundColor?.withAlphaComponent(0.5)
            }
        }
        else {
            muteIsOn = false
            
            // Make button go back to black
            DispatchQueue.main.sync {
                self.muteButton.backgroundColor = UIColor.black
                self.muteButton.backgroundColor?.withAlphaComponent(1)
            }
        }
        
        print("\(#file) > \(#function) > mute: \(muteIsOn)")
    }
    
    @IBAction func speakerButtonIsTouched(_ sender: Any) {
        if (!speakerIsOn) {
            speakerIsOn = true
            
            // Make the button look gray
            DispatchQueue.main.sync {
                do {
                    try self.audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
                }
                catch let error as NSError {
                    print("\(#file) > \(#function) > Could not change to speaker: \(error.description)")
                }
                self.speakerButton.backgroundColor = UIColor.gray
                self.speakerButton.backgroundColor?.withAlphaComponent(0.5)
            }
        }
        else {
            speakerIsOn = false
            
            // Make button go back to black
            DispatchQueue.main.sync {
                self.speakerButton.backgroundColor = UIColor.black
                self.speakerButton.backgroundColor?.withAlphaComponent(1)
            }
        }
        
        print("\(#file) > \(#function) > speaker: \(speakerIsOn)")
    }
    
    @IBAction func endCallButtonIsClicked(_ sender: UIButton) {
        if (sender == nilButton) {
            userEndedCall = false
        }
        else {
            userEndedCall = true
        }
        
        print("\(#file) > \(#function) > Stopping recording")
        
        OperationQueue.main.addOperation {
            self.closeAllResources()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    // A function which stops recording and closes streams
    func closeAllResources() {
        print("\(#file) > \(#function) > Closing resources")
        
        //Stop recording and playing
        if localAudioEngine.isRunning {
            localAudioEngine.stop()
        }
        
        if localAudioPlayer.isPlaying {
            localAudioPlayer.stop()
        }
        
        if peerAudioEngine.isRunning {
            peerAudioEngine.stop()
        }
        
        if peerAudioPlayer.isPlaying {
            peerAudioPlayer.stop()
        }
        
        // Stop the timer
        timer?.invalidate()
        
        // Close the output stream
        outputStream?.close()
        inputStream?.close()
        
        inputStreamIsSet = false
        outputStreamIsSet = false
        
        UIDevice.current.isProximityMonitoringEnabled = false
        
        // Disconnect from peer. This way the other user will be notified that the call has ended.
        if (appDelegate.connectionManager.checkIfAlreadyConnected(peerID: self.peerID!)) {
            appDelegate.connectionManager.sessions[sessionIndex!].disconnect()
        }
        else {
            print("\(#file) > \(#function) > Not connected to peer")
        }
        
        print("\(#file) > \(#function) > Resources closed")
    }
    
    
    // MARK: - ConnectionManagerDelegate
    func foundPeer(_ newPeer : MCPeerID) {
        // nothing to do
        print("\(#file) > \(#function) > \(newPeer.displayName)")
    }
    
    func lostPeer(_ lostPeer: MCPeerID) {
        // Nothing to do, since disconnectedFromPeer will run if lostPeer is currently connected to peer
        print("\(#file) > \(#function) > \(lostPeer.displayName)")
        
//        if (lostPeer == self.peerID) {
//            self.endCallButtonIsClicked(self.nilButton)
//        }
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        //TODO: Need to notify the user that someone is trying to connect
        print("\(#file) > \(#function) > \(fromPeer.displayName)")
    }
    
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        
        if (peerID == self.peerID) {
            print("\(#file) > \(#function) > Connected with the current peer.")
            
            OperationQueue.main.addOperation { () -> Void in
                self.timerLabel.text = "Connected to \(self.peerID!.displayName)"
            }
            
//            setupAVRecorder()
            setupStream()
        }
        else {
            print("\(#file) > \(#function) > New connection to \(peerID.displayName)")
        }
        
    }
    
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > Disconnected from peer: \(peerID.displayName), user ended call: \(userEndedCall)")
        
        if (!userEndedCall) {
        
            if (peerID == self.peerID!) {
                inputStreamIsSet = false
                outputStreamIsSet = false
            
                let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(self.peerID!.displayName)", preferredStyle: UIAlertControllerStyle.alert)
                
                let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (alertAction) -> Void in
                    //Go back to PeerView
                    self.endCallButtonIsClicked(self.nilButton)
                }
                
                alert.addAction(okAction)
                
                OperationQueue.main.addOperation { () -> Void in
                    self.present(alert, animated: true, completion: nil)
                }
                
                // Since the peer is already disconnected, than we need to close all resources immediately
                OperationQueue.main.addOperation {
                    self.closeAllResources()
                }
            }
        }
    }
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > peer \(peerID.displayName)")
        
        if (peerID == self.peerID) {
            OperationQueue.main.addOperation { () -> Void in
                self.timerLabel.text = "Connecting to peer \(peerID.displayName)..."
            }
        }
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        print("\(#file) > \(#function) > Received inputStream from peer \(peerID.displayName), currQueue=\(currentQueueName()!)")
        if (peerID == self.peerID) {
            
            self.outputStream!.delegate = self
            self.outputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            self.outputStream!.open()
            
            self.recordingQueue.sync {
                self.recordAudio()
            }
        
            self.inputStream = inputStream
            self.inputStreamIsSet = true
            self.inputStream!.delegate = self
            self.inputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            self.inputStream!.open()
            
            
        }
        else {
            print("\(#file) > \(#function) > Should not print.")
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
