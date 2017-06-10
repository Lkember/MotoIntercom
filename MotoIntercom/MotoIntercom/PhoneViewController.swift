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
import Accelerate
import MultipeerConnectivity
import JSQMessagesViewController

@available(iOS 10.0, *)
class PhoneViewController: UIViewController, AVAudioRecorderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, StreamDelegate, ConnectionManagerDelegate, PeerAddedDelegate {

    // MARK: - Properties
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let incomingCall = "_incoming_call_"
    let acceptCall = "_accept_call_"
    let declineCall = "_decline_call_"
    let endingCall = "_user_ended_call_"
    
    // Background Task to keep the app running in the background
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var peerLabel: UILabel!
    @IBOutlet weak var endCallButton: UIButton!
    var nilButton: UIButton = UIButton.init()
    
    // MC
    var peerID: MCPeerID?
    var sessionIndex: Int?
    var didReceiveCall: Bool = false
    
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
    
    // Used to fix a crash when attempting to detach a node that isn't attached
    var isNodeAttached = false
    var isAudioSetup = false
    
    // Peer audio format
    var peerAudioFormat: AVAudioFormat?
    var peerAudioFormatIsSet = false
    
    // Average Volume
    var averageInputIsSet = false
    var averageInputVolume: Double = 0.0
    var size = 0
    
    // Button Options
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var addPeerButton: UIButton!
    
    var muteIsOn = false
    var speakerIsOn = false
    
    // User ended call
    var userEndedCall = false
    
    
    // MARK: - View Methods
    override func viewDidLoad() {
        print("\(#file) > \(#function) > Entry")
        super.viewDidLoad()
        
        // Setting the connectionManager delegate to self
        appDelegate.connectionManager.delegate = self
        appDelegate.connectionManager.debugSessions()
        self.sessionIndex = self.appDelegate.connectionManager.findSinglePeerSession(peer: self.peerID!)
        
        if (sessionIndex! == -1) {
            statusLabel.text = "Calling..."
            userEndedCall = false
            disconnectedFromPeer(self.peerID!)
        }
        else {
            print("\(#file) > \(#function) > sessionIndex = \(sessionIndex!.description)")
            
            // When the device is up to the ear, the screen will dim
            UIDevice.current.isProximityMonitoringEnabled = true
            self.prepareAudio()
            
            if (didReceiveCall) {
                statusLabel.text = "Connecting..."
                
                readyToOpenStream()
            }
            else {
                statusLabel.text = "Calling"
            }
        }
        
        // Stop advertising and browsing for peers when in a call
//        self.appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
//        self.appDelegate.connectionManager.browser.stopBrowsingForPeers()
        
        NotificationCenter.default.addObserver(self, selector: #selector(receivedStandardMessage(_:)), name: NSNotification.Name(rawValue: "receivedStandardMessageNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(errorReceivedWhileRecording), name: NSNotification.Name(rawValue: "AVCaptureSessionRuntimeError"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(audioHardwareRouteChanged(notification:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedPeerStreamInformation(_:)), name: NSNotification.Name(rawValue: "receivedAVAudioFormat"), object: nil)
        
        print("\(#file) > \(#function) > Exit")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        // Used to change button layouts, views, etc
        self.updateUI()
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    
    // MARK: - Startup
    
    func updateUI() {
        print("\(#file) > \(#function) > Entry")
        self.navigationController?.navigationBar.isHidden = true
        
        // Giving the background view a blur effect
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.insertSubview(blurEffectView, at: 0)
        
        // Making the buttons circular
        let muteImage: UIImage = UIImage.init(named: "microphone.png")!
        let tintedMuteImage = muteImage.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        muteButton.setImage(tintedMuteImage, for: UIControlState.normal)
        muteButton.tintColor = UIColor.white
        muteButton.layer.cornerRadius = muteButton.frame.width/2
        muteButton.layer.borderWidth = 1
        muteButton.layer.borderColor = UIColor.gray.cgColor
        muteButton.isUserInteractionEnabled = false
        muteButton.isEnabled = false
        
        let addPeerImage: UIImage = UIImage.init(named: "add (1).png")!
        let tintedAddPeerImage = addPeerImage.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        addPeerButton.setImage(tintedAddPeerImage, for: UIControlState.normal)
        addPeerButton.tintColor = UIColor.white
        addPeerButton.layer.cornerRadius = muteButton.frame.width/2
        addPeerButton.layer.borderWidth = 1
        addPeerButton.layer.borderColor = UIColor.gray.cgColor
        addPeerButton.isUserInteractionEnabled = false
        addPeerButton.isEnabled = false
        
        let speakerImage: UIImage = UIImage.init(named: "High Volume-50.png")!
        let tintedSpeakerImage = speakerImage.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        speakerButton.setImage(tintedSpeakerImage, for: UIControlState.normal)
        speakerButton.tintColor = UIColor.white
        speakerButton.layer.cornerRadius = speakerButton.frame.width/2
        speakerButton.layer.borderWidth = 1
        speakerButton.layer.borderColor = UIColor.gray.cgColor
        speakerButton.isEnabled = false
        speakerButton.isUserInteractionEnabled = false
        
        peerLabel.text = "\(peerID!.displayName)"
        
        print("\(#file) > \(#function) > Exit")
    }
    
    func callPeer() {
        self.sessionIndex = self.appDelegate.connectionManager.findSinglePeerSession(peer: self.peerID!)
        
        // TODO: This code may be unnecessary because we should be already connected to the peer.
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
            
            //TODO: Need to change if allowed to connect to multiple users
            if (!self.appDelegate.connectionManager.sendData(stringMessage: incomingCall, toPeer: self.appDelegate.connectionManager.sessions[self.sessionIndex!].connectedPeers[0])) {
                print("\(#file) > \(#function) > Failed to send call invitation to peer")
                
                OperationQueue.main.addOperation {
                    self.statusLabel.text = "Call Failed"
                }
                
                //TODO: Play a beeping sound to let the user know the call failed
                
                // Wait 2 seconds and then end call
                sleep(2)
                self.endCallButtonIsClicked(self.nilButton)
            }
        }
    }
    
    
    func registerBackgroundTask() {
        print("\(#file) > \(#function) > backgroundTask is registered")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != UIBackgroundTaskInvalid)
    }
    
    
    func endBackgroundTask() {
        print("\(#file) > \(#function) > Background task ended")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskInvalid
    }
    
    
    // MARK: - Dispatch Queue
    
