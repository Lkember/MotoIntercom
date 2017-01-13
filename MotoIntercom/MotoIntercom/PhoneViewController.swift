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

class PhoneViewController: UIViewController, AVAudioRecorderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, ConnectionManagerDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let incomingCall = "_incoming_call_"
    
    // MARK: Properties
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var endCallButton: UIButton!
    
    var peerID: MCPeerID?
    var sessionIndex: Int?
    var outputStream: OutputStream?
    var outputStreamIsSet: Bool = false
    var isConnecting: Bool = false
    
    var streamingThread: Thread?
    var startTime = NSDate.timeIntervalSinceReferenceDate
    var timer = Timer()
    
    var captureSession: AVCaptureSession!
    var recordingSession: AVAudioSession!
    var captureDevice: AVCaptureDevice!
    var captureDeviceInput: AVCaptureDeviceInput!
//    var audioRecorder: AVAudioRecorder!
    
    override func viewDidLoad() {
        //-------------------------------------------------------------------------------
        
        if (isConnecting) {
            timerLabel.text = "Connecting..."
        }
        
        
        // Initializing recording device
        
        print("\(#file) > \(#function) > Entry")
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(errorReceivedWhileRecording), name: NSNotification.Name(rawValue: "AVCaptureSessionRuntimeError"), object: nil)
        
        // Setting the connectionManager delegate to self
        appDelegate.connectionManager.delegate = self
        
