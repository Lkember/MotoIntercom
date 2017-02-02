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

class PhoneViewController: UIViewController, AVAudioRecorderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, StreamDelegate, ConnectionManagerDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let incomingCall = "_incoming_call_"
    
    // MARK: - Properties
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var endCallButton: UIButton!
    
    var peerID: MCPeerID?
    var sessionIndex: Int?
    var isConnecting: Bool = false
    
    var outputStream: OutputStream?
    var outputStreamIsSet: Bool = false
    var inputStream: InputStream?
    var inputStreamIsSet: Bool = false
    
    var streamingThread: Thread?
    var startTime = NSDate.timeIntervalSinceReferenceDate
    var timer = Timer()
    
    var captureSession: AVCaptureSession! = AVCaptureSession()
    var recordingSession: AVAudioSession! = AVAudioSession()
    var captureDevice: AVCaptureDevice!
    var captureDeviceInput: AVCaptureDeviceInput!
    var outputDevice: AVCaptureAudioDataOutput?
    var audioQueue: AudioQueueRef?
    var audioPlayer: AVAudioPlayerNode?
    
    // MARK: - View Methods
    
    override func viewDidLoad() {
        print("\(#file) > \(#function) > Entry")
        
        super.viewDidLoad()
        //-------------------------------------------------------------------------------
        
        if (isConnecting) {
            timerLabel.text = "Connecting..."
        }
        else {
            timerLabel.text = "Calling..."
        }
        
        recordingSession = AVAudioSession.sharedInstance()
        
        NotificationCenter.default.addObserver(self, selector: #selector(errorReceivedWhileRecording), name: NSNotification.Name(rawValue: "AVCaptureSessionRuntimeError"), object: nil)
        
        // Setting the connectionManager delegate to self
        appDelegate.connectionManager.delegate = self
        
        //-------------------------------------------------------------------------------
        // Calling peer
        
        sessionIndex = self.appDelegate.connectionManager.findSinglePeerSession(peer: peerID!)
        
        // sessionIndex is -1 then we are not connected to peer, so send invite
        if (sessionIndex == -1) {
            print("\(#file) > \(#function) > Sending call invitation to peer.")
            sessionIndex = self.appDelegate.connectionManager.createNewSession()
            
            let isPhoneCall: Bool = true
            let dataToSend : Data = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
            
            self.appDelegate.connectionManager.browser.invitePeer(self.peerID!, to: self.appDelegate.connectionManager.sessions[sessionIndex!], withContext: dataToSend, timeout: 20)
        }
        else {
            print("\(#file) > \(#function) > Sending message to peer.")
            
            let phoneMessage = MessageObject.init(peerID: self.appDelegate.connectionManager.sessions[sessionIndex!].connectedPeers[0], messageFrom: [1], messages: [incomingCall])
            
            // Attempt to send phone message
            if (!self.appDelegate.connectionManager.sendData(message: phoneMessage, toPeer: self.appDelegate.connectionManager.sessions[sessionIndex!].connectedPeers[0])) {
                
                print("\(#file) > \(#function) > Failed to send call invitation to peer")
                timerLabel.text = "Call Failed"
                
                //TODO: Play a beeping sound to let the user know the call failed
                
                // Wait 2 seconds and then end call
                sleep(2)
                endCallButtonIsClicked(endCallButton)
            }
        }
        
        //-------------------------------------------------------------------------------
        // Attempting to create outputStream. This will only succeed if the user was already connected to.
        
        do {
            outputStream = try self.appDelegate.connectionManager.sessions[sessionIndex!].startStream(withName: "motoIntercom", toPeer: peerID!)
            outputStreamIsSet = true
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > Failed to create outputStream: \(error.localizedDescription)")
            outputStreamIsSet = false
        }
        
//        print("\(#file) > \(#function) > sessionIndex = \(sessionIndex)")
        
        self.navigationController?.navigationBar.isHidden = true
        
        if (outputStreamIsSet) {
            print("\(#file) > \(#function) > Starting recording.")
            setupAVRecorder()
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
    
    // MARK: - Recorder
    
    // A function which checks permission of recording and initializes recorder
    func setupAVRecorder() {
        print("\(#file) > \(#function) > Entry")
        
        do {
            print("\(#file) > \(#function) > setting category")
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            
            print("\(#file) > \(#function) > setting mode")
            try recordingSession.setMode(AVAudioSessionModeVoiceChat)
            
            print("\(#file) > \(#function) > setting preferred sample rate")
            try recordingSession.setPreferredSampleRate(44000.00)
            
            print("\(#file) > \(#function) > setting preferred IO buffer duration")
            try recordingSession.setPreferredIOBufferDuration(0.2)
            
            print("\(#file) > \(#function) > setting active")
            try recordingSession.setActive(true)
            
            recordingSession.requestRecordPermission() { [unowned self] (allowed: Bool) -> Void in
                DispatchQueue.main.async {
                    if allowed {
                        do {
                            self.captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
                            try self.captureDeviceInput = AVCaptureDeviceInput.init(device: self.captureDevice)
                            
                            self.outputDevice = AVCaptureAudioDataOutput()
                            self.outputDevice?.setSampleBufferDelegate(self, queue: DispatchQueue.main)
                            
                            self.captureSession = AVCaptureSession()
                            self.captureSession.addInput(self.captureDeviceInput)
                            self.captureSession.addOutput(self.outputDevice)
                            
                            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTime), userInfo: nil, repeats: true)
                        }
                        catch let error {
                            print("\(#file) > \(#function) > ERROR: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        catch let error {
            print("\(#file) > \(#function) > ERROR: \(error.localizedDescription)")
        }
        
        
        //------------------------------------------------------------------
        // Set output stream
        
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
        
        print("\(#file) > \(#function) > Exit")
    }
    
    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        //https://developer.apple.com/reference/avfoundation/avcaptureaudiodataoutputsamplebufferdelegate/1386039-captureoutput
        
        //-------------------------------------------------------
        // Writing to output stream
        
        var blockBuffer: CMBlockBuffer?
        var audioBufferList: AudioBufferList = AudioBufferList.init()
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer)
        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        
        for buffer in buffers {
            let u8ptr = buffer.mData!.assumingMemoryBound(to: UInt8.self)
            let output = outputStream!.write(u8ptr, maxLength: Int(buffer.mDataByteSize))
            
//            let output = outputStream?.write((buffer.mData?.load(as: UnsafePointer<UInt8>.self))!, maxLength: Int(buffer.mDataByteSize))
            
            if (output == -1) {
                let error = outputStream?.streamError
                print("\(#file) > \(#function) > Error on outputStream: \(error!.localizedDescription)")
            }
            else {
                print("\(#file) > \(#function) > Number of audio buffers \(audioBufferList.mNumberBuffers), number of buffers \(buffers.count)")
            }
        }
        
//        audioPlayer?.scheduleBuffer(blockBuffer, completionHandler: nil)
        
//        for i in 0..<audioBufferList.mNumberBuffers {
//            var audioBuffer: AudioBuffer = audioBufferList.mBuffers.mData[i]
//            outputStream?.write(audioBuffer.mData, maxLength: audioBuffer.mDataByteSize)
//        }
    }
    
    
    // MARK: - Recording
    func startRecording() {
        print("\(#file) > \(#function) > Started recording")
        captureSession.startRunning()
    }
    
    func finishRecording(success: Bool) {
        print("\(#file) > \(#function) > Stopping audio recording")
        // TODO: Stop the updateTime() method from working
//        if audioRecorder != nil {
//            audioRecorder.stop()
//            audioRecorder = nil
//        }
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
    
    // MARK: - InputStream
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        print("\(#file) > \(#function) > data received from stream")
        
        switch (eventCode) {
        case Stream.Event.errorOccurred:
            print("\(#file) > \(#function) > Error has occurred on input stream")
            
            
        case Stream.Event.hasBytesAvailable:
            print("\(#file) > \(#function) > New data has arrived")
            
            
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
    
    // This function is called when bytes are available from the input stream.
    // This will read from the input stream and play the audio.
    func readFromStream() {
        
        
        var status = inputStream!.read(<#T##buffer: UnsafeMutablePointer<UInt8>##UnsafeMutablePointer<UInt8>#>, maxLength: <#T##Int#>)
        
        if (status == -1) {
            let error = inputStream!.streamError
            print("\(#file) > \(#function) > Error at inputStream: \(error?.localizedDescription)")
        }
        else {
            print("\(#file) > \(#function) > Successfully read inputStream data")
        }
        
    }
    
//    func getDocumentsDirectory() -> URL {
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        let documentDirectory = paths[0]
//
//        print("\(#file) > \(#function) > Returning \(documentDirectory)")
//        return documentDirectory
//    }
    
    
    //MARK: - Button Actions
    @IBAction func endCallButtonIsClicked(_ sender: UIButton) {
        // TODO : need to stop timer from incrementing 
        print("\(#file) > \(#function) > Stopping recording")
        
        OperationQueue.main.addOperation {
            _ = self.navigationController?.popViewController(animated: true)
        }
        
        // Stop recording
        captureSession.stopRunning()
        
        // Stop the timer
        timer.invalidate()
        
        // Close the output stream
        outputStream?.close()
        inputStream?.close()
        
        // Disconnect from peer. This way the other user will be notified that the call has ended.
        appDelegate.connectionManager.sessions[sessionIndex!].disconnect()
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
            let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(self.peerID!.displayName)", preferredStyle: UIAlertControllerStyle.alert)
            
            let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (alertAction) -> Void in
                //Go back to PeerView
                self.endCallButtonIsClicked(self.endCallButton)
            }
            
            alert.addAction(okAction)
            
            OperationQueue.main.addOperation { () -> Void in
                self.present(alert, animated: true, completion: nil)
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
        print("\(#file) > \(#function) > Received inputStream from peer \(peerID.displayName)")
        if (peerID == self.peerID) {
            
            self.inputStream = inputStream
            
            self.inputStreamIsSet = true
            self.inputStream!.delegate = self
            self.inputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            self.inputStream!.open()
            
            self.outputStream!.delegate = self
            self.outputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            self.outputStream!.open()
            
            startRecording()
        }
        else {
            print("\(#file) > \(#function) > Should not print.")
        }
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
