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
import Compression

class PhoneViewController: UIViewController, AVAudioRecorderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, StreamDelegate, ConnectionManagerDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let incomingCall = "_incoming_call_"
    
    // MARK: - Properties
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var endCallButton: UIButton!
    
    // MC
    var peerID: MCPeerID?
    var sessionIndex: Int?
    var isConnecting: Bool = false
    
    // Streams
    var outputStream: OutputStream?
    var outputStreamIsSet: Bool = false
    var inputStream: InputStream?
    var inputStreamIsSet: Bool = false
    
    // Timer
    var startTime = NSDate.timeIntervalSinceReferenceDate
    var timer = Timer()
    
    //Thread
    var recordingQueue = DispatchQueue(label: "recordingQueue", qos: DispatchQoS.userInteractive)
    var localPlayerQueue = DispatchQueue(label: "localPlayerQueue", qos: DispatchQoS.userInteractive)
    var receivingQueue = DispatchQueue(label: "receivingQueue", qos: DispatchQoS.userInteractive)
    var audioPlayerQueue = DispatchQueue(label: "audioPlayerQueue", qos: DispatchQoS.userInteractive)
    
    // Audio Capture and Playing
    var localAudioEngine: AVAudioEngine = AVAudioEngine()
    var localAudioPlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    var localInput: AVAudioInputNode?
    var localInputFormat: AVAudioFormat?
    
    var peerAudioEngine: AVAudioEngine = AVAudioEngine()
    var peerAudioPlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    var peerInput: AVAudioInputNode?
    var peerInputFormat: AVAudioFormat?
    
    // MARK: - View Methods
    
    override func viewDidLoad() {
        print("\(#file) > \(#function) > Entry")
        
        super.viewDidLoad()
        
        if (isConnecting) {
            timerLabel.text = "Connecting..."
        }
        else {
            timerLabel.text = "Calling..."
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(errorReceivedWhileRecording), name: NSNotification.Name(rawValue: "AVCaptureSessionRuntimeError"), object: nil)
        
        // Setting the connectionManager delegate to self
        appDelegate.connectionManager.delegate = self
        
        //-------------------------------------------------------------------------------
        // Calling peer
        
        recordingQueue.async {
        
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
                                                                      timeout: 20)
            }
            else {
                print("\(#file) > \(#function) > Sending message to peer.")
                
                let phoneMessage = MessageObject.init(peerID: self.appDelegate.connectionManager.sessions[self.sessionIndex!].connectedPeers[0],
                                                      messageFrom: [1],
                                                      messages: [self.incomingCall])
                
                // Attempt to send phone message
                if (!self.appDelegate.connectionManager.sendData(message: phoneMessage, toPeer: self.appDelegate.connectionManager.sessions[self.sessionIndex!].connectedPeers[0])) {
                    
                    print("\(#file) > \(#function) > Failed to send call invitation to peer")
                    self.timerLabel.text = "Call Failed"
                    
                    //TODO: Play a beeping sound to let the user know the call failed
                    
                    // Wait 2 seconds and then end call
                    sleep(2)
                    self.endCallButtonIsClicked(self.endCallButton)
                }
            }
        
            //-------------------------------------------------------------------------------
            // Attempting to create outputStream. This will only be called if the current peer is already connected to.
            
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
        
        recordingQueue.async {
            if (self.outputStreamIsSet) {
                print("\(#file) > \(#function) > Starting recording.")
                self.setupAVRecorder()
            }
        }
    
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
    
    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("\(#file) > \(#function) > Running...")
        
        var blockBuffer: CMBlockBuffer?
        var audioBufferList: AudioBufferList = AudioBufferList.init()
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer)
        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        
        for buffer in buffers {
            let u8ptr = buffer.mData!.assumingMemoryBound(to: UInt8.self)
            let output = outputStream!.write(u8ptr, maxLength: Int(buffer.mDataByteSize))
            
            if (output == -1) {
                let error = outputStream?.streamError
                print("\(#file) > \(#function) > Error on outputStream: \(error!.localizedDescription)")
            }
            else {
                print("\(#file) > \(#function) > Successfully sent data on queue \(currentQueueName()!)")
            }
        }
    }
    
    // MARK: - Dispatch Queue
    
    func currentQueueName() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)!
    }
    
    
    // MARK: - Recording/Playing
    
    // A function which checks permission of recording and initializes recorder
    func setupAVRecorder() {
        
        // Setting up audio engine for local recording and sounds
        recordingQueue.async {
            self.localInput = self.localAudioEngine.inputNode
            self.localAudioEngine.attach(self.localAudioPlayer)
            self.localInputFormat = self.localInput?.inputFormat(forBus: 0)
            self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: self.localInputFormat)
        }
        
        self.audioPlayerQueue.async {
            self.peerInput = self.peerAudioEngine.inputNode
            self.peerAudioEngine.attach(self.peerAudioPlayer)
            self.peerInputFormat = self.peerInput?.inputFormat(forBus: 1)
            self.peerAudioEngine.connect(self.peerAudioPlayer, to: self.peerAudioEngine.mainMixerNode, format: self.peerInputFormat)
        }
        
        // Start the timer
        self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTime), userInfo: nil, repeats: true)
        setupStream()
    }
    
    
    func startRecording() {
        print("\(#file) > \(#function) > Entry")
        
        localInput?.installTap(onBus: 0, bufferSize: 8192, format: localInputFormat) {
            (buffer, time) -> Void in
            
            // the audio being sent will be played locally as well
            self.localPlayerQueue.async {
                self.localAudioPlayer.scheduleBuffer(buffer)
            }
            
            let audioBuffer = self.audioBufferToBytes(audioBuffer: buffer)
            let output = self.outputStream!.write(audioBuffer, maxLength: Int(buffer.frameLength))
            
            if output > 0 {
                print("\(#file) > \(#function) > \(output) bytes written from queue \(self.currentQueueName())")
            }
            else if output == -1 {
                let error = self.outputStream!.streamError
                print("\(#file) > \(#function) > Error writing to stream: \(error?.localizedDescription)")
            }
            else {
                print("\(#file) > \(#function) > Cannot write to stream, stream is full")
            }
        }
        
        localPlayerQueue.sync {
            do {
                try self.localAudioEngine.start()
            }
            catch let error as NSError {
                print("\(#file) > \(#function) > Error starting audio engine: \(error.localizedDescription)")
            }
            
            //            self.localAudioPlayer.volume = 0.75
            self.localAudioPlayer.play()
            print("\(#file) > \(#function) > Audio is playing...")
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
//    func audioBufferToData(audioBuffer: AVAudioPCMBuffer) -> Data {
//        let channelCount = 1
//        let channels = UnsafeBufferPointer(start: audioBuffer.floatChannelData, count: channelCount)
//        
//        var data = NSData(bytes: channels[0], length: Int(audioBuffer.frameCapacity * audioBuffer.format.streamDescription.pointee.mBytesPerFrame))
//        
//    }
    
    func audioBufferToBytes(audioBuffer: AVAudioPCMBuffer) -> [UInt8] {
        let srcLeft = audioBuffer.floatChannelData![0]
        let bytesPerFrame = audioBuffer.format.streamDescription.pointee.mBytesPerFrame
        let numBytes = Int(bytesPerFrame * audioBuffer.frameLength)
        
        // initialize bytes by 0 
        var audioByteArray = [UInt8](repeating: 0, count: numBytes)
        
        srcLeft.withMemoryRebound(to: UInt8.self, capacity: numBytes) { srcByteData in
            audioByteArray.withUnsafeMutableBufferPointer {
                $0.baseAddress!.initialize(from: srcByteData, count: numBytes)
            }
        }
        
        return audioByteArray
    }
    
    
    // A function which starts the audio engine
    func setupStreamAudioPlayer() {
        print("\(#file) > \(#function) > Setting up audio engine and audio player")
        
        if (!peerAudioEngine.isRunning) {
            do {
                try self.peerAudioEngine.start()
                self.peerAudioPlayer.play()
                
                print("\(#file) > \(#function) > Successfully started audio engine")
            }
            catch let error as NSError {
                print("\(#file) > \(#function) > error: \(error.localizedDescription)")
            }
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    
    func errorReceivedWhileRecording() {
        print("\(#file) > \(#function) > Error")
    }
    
    // Used to display how long the call has been going on for
    func updateTime() {
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
                
                endCallButtonIsClicked(endCallButton)
            }
        }
        
        print("\(#file) > \(#function) > Exit - Queue: \(currentQueueName()!)")
    }
    
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode) {
        case Stream.Event.errorOccurred:
            print("\(#file) > \(#function) > Error has occurred on input stream")
            
            
        case Stream.Event.hasBytesAvailable:
            DispatchQueue.global().async {
                
                var buffer = [UInt8](repeating: 0, count: 8192)
                let length = self.inputStream!.read(&buffer, maxLength: buffer.count)
                
                if (length > 0) {
                    print("\(#file) > \(#function) > \(length) bytes read on queue \(self.currentQueueName()!) buffer.count \(buffer.count)")
                    
                    let audioBuffer = self.bytesToAudioBuffer(buffer)
                    
                    self.audioPlayerQueue.async {
                        self.peerAudioPlayer.scheduleBuffer(audioBuffer)
                        
                        if (!self.peerAudioPlayer.isPlaying && self.localAudioEngine.isRunning) {
                            self.peerAudioPlayer.play()
                        }
                    }
                }
                else if (length == 0) {
                    print("\(#file) > \(#function) > Reached end of stream")
                }
            }
        
        case Stream.Event.hasSpaceAvailable:
            print("\(#file) > \(#function) > Space available")
            
            
        case Stream.Event.endEncountered:
            print("\(#file) > \(#function) > End encountered")
            endCallButtonIsClicked(endCallButton)
            
            
        case Stream.Event.openCompleted:
            print("\(#file) > \(#function) > Open completed")
        
            
        default:
            print("\(#file) > \(#function) > Other")
        }
    }
    
    
    func bytesToAudioBuffer(_ buf: [UInt8]) -> AVAudioPCMBuffer {
        
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: true)
        let frameLength = UInt32(buf.count) / fmt.streamDescription.pointee.mBytesPerFrame
        
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameLength)
        audioBuffer.frameLength = frameLength
        
        let dstLeft = audioBuffer.floatChannelData![0]