//        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
//        
//        do {
//            try captureDeviceInput = AVCaptureDeviceInput.init(device: captureDevice)
//        }
//        catch let error as NSError {
//            print("\(#file) > \(#function) > error: \(error.localizedDescription)")
//            
//            // End the call
//            endCallButtonIsClicked(endCallButton)
//        }
//        
//        captureSession.addInput(captureDeviceInput)
//        
//        // Checking recording permission
//        if ((recordingSession.recordPermission() == AVAudioSessionRecordPermission.denied)) {
//            print("\(#file) > \(#function) > Permission to record denied. Exiting.")
//            //TODO: Notify user that we do not have permission
//            
//            endCallButtonIsClicked(endCallButton)
//        }
        
        //-------------------------------------------------------------------------------
        // Calling peer
        
        sessionIndex = self.appDelegate.connectionManager.findSinglePeerSession(peer: peerID!)
        
        // sessionIndex is -1 then we are not connected to peer, so send invite
        if (sessionIndex == -1) {
            print("\(#file) > \(#function) > Calling peer.")
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
                
                print("\(#file) > \(#function) > Phone call failed")
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
        
        print("\(#file) > \(#function) > sessionIndex = \(sessionIndex)")
        
        self.navigationController?.navigationBar.isHidden = true
        
        if (outputStreamIsSet) {
            setupAVRecorder()
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    
    // A function which checks permission of recording and initializes recorder
    func setupAVRecorder() {
        
        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
        
        do {
            try captureDeviceInput = AVCaptureDeviceInput.init(device: captureDevice)
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > error: \(error.localizedDescription)")
            
            // End the call
            endCallButtonIsClicked(endCallButton)
        }
        
        captureSession.addInput(captureDeviceInput)
        
        let output = AVCaptureAudioDataOutput()
        let queue = DispatchQueue(label: "streamData")
        
        output.setSampleBufferDelegate(self, queue: queue)
        captureSession.addOutput(output)
        
        // Checking recording permission
        if ((recordingSession.recordPermission() == AVAudioSessionRecordPermission.denied)) {
            print("\(#file) > \(#function) > Permission to record denied. Exiting.")
            //TODO: Notify user that we do not have permission
            
            endCallButtonIsClicked(endCallButton)
        }
        
        
        // Attempting to set the mode to a voice chat
        do {
            try recordingSession.setMode(AVAudioSessionModeVoiceChat)
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > Error setting recording mode: \(error.localizedDescription)")
            //TODO: Notify user there was an error setting voice mode
            
            endCallButtonIsClicked(endCallButton)
        }
        
        
        do {
//            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try recordingSession.setActive(true)
            
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        print("\(#file) > \(#function) > Began recording")
                        self.startRecording()
                        self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTime), userInfo: nil, repeats: true)
                    }
                    else {
                        // failed to record
                        print("\(#file) > \(#function) > Failed to begin recording 1")
                    }
                }
                
            }
            
            
            // If output stream is not set, then create output stream
            if (!outputStreamIsSet) {
                
                do {
                    outputStream = try self.appDelegate.connectionManager.sessions[sessionIndex!].startStream(withName: "motoIntercom", toPeer: peerID!)
                    outputStreamIsSet = true
                }
                catch let error as NSError {
                    print("\(#file) > \(#function) > Failed to create outputStream: \(error.localizedDescription)")
                    outputStreamIsSet = false
                }
            }
            
        }
        catch let error as NSError {
            // TODO: Figure out what to do when recording fails
            print("\(#file) > \(#function) > Failed to begin recording: \(error.localizedDescription)")
            
            endCallButtonIsClicked(endCallButton)
        }
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
    
    
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
    }
    
    
    // MARK: Actions
    func startRecording() {
        print("\(#file) > \(#function) > Started recording")
        captureSession.startRunning()
//        print("\(#file) > \(#function) > Entry")
//        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
//        
//        let settings = [
//            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
//            AVSampleRateKey: 12000,
//            AVNumberOfChannelsKey: 1,
//            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
//        ]
//        
//        do {
//            audioRecorder = try AVAudioRecorder.init(url: audioFilename, settings: settings)
//            audioRecorder.delegate = self
//            audioRecorder.record()
//            
//        } catch let error as NSError {
//            print("\(#file) > \(#function) > Failed to start recording: \(error.localizedDescription)")
//            // Failed to record
//        }
//        print("\(#file) > \(#function) > Exit")
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
        
    }
    
    
    // Used to display how long the call has been going on for
    func updateTime() {
        let currentTime = NSDate.timeIntervalSinceReferenceDate
        
        var elapsedTime = currentTime - startTime
        
        let minutes = UInt8(elapsedTime / 60)
        elapsedTime -= (TimeInterval(minutes) * 60)
        
        let seconds = UInt8(elapsedTime)
        
        let minuteString = String(format: "%02d", minutes)
        let secondString = String(format: "%02d", seconds)
        
        timerLabel.text = "\(minuteString):\(secondString)"
    }
    
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        
        print("\(#file) > \(#function) > Returning \(documentDirectory)")
        return documentDirectory
    }
    
    
    //MARK: ButtonActions
    @IBAction func endCallButtonIsClicked(_ sender: UIButton) {
        // TODO : need to stop timer from incrementing 
        print("\(#file) > \(#function) > Stopping recording")
        
        finishRecording(success: true)
        outputStream?.close()
        
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    
    // MARK: ConnectionManagerDelegate
    func foundPeer(_ newPeer : MCPeerID) {
        // nothing to do
    }
    
    func lostPeer(_ lostPeer: MCPeerID) {
        // Nothing to do, since disconnectedFromPeer will run if lostPeer is currently connected to peer
//        if (lostPeer == self.peerID) {
//            print("\(#file) > \(#function) > Lost peer \(lostPeer.displayName). Ending call, closing output stream.")
//            finishRecording(success: true)
//            outputStream?.close()
//        }
//        else {
//            print("\(#file) > \(#function) > \(lostPeer.displayName)")
//        }
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        //TODO: Need to notify the user that someone is trying to connect
    }
    
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        
        if (peerID == self.peerID) {
            print("\(#file) > \(#function) > Connected with the current peer. Setting up AVRecorder.")
            self.timerLabel.text = "Connecting..."
            
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
                
//                _ = self.navigationController?.popViewController(animated: true)
            }
            
            alert.addAction(okAction)
            
            OperationQueue.main.addOperation { () -> Void in
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        timerLabel.text = "Connecting..."
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