    func currentQueueName() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)!
    }
    
    
    // MARK: - Recording/Playing
    
    func prepareAudio() {
        
        // Setting up AVAudioSession
        do {
            print("\(#file) > \(#function) > setCategory")
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: [AVAudioSessionCategoryOptions.allowBluetooth])
            print("\(#file) > \(#function) > setPreferredIOBufferDuration")
            try audioSession.setPreferredIOBufferDuration(0.001)
//            print("\(#file) > \(#function) > setPreferredNumberOfChannels")
//            try audioSession.setPreferredInputNumberOfChannels(1)
            print("\(#file) > \(#function) > setPreferredSampleRate")
            try audioSession.setPreferredSampleRate(44100)
            print("\(#file) > \(#function) > setMode")
            try audioSession.setMode(AVAudioSessionModeVoiceChat)
            print("\(#file) > \(#function) > setActive")
            try audioSession.setActive(true)
            
            print("\(#file) > \(#function) > audioSession \(audioSession)")
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > Error encountered: \(error)")
        }
        
        
        // Setting up audio engine for local recording and sounds
        self.localInput = self.localAudioEngine.inputNode
        self.localAudioEngine.attach(self.localAudioPlayer)
        self.isNodeAttached = true
        self.localInputFormat = self.localInput?.inputFormat(forBus: 0)
        
        self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: localInputFormat)
        
        self.localAudioEngine.prepare()
        
        print("\(#file) > \(#function) > localInputFormat = \(self.localInputFormat.debugDescription)")
        print("\(#file) > \(#function) > Starting localAudioEngine")
        
        localPlayerQueue.sync {
            do {
                try self.localAudioEngine.start()
                self.localAudioPlayer.play()
            }
            catch let error as NSError {
                print("\(#file) > \(#function) > Error starting audio engine: \(error.localizedDescription)")
            }
        }
        
        localInput?.reset()
        localInput?.removeTap(onBus: 0)
        localInput?.installTap(onBus: 0, bufferSize: 17640, format: localInputFormat) {
            (buffer, when) -> Void in
            /* Calling this method so that there is less delay when the user starts speaking.
             * I was having an issue where there was about a 100-300 ms delay, however I noticed
             * if you clicked the mute button twice the delay was basically gone. Instead
             * of making the user click the button twice, it will start recording and then
             * automatically remove the tap and reinstall the tap.
             * It may eventually be unnecessary
            */
        }
        print("\(#file) > \(#function) > tap installed")
        localInput?.reset()
        localInput?.removeTap(onBus: 0)
        print("\(#file) > \(#function) > tap removed")
        print("\(#file) > \(#function) > Exit")
        isAudioSetup = true
    }
    
    
    func updateAudioSettings() {
        print("\(#file) > \(#function) > Entry")
        self.localInput = self.localAudioEngine.inputNode
        self.localInputFormat = self.localInput?.inputFormat(forBus: 0)
        self.localAudioEngine.disconnectNodeInput(self.localAudioPlayer)
        
        if (peerAudioFormatIsSet) {
            self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: peerAudioFormat)
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    
    func recordAudio() {
        localPlayerQueue.sync {
            localInput?.reset()
            localInput?.removeTap(onBus: 0)
            localInput?.installTap(onBus: 0, bufferSize: 4410, format: localInputFormat) {
                (buffer, when) -> Void in
                
//                http://stackoverflow.com/questions/14349874/taking-absolute-value-of-cgfloat
//                http://stackoverflow.com/questions/32891012/spectrogram-from-avaudiopcmbuffer-using-accelerate-framework-in-swift
                
                //------------------------------------------------------------------
                // Calculating the magnitude of sound coming from the microphone
                
                let arraySize = Int(buffer.frameLength)
                var channelSamples: [[DSPComplex]] = []
                
//                for i in 0..<1 {
                
                    channelSamples.append([])
                    let firstSample = buffer.format.isInterleaved ? 0 : 0*arraySize
                    
                    for j in stride(from: firstSample, to: arraySize, by: buffer.stride*2) {
                        
                        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                        let floats = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                        channelSamples[0].append(DSPComplex(real: floats[j], imag: floats[j+buffer.stride]))
                        
                    }
//                }
                
                var spectrum = [Float]()
                
                for i in 0..<arraySize/2 {
                    
                    let imag = channelSamples[0][i].imag
                    let real = channelSamples[0][i].real
                    let magnitude = sqrt(pow(real,2)+pow(imag,2))
                    
                    spectrum.append(magnitude)
                }
                
                var sum = 0.0
                var iter = 0.0
                for i in stride(from: 0, to: spectrum.count, by: 20) {
                    sum += Double(spectrum[i])
                    iter += 1
                }
                
                sum = sum/iter
                
                DispatchQueue.global().async {
                    self.updateAverageVolumeInput(average: sum)
                }
                
                //---------------------------------------------------
                // Sending the data to peer
                
//                print("\(#file) > \(#function) > curr: \(sum) -- average: \(self.averageInputVolume)")
                
                if (sum > self.averageInputVolume || !self.averageInputIsSet) {
                    print("\(#file) > \(#function) > Sending data to peer: \(sum) > \(self.averageInputVolume) ")
                    let data = self.audioBufferToNSData(PCMBuffer: buffer)
                    let output = self.outputStream!.write(data.bytes.assumingMemoryBound(to: UInt8.self), maxLength: data.length)
                    
                    if output > 0 {
    //                    print("\(#file) > \(#function) > \(output) bytes written")
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
    }
    
    
    func audioBufferToNSData(PCMBuffer: AVAudioPCMBuffer) -> NSData {
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: channelCount)
        let data = NSData(bytes: channels[0], length:Int(PCMBuffer.frameLength * PCMBuffer.format.streamDescription.pointee.mBytesPerFrame))
        
        return data
    }
    
    func errorReceivedWhileRecording() {
        print("\(#file) > \(#function) > Error")
    }
    
    func audioHardwareRouteChanged(notification: NSNotification) {
        print("\(#file) > \(#function) > Entry \(notification.name)")
        self.localInput?.reset()
        self.localInput?.removeTap(onBus: 0)
        updateAudioSettings()
        
        if (inputStreamIsSet && outputStreamIsSet) {
            print("\(#file) > \(#function) > Recording audio")
            recordAudio()
        }
        
        print("\(#file) > \(#function) > Exit")
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
    
    func updateAverageVolumeInput(average: Double) {
        if (averageInputIsSet) {
            
            // If the current average volume is greater than the average * 50%, then the user is talking.
            // If this is the case, then do not update the volume.
            // Otherwise update it.
            if (!(average > averageInputVolume * 1.5)) {
                averageInputVolume = averageInputVolume * 1000
                averageInputVolume += average*1.05
                averageInputVolume = averageInputVolume/1001
            }
//            else {
//                averageInputVolume = averageInputVolume * 100
//                averageInputVolume += average
//                averageInputVolume = averageInputVolume/101
//            }
        }
        else {
            averageInputVolume += average
            size += 1
            
            if (size >= 100) {
                averageInputVolume = averageInputVolume/Double(size)
                
                averageInputIsSet = true
            }
        }
//        print("\(#file) > \(#function) > averageInputIsSet \(averageInputIsSet) -- averageInputVolume \(averageInputVolume)")
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
            
            OperationQueue.main.addOperation {
                self.statusLabel.text = "\(minuteString):\(secondString)"
            }
            
            let second = Int(secondString)
            
            if (second! % 10 == 0) {
                print("\(#file) > \(#function) > Timer updated to \(minuteString):\(secondString)")
            }
        }
    }
    
    
    // MARK: - Stream
    
    func readyToOpenStream() {
        print("\(#file) > \(#function) > Entry")
//        let result = appDelegate.connectionManager.sendData(stringMessage: readyForStream, toPeer: peerID!)
        let result = appDelegate.connectionManager.sendData(format: localInputFormat!, toPeer: peerID!)
        
        if (!result) {
            print("\(#file) > \(#function) > Error sending message...")
        }
        
        setupStream()
        print("\(#file) > \(#function) > Exit")
    }
    
    func setupStream() {
        print("\(#file) > \(#function) > Creating output stream")
        
        if (!outputStreamIsSet) {
            do {
                let stream = try self.appDelegate.connectionManager.sessions[sessionIndex!].startStream(withName: "motoIntercom", toPeer: peerID!)
                outputStream = stream
                outputStreamIsSet = true
            }
            catch let error as NSError {
                print("\(#file) > \(#function) > Failed to create outputStream: \(error.localizedDescription)")
                // TODO: Send streamFailed message to user
                endCallButtonIsClicked(endCallButton)
            }
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode) {
        case Stream.Event.errorOccurred:
            print("\(#file) > \(#function) > Error has occurred on input stream")
            
            
        case Stream.Event.hasBytesAvailable:
            DispatchQueue.global().sync {
                
                let availableCount = 1024-self.testBufferCount
                
                var tempBuffer: [UInt8] = .init(repeating: 0, count: availableCount)
                let length = self.inputStream!.read(&tempBuffer, maxLength: availableCount)
                
                if (tempBuffer.count != length) {
                    tempBuffer = [UInt8](tempBuffer.dropLast(tempBuffer.count - length))
                }
                
                self.testBufferCount += length
                self.testBuffer.append(contentsOf: tempBuffer)
                
//                print("\(#file) > \(#function) > Size of buffer: \(self.testBufferCount), amount read: \(length), available: \(availableCount - length), buffer size = \(self.testBuffer.count)")
                
                if (self.testBufferCount >= 1024) {
                    
                    let data = NSData.init(bytes: &self.testBuffer, length: self.testBufferCount)
                    let audioBuffer = self.dataToPCMBuffer(data: data)
                    
                    self.localAudioPlayer.scheduleBuffer(audioBuffer, completionHandler: nil)
                    
                    self.testBuffer.removeAll()
                    self.testBufferCount = 0
                }
            }
        
        case Stream.Event.hasSpaceAvailable:
//            print("\(#file) > \(#function) > Space available")
            break
            
            
        case Stream.Event.endEncountered:
            print("\(#file) > \(#function) > End encountered")
            
            
        case Stream.Event.openCompleted:
            registerBackgroundTask()
            print("\(#file) > \(#function) > Open completed")
        
            
        default:
            print("\(#file) > \(#function) > Other")
        }
    }
    
    func dataToPCMBuffer(data: NSData) -> AVAudioPCMBuffer {
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: peerAudioFormat!,
                                           frameCapacity: UInt32(data.length) / peerAudioFormat!.streamDescription.pointee.mBytesPerFrame)
        
        audioBuffer.frameLength = audioBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: audioBuffer.floatChannelData, count: Int(audioBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return audioBuffer
    }
    
    
    //MARK: - Button Actions
    
    @IBAction func addPeerButtonIsTouched(_ sender: Any) {
        print("\(#file) > \(#function)")
        
        let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AddNewPeers") as! AddPeerViewController
        popOverView.sessionIndex = self.sessionIndex!
        self.addChildViewController(popOverView)
        
        OperationQueue.main.addOperation {
            popOverView.view.frame = self.view.frame
            self.view.addSubview(popOverView.view)
            popOverView.didMove(toParentViewController: self)
        }
    }
    
    
    @IBAction func muteButtonIsTouched(_ sender: Any) {
        
        print("\(#file) > \(#function) > Entry > mute: \(muteIsOn) -> \(!muteIsOn) -- isEnabled: \(muteButton.isUserInteractionEnabled)")
        
        if (muteButton.isUserInteractionEnabled == true && muteButton.isEnabled == true) {
            
            OperationQueue.main.addOperation {
                self.muteButton.isUserInteractionEnabled = false
                self.muteButton.isEnabled = false
            }
            
            DispatchQueue.global().sync {
                
                if (!muteIsOn) {
                    // Make the button look gray
                    print("\(#file) > \(#function) > removing tap")
                    localInput?.reset()
                    self.localInput?.removeTap(onBus: 0)
                    print("\(#file) > \(#function) > tap removed")
                    
                    OperationQueue.main.addOperation {
                        self.muteButton.backgroundColor = UIColor.darkGray
                        self.muteButton.backgroundColor?.withAlphaComponent(0.5)
                    }
                    
                    muteIsOn = true
                }
                else {
                    // Make button go back to black
                    print("\(#file) > \(#function) > removing tap")
                    localInput?.reset()
                    self.localInput?.removeTap(onBus: 0)
                    print("\(#file) > \(#function) > tap removed")
                    print("\(#file) > \(#function) > installing tap")
                    self.recordAudio()
                    print("\(#file) > \(#function) > tap installed")
                    
                    OperationQueue.main.addOperation {
                        self.muteButton.backgroundColor = UIColor.clear
                        self.muteButton.backgroundColor?.withAlphaComponent(1)
                    }
                    
                    muteIsOn = false
                }
            }
            
            OperationQueue.main.addOperation {
                self.muteButton.isEnabled = true
                self.muteButton.isUserInteractionEnabled = true
            }
        }
        print("\(#file) > \(#function) > Exit > mute: \(muteIsOn)")
    }
    
    @IBAction func speakerButtonIsTouched(_ sender: Any) {
        if (!speakerIsOn) {
            speakerIsOn = true
            
            // Make the button look gray
            DispatchQueue.global().sync {
                //TODO: Need to make the output go to the speaker
                do {
                    try self.audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
                }
                catch let error as NSError {
                    print("\(#file) > \(#function) > Could not change to speaker: \(error.description)")
                }
                
                OperationQueue.main.addOperation {
                    self.speakerButton.backgroundColor = UIColor.darkGray
                    self.speakerButton.backgroundColor?.withAlphaComponent(0.5)
                }
            }
        }
        else {
            speakerIsOn = false
            
            // Make button go back to black
            DispatchQueue.global().sync {
                do {
                    try self.audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.none)
                }
                catch let error as NSError {
                    print("\(#file) > \(#function) > Could not change to ear speaker: \(error.description)")
                }
                
                OperationQueue.main.addOperation {
                    self.speakerButton.backgroundColor = UIColor.clear
                    self.speakerButton.backgroundColor?.withAlphaComponent(1)
                }
            }
        }
        
        print("\(#file) > \(#function) > speaker: \(speakerIsOn)")
    }
    
    @IBAction func endCallButtonIsClicked(_ sender: UIButton) {
        print("\(#file) > \(#function) > Entry")
        if (sender == nilButton) {
            userEndedCall = false
        }
        else {
            userEndedCall = true
        }
        
        if (userEndedCall) {
            _ = appDelegate.connectionManager.sendData(stringMessage: endingCall, toPeer: peerID!)
        }
        
        OperationQueue.main.addOperation {
            DispatchQueue.global().sync {
                self.closeAllResources()
            }
            self.dismiss(animated: true, completion: nil)
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    // A function which stops recording and closes streams
    func closeAllResources() {
        print("\(#file) > \(#function) > Entry")
        
        // Ending the background task
        self.endBackgroundTask()
        
        //Stop recording and playing
        if localAudioPlayer.isPlaying {
            print("\(#file) > \(#function) > localAudioPlayer stopped")
            localAudioPlayer.stop()
        }
        
        if localAudioEngine.isRunning {
            print("\(#file) > \(#function) > localAudioEngine stopped")
            localAudioEngine.stop()
        }
        
        if (self.isNodeAttached) {
            self.localAudioEngine.detach(self.localAudioPlayer)
            self.isNodeAttached = false
        }
        
        // Stop the timer
        timer?.invalidate()
        
        // Close the output stream
        outputStream?.close()
        inputStream?.close()
        
        print("\(#file) > \(#function) > Streams closed")
        
        inputStreamIsSet = false
        outputStreamIsSet = false
        isAudioSetup = false
        
        self.testBufferCount = 0
        self.testBuffer.removeAll()
        
        UIDevice.current.isProximityMonitoringEnabled = false
        
        print("\(#file) > \(#function) > Exit")
    }
    
    // MARK: - PeerAddedDelegate
    func peersToBeAdded(peers: [MCPeerID]) {
        print("\(#file) > \(#function) > Entry -- \(peers.count) peers to call")
        let isPhoneCall = true
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
        
        // Loop through each peer and send them an invite
        for i in 0..<peers.count {
            
            // If the peer is not already in the session, then send them an invite
            if (!self.appDelegate.connectionManager.sessions[sessionIndex!].connectedPeers.contains(peers[i])) {
                
                print("\(#file) > \(#function) > Adding peer \(peers[i].displayName)")
                self.appDelegate.connectionManager.browser.invitePeer(peers[i],
                                                                      to: self.appDelegate.connectionManager.sessions[sessionIndex!],
                                                                      withContext: dataToSend,
                                                                      timeout: 20)
                
            }
            else {
                print("\(#file) > \(#function) > Peer \(peers[i].displayName) is already in the call")
            }
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    
    // MARK: - ConnectionManagerDelegate
    func foundPeer(_ newPeer : MCPeerID) {
        // nothing to do
        print("\(#file) > \(#function) > \(newPeer.displayName)")
    }
    
    func lostPeer(_ lostPeer: MCPeerID) {
        // Nothing to do, since disconnectedFromPeer will run if lostPeer is currently connected to peer
        print("\(#file) > \(#function) > \(lostPeer.displayName)")
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        //TODO: Need to notify the user that someone is trying to connect
        print("\(#file) > \(#function) > \(fromPeer.displayName)")
        
        if (!self.appDelegate.connectionManager.checkIfAlreadyConnected(peerID: fromPeer)) {
            let index = self.appDelegate.connectionManager.createNewSession()
            self.appDelegate.connectionManager.invitationHandler!(true, self.appDelegate.connectionManager.sessions[index])
        }
    }
    
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > Disconnected from peer: \(peerID.displayName), user ended call: \(userEndedCall)")
        
        if (peerID == self.peerID!) {
            
            // If the user did not end the call and the peer is not connected, attempt to reconnect
            if (!userEndedCall && !appDelegate.connectionManager.checkIfAlreadyConnected(peerID: peerID)) {
                
                // Closing all resources (this is to save battery while reconnecting)
                OperationQueue.main.addOperation {
                    self.closeAllResources()
                    self.statusLabel.text = "Reconnecting..."
                }
                
                self.sessionIndex = self.appDelegate.connectionManager.createNewSession()
                
                let isPhoneCall: Bool = true
                let dataToSend : Data = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
                
                self.appDelegate.connectionManager.browser.invitePeer(self.peerID!,
                                                                      to: self.appDelegate.connectionManager.sessions[self.sessionIndex!],
                                                                      withContext: dataToSend,
                                                                      timeout: 60)
                
            }
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > peer \(peerID.displayName)")
        
        if (peerID == self.peerID) {
            OperationQueue.main.addOperation { () -> Void in
                self.statusLabel.text = "Connecting"
            }
            
            if !isAudioSetup {
                self.prepareAudio()
            }
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        
        if (peerID == self.peerID) {
            print("\(#file) > \(#function) > Connected with the current peer.")
            
            OperationQueue.main.addOperation {
                self.statusLabel.text = "Connected"
            }
            
            readyToOpenStream()
        }
        else {
            print("\(#file) > \(#function) > New connection to \(peerID.displayName)")
        }
        
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        
        print("\(#file) > \(#function) > Entry > Received inputStream from peer \(peerID.displayName)")
        if (peerID == self.peerID) {
            
            self.inputStream = inputStream
            self.inputStreamIsSet = true
            self.inputStream!.delegate = self
            self.inputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            self.inputStream!.open()
            
            self.outputStream!.delegate = self
            self.outputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            self.outputStream!.open()
            
            self.recordingQueue.async {
                sleep(1)
                print("\(#file) > \(#function) > installing tap")
                self.recordAudio()
                print("\(#file) > \(#function) > tap installed")
                
                self.muteButton.isEnabled = true
                self.speakerButton.isEnabled = true
                self.addPeerButton.isEnabled = true
                
                self.muteButton.isUserInteractionEnabled = true
                self.speakerButton.isUserInteractionEnabled = true
                self.addPeerButton.isUserInteractionEnabled = true
            }
        }
        else {
            print("\(#file) > \(#function) > Should not print.")
        }
        
        OperationQueue.main.addOperation {
            self.statusLabel.text = "Connected"
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    func receivedStandardMessage(_ notification: Notification) {
        print("\(#file) > \(#function) > Entry")
        
        let newMessage = notification.object as! StandardMessage
        
        if (newMessage.peerID == self.peerID) {
            if newMessage.message == acceptCall {
                print("\(#file) > \(#function) > Call accepted")
                
                if (!outputStreamIsSet) {
                    OperationQueue.main.addOperation {
                        self.statusLabel.text = "Connecting..."
                    }
                }
            }
            else if newMessage.message == declineCall {
                print("\(#file) > \(#function) > Call declined -- Ending")
                endCallButtonIsClicked(endCallButton)
            }
            
//            else if newMessage.message == readyForStream {
//                print("\(#file) > \(#function) > Ready for stream -- Starting stream")
////                if (!outputStreamIsSet) {
////                    setupStream()
////                }
//            }
            
            else if newMessage.message == endingCall {
                print("\(#file) > \(#function) > Peer ended call")
                //TODO: Need to play a sound to let the user know that the call has ended
                endCallButtonIsClicked(nilButton)
            }
            
        }
        else {
            print("\(#file) > \(#function) > Wrong peer")
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    func receivedPeerStreamInformation(_ notification: NSNotification) {
        print("\(#file) > \(#function) > Entry \(localAudioEngine.isRunning)")
        
        let audioFormat = notification.object as! AVAudioFormat
        
        peerAudioFormat = audioFormat
        peerAudioFormatIsSet = true
        
        if (!didReceiveCall) {
            _ = appDelegate.connectionManager.sendData(format: self.localInputFormat!, toPeer: peerID!)
        }
        
        // Setting the format for the localAudioPlayer
        self.localAudioEngine.disconnectNodeInput(self.localAudioPlayer)
        self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: peerAudioFormat)
        self.localAudioEngine.prepare()
        do {
            try self.localAudioEngine.start()
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > failed to start audio engine \(error.localizedDescription)")
        }
        
        self.localAudioPlayer.play()
        
        if (!outputStreamIsSet) {
            self.setupStream()
        }
        print("\(#file) > \(#function) > Exit - \(peerAudioFormat)")
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