//        for stereo
//        let dstRight = audioBuffer.floatChannelData![1]
        
        buf.withUnsafeBufferPointer {
            let src = UnsafeRawPointer($0.baseAddress!).bindMemory(to: Float.self, capacity: Int(frameLength))
            dstLeft.initialize(from: src, count: Int(frameLength))
        }
        
        return audioBuffer
    }
    
    
    //MARK: - Button Actions
    @IBAction func endCallButtonIsClicked(_ sender: UIButton) {
        // TODO : need to stop timer from incrementing 
        print("\(#file) > \(#function) > Stopping recording")
        
        OperationQueue.main.addOperation {
            _ = self.navigationController?.popViewController(animated: true)
            self.closeAllResources()
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
        timer.invalidate()
        
        // Close the output stream
        outputStream?.close()
        inputStream?.close()
        
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
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        //TODO: Need to notify the user that someone is trying to connect
        print("\(#file) > \(#function) > \(fromPeer.displayName)")
    }
    
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        
        if (peerID == self.peerID) {
            print("\(#file) > \(#function) > Connected with the current peer. Setting up AVRecorder.")
            
            OperationQueue.main.addOperation { () -> Void in
                self.timerLabel.text = "Connected"
            }
            
            setupAVRecorder()
        }
        else {
            print("\(#file) > \(#function) > New connection to \(peerID.displayName)")
        }
        
    }
    
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > Disconnected from peer \(peerID.displayName)")
        
        if (peerID == self.peerID!) {
            inputStreamIsSet = false
            outputStreamIsSet = false
            
            let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(self.peerID!.displayName)", preferredStyle: UIAlertControllerStyle.alert)
            
            let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (alertAction) -> Void in
                //Go back to PeerView
                self.endCallButtonIsClicked(self.endCallButton)
            }
            
            alert.addAction(okAction)
            
            OperationQueue.main.addOperation { () -> Void in
                self.present(alert, animated: true, completion: nil)
            }
            
            // Since the peer is already disconnected, than we need to close all resources immediately
            DispatchQueue.global().async {
                self.closeAllResources()
            }
        }
    }
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > peer \(peerID.displayName)")
        
        if (peerID == self.peerID) {
            OperationQueue.main.addOperation { () -> Void in
                self.timerLabel.text = "Connecting..."
            }
        }
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        print("\(#file) > \(#function) > Received inputStream from peer \(peerID.displayName), currQueue=\(currentQueueName()!)")
        if (peerID == self.peerID) {
            
            self.audioPlayerQueue.sync {
                self.setupStreamAudioPlayer()
            }
            
            self.outputStream!.delegate = self
            self.outputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            self.outputStream!.open()
            
            self.recordingQueue.sync {
                self.startRecording()
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
