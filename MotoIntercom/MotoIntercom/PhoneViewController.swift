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

@available(iOS 10.0, *)
class PhoneViewController: UIViewController, AVAudioRecorderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, StreamDelegate, ConnectionManagerDelegate, PeerAddedDelegate {

    // MARK: - Properties
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let incomingCall = "_incoming_call_"
    let acceptCall = "_accept_call_"
    let declineCall = "_decline_call_"
    let leavingCall = "_user_is_leaving_call_"
    let receivedStream = "_received_stream_"
    
    // Background Task to keep the app running in the background
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var backgroundTaskIsRegistered = false;

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var peerLabel: UILabel!
    @IBOutlet weak var endCallButton: UIButton!
    var nilButton: UIButton = UIButton.init()
    
    // MC
//    var peers = [MCPeerID]()
//    var peerID: MCPeerID?
//    var sessionIndex: Int?
    var didReceiveCall: Bool = false
    
    // Streams
//    var outputStreams = [OutputStream]()
//    var outputStreamIsSet: Bool = false
//    var inputStreams = [InputStream]()
//    var inputStreamIsSet: Bool = false
    
    var peerOrganizer = PeerStreamOrganizer()
    
    // Used to play audio
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
//    var peerAudioFormat: AVAudioFormat?
//    var peerAudioFormatIsSet = false
    
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
        print("\(type(of: self)) > \(#function) > Entry \(didReceiveCall)")
        super.viewDidLoad()
        
        // Setting the connectionManager delegate to self
        appDelegate.connectionManager.delegate = self
        appDelegate.connectionManager.debugSessions()
        
        if (peerOrganizer.sessionIndex! == -1) {
            print("\(type(of: self)) > \(#function) > Could not find session")
            statusLabel.text = "Calling..."
            userEndedCall = false
            disconnectedFromPeer(peerOrganizer.peers[0])
        }
        else {
            print("\(type(of: self)) > \(#function) > sessionIndex = \(peerOrganizer.sessionIndex!.description)")
            
            // When the device is up to the ear, the screen will dim
            DispatchQueue.main.async {
                UIDevice.current.isProximityMonitoringEnabled = true
            }
            
            self.prepareAudio()
            
            if (didReceiveCall) {
                statusLabel.text = "Connecting..."
                
                readyToOpenStream(peer: peerOrganizer.peers[0])
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
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("\(type(of: self)) > \(#function) > Entry")
        
        // Used to change button layouts, views, etc
        self.updateUI()
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("\(type(of: self)) > \(#function) > Entry")
        self.navigationController?.navigationBar.isHidden = true
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("\(type(of: self)) > \(#function) > Entry")
        self.navigationController?.navigationBar.isHidden = false
        print("\(type(of: self)) > \(#function) > Exit")
    }

    override func didReceiveMemoryWarning() {
        print("\(type(of: self)) > \(#function) > Entry")
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    
    // MARK: - Startup
    
    func updateUI() {
        print("\(type(of: self)) > \(#function) > Entry")
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
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    func registerBackgroundTask() {
        backgroundTaskIsRegistered = true;
        
        print("\(type(of: self)) > \(#function) > backgroundTask is registered")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != UIBackgroundTaskInvalid)
    }
    
    
    func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskInvalid
        print("\(type(of: self)) > \(#function) > Background task ended")
    }
    
    func updatePeerLabelText() {
        peerLabel.text = peerOrganizer.getPeerLabel()
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
            print("\(type(of: self)) > \(#function) > setCategory")
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: [AVAudioSessionCategoryOptions.allowBluetooth])
            print("\(type(of: self)) > \(#function) > setPreferredIOBufferDuration")
            try audioSession.setPreferredIOBufferDuration(0.001)
//            print("\(type(of: self)) > \(#function) > setPreferredNumberOfChannels")
//            try audioSession.setPreferredInputNumberOfChannels(1)
            print("\(type(of: self)) > \(#function) > setPreferredSampleRate")
            try audioSession.setPreferredSampleRate(44100)
            print("\(type(of: self)) > \(#function) > setMode")
            try audioSession.setMode(AVAudioSessionModeVoiceChat)
            print("\(type(of: self)) > \(#function) > setActive")
            try audioSession.setActive(true)
            
            print("\(type(of: self)) > \(#function) > audioSession \(audioSession)")
        }
        catch let error as NSError {
            print("\(type(of: self)) > \(#function) > Error encountered: \(error)")
        }
        
        
        // Setting up audio engine for local recording and sounds
        self.localInput = self.localAudioEngine.inputNode
        self.localAudioEngine.attach(self.localAudioPlayer)
        self.isNodeAttached = true
        self.localInputFormat = self.localInput?.inputFormat(forBus: 0)
        
        self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: localInputFormat)
        self.localAudioEngine.prepare()
        
        print("\(type(of: self)) > \(#function) > localInputFormat = \(self.localInputFormat.debugDescription)")
        print("\(type(of: self)) > \(#function) > Starting localAudioEngine")
        
        localPlayerQueue.sync {
            do {
                try self.localAudioEngine.start()
                self.localAudioPlayer.play()
            }
            catch let error as NSError {
                print("\(type(of: self)) > \(#function) > Error starting audio engine: \(error.localizedDescription)")
            }
        }
        
        print("\(type(of: self)) > \(#function) > installing tap")
        localInput?.installTap(onBus: 0, bufferSize: 17640, format: localInputFormat) {
            (buffer, when) -> Void in
            /* Calling this method so that there is less delay when the user starts speaking.
             * I was having an issue where there was about a 100-300 ms delay, however I noticed
             * if you clicked the mute button twice the delay was basically gone. Instead
             * of making the user click the button twice, it will start recording and then
             * automatically remove the tap and reinstall the tap.
            */
        }
        
        print("\(type(of: self)) > \(#function) > Removing tap")
        sleep(UInt32(0.05))
        localInput?.removeTap(onBus: 0)
        
        isAudioSetup = true
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    func updateAudioSettings() {
        print("\(type(of: self)) > \(#function) > Entry")
        self.isAudioSetup = false
        
        do {
            try audioSession.setPreferredSampleRate(44100)
        }
        catch let error as NSError {
            print("\(type(of: self)) > \(#function) > Error encountered: \(error)")
        }
        
        self.localInput = self.localAudioEngine.inputNode
        self.localInputFormat = self.localInput?.inputFormat(forBus: 0)
        
//        if (self.isNodeAttached) {
//            print("\(type(of: self)) > \(#function) > Removing node")
//            self.localAudioEngine.disconnectNodeInput(self.localAudioPlayer)
//            self.isNodeAttached = false
//        }
        
        // TODO: Will need to change if multiple audio players are created
//        if (peerAudioFormatIsSet) {
//            print("\(type(of: self)) > \(#function) > Connecting audio player to audio engine")
//            self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: peerAudioFormat)
//        }
        
        localPlayerQueue.sync {
            self.localAudioEngine.prepare()
            do {
                try self.localAudioEngine.start()
                self.localAudioPlayer.play()
            }
            catch let error as NSError {
                print("\(type(of: self)) > \(#function) > Error starting audio engine: \(error.localizedDescription)")
            }
        }
        
//        sleep(UInt32(0.05))
//        localInput?.removeTap(onBus: 0)
//        localInput?.installTap(onBus: 0, bufferSize: 17640, format: localInputFormat) {
//            (buffer, when) -> Void in
//            /* Calling this method so that there is less delay when the user starts speaking.
//             * I was having an issue where there was about a 100-300 ms delay, however I noticed
//             * if you clicked the mute button twice the delay was basically gone. Instead
//             * of making the user click the button twice, it will start recording and then
//             * automatically remove the tap and reinstall the tap.
//             * It may eventually be unnecessary
//             */
//        }
//        
//        sleep(UInt32(0.05))
//        localInput?.removeTap(onBus: 0)
        
        self.isAudioSetup = true
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    func recordAudio() {
        localPlayerQueue.sync {
            sleep(UInt32(0.05))
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
                
//                print("\(type(of: self)) > \(#function) > curr: \(sum) -- average: \(self.averageInputVolume)")
                
                if (sum > self.averageInputVolume || !self.averageInputIsSet) {
                    let data = self.audioBufferToNSData(PCMBuffer: buffer)
                    
                    var output = 0
                    for i in 0..<self.peerOrganizer.outputStreams.count {
                        print("\(type(of: self)) > \(#function) > Sending data to peer: \(sum) > \(self.averageInputVolume) ")
                        print("\(type(of: self)) > \(#function) > Stream is set = \(self.peerOrganizer.outputStreamIsSet)")
                        if (self.peerOrganizer.outputStreamIsSet[i]) {
                            let stream = self.peerOrganizer.outputStreams[i]
                            output = stream!.write(data.bytes.assumingMemoryBound(to: UInt8.self), maxLength: data.length)
                        }
                    }
                    
                    if output > 0 {
//                        print("\(type(of: self)) > \(#function) > \(output) bytes written")
                    }
                    else if output == -1 {
//                        let error = self.outputStream!.streamError
                        print("\(type(of: self)) > \(#function) > Error writing to stream")
                    }
                    else {
                        print("\(type(of: self)) > \(#function) > Cannot write to stream, stream is full")
                    }
                }
                print("\(type(of: self)) > \(#function) > Data sent")
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
        print("\(type(of: self)) > \(#function) > Error")
    }
    
    func audioHardwareRouteChanged(notification: NSNotification) {
        print("\(type(of: self)) > \(#function) > Entry \(notification.name)")
        
        DispatchQueue.main.async {
            sleep(UInt32(0.05))
            self.localInput?.removeTap(onBus: 0)
            self.updateAudioSettings()
            
            if (self.peerOrganizer.areAnyStreamsSet()) {
                print("\(type(of: self)) > \(#function) > Recording audio")
                self.recordAudio()
            }
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        print("\(type(of: self)) > \(#function) > Entry")
        if recorder.isRecording {
            recorder.pause()
            // TODO: Stop timer
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        print("\(type(of: self)) > \(#function) > Entry")
        if (peerOrganizer.areAnyStreamsSet()) {
            recorder.record()
            // TODO: Resume timer
        }
        print("\(type(of: self)) > \(#function) > Exit")
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
    }
    
    // MARK: - Timer
    
//    // Used to display how long the call has been going on for
//    func updateTime() {
//        print("\(type(of: self)) > \(#function) > Running...")
//        if (outputStreamIsSet && inputStreamIsSet) {
//            let currentTime = NSDate.timeIntervalSinceReferenceDate
//            
//            var elapsedTime = currentTime - startTime
//            
//            let minutes = UInt8(elapsedTime / 60)
//            elapsedTime -= (TimeInterval(minutes) * 60)
//            
//            let seconds = UInt8(elapsedTime)
//            
//            let minuteString = String(format: "%02d", minutes)
//            let secondString = String(format: "%02d", seconds)
//            
//            DispatchQueue.main.async {
//                self.statusLabel.text = "\(minuteString):\(secondString)"
//            }
//            
//            let second = Int(secondString)
//            
//            if (second! % 10 == 0) {
//                print("\(type(of: self)) > \(#function) > Timer updated to \(minuteString):\(secondString)")
//            }
//        }
//    }
    
    
    // MARK: - Stream
    
    func readyToOpenStream(peer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Entry")
//        let result = appDelegate.connectionManager.sendData(stringMessage: readyForStream, toPeer: peerID!)
        var dataToSend = [NSObject]()
        dataToSend.append(self.appDelegate.connectionManager.peer)
        dataToSend.append(localInputFormat!)
        
        let result = appDelegate.connectionManager.sendData(format: dataToSend, toPeer: peer, sessionIndex: peerOrganizer.sessionIndex!)
        
        if (!result) {
            print("\(type(of: self)) > \(#function) > Error sending message...")
        }
        
//        setupStream(peer: peer)
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func setupStream(peer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Creating output stream")
        
        do {
            let stream = try self.appDelegate.connectionManager.sessions[peerOrganizer.sessionIndex!].startStream(withName: "motoIntercom", toPeer: peer)
            peerOrganizer.setOutputStream(for: peer, stream: stream)
            print("\(type(of: self)) > \(#function) > OutputStream created")
        }
        catch let error as NSError {
            print("\(type(of: self)) > \(#function) > Failed to create outputStream: \(error.localizedDescription)")
            // TODO: Send streamFailed message to user
            endCallButtonIsClicked(endCallButton)
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode) {
        case Stream.Event.errorOccurred:
            print("\(type(of: self)) > \(#function) > Error has occurred on input stream")
            
            
        case Stream.Event.hasBytesAvailable:
            print("\(type(of: self)) > \(#function) > Entry")
            DispatchQueue.global().sync {
                
                let availableCount = 1024-self.testBufferCount
                
                var tempBuffer: [UInt8] = .init(repeating: 0, count: availableCount)
                let inputStream = aStream as! InputStream
                
                let index = peerOrganizer.findIndexForStream(stream: inputStream)
                if (index != -1) {
                    let format = peerOrganizer.audioFormatForPeer[index]
                    let length = inputStream.read(&tempBuffer, maxLength: availableCount)
                    
                    if (tempBuffer.count != length) {
                        tempBuffer = [UInt8](tempBuffer.dropLast(tempBuffer.count - length))
                    }
                    
                    self.testBufferCount += length
                    self.testBuffer.append(contentsOf: tempBuffer)
                    
                    print("\(type(of: self)) > \(#function) > Size of buffer: \(self.testBufferCount), amount read: \(length), available: \(availableCount - length), buffer size = \(self.testBuffer.count)")
                    
                    if (self.testBufferCount >= 1024) {
                        
                        let data = NSData.init(bytes: &self.testBuffer, length: self.testBufferCount)
                        let audioBuffer = self.dataToPCMBuffer(format: format, data: data)
                        
                        self.localAudioPlayer.scheduleBuffer(audioBuffer, completionHandler: nil)
                        
                        self.testBuffer.removeAll()
                        self.testBufferCount = 0
                    }
                }
                else {
                    print("\(type(of: self)) > \(#function) > ERROR -> COULD NOT FIND PEER")
                }
            }
            print("\(type(of: self)) > \(#function) > Exit")
        
        case Stream.Event.hasSpaceAvailable:
            print("\(type(of: self)) > \(#function) > Space available")
            break
            
            
        case Stream.Event.endEncountered:
            print("\(type(of: self)) > \(#function) > End encountered")
            
            
        case Stream.Event.openCompleted:
            if (!backgroundTaskIsRegistered) {
                registerBackgroundTask()
            }
            print("\(type(of: self)) > \(#function) > Open completed")
        
            
        default:
            print("\(type(of: self)) > \(#function) > Other")
        }
    }
    
    func dataToPCMBuffer(format: AVAudioFormat, data: NSData) -> AVAudioPCMBuffer {
        
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                           frameCapacity: UInt32(data.length) / format.streamDescription.pointee.mBytesPerFrame)
        
        audioBuffer.frameLength = audioBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: audioBuffer.floatChannelData, count: Int(audioBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return audioBuffer
    }
    
    
    //MARK: - Button Actions
    
    @IBAction func addPeerButtonIsTouched(_ sender: Any) {
        print("\(type(of: self)) > \(#function)")
        
        let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AddNewPeers") as! AddPeerViewController
        popOverView.sessionIndex = self.peerOrganizer.sessionIndex!
        self.addChildViewController(popOverView)
        
        DispatchQueue.main.async {
            popOverView.view.frame = self.view.frame
            self.view.addSubview(popOverView.view)
            popOverView.didMove(toParentViewController: self)
        }
    }
    
    
    @IBAction func muteButtonIsTouched(_ sender: Any) {
        
        print("\(type(of: self)) > \(#function) > Entry > mute: \(muteIsOn) -> \(!muteIsOn) -- isEnabled: \(muteButton.isUserInteractionEnabled)")
        
        if (muteButton.isUserInteractionEnabled == true && muteButton.isEnabled == true) {
            
            DispatchQueue.main.async {
                self.muteButton.isUserInteractionEnabled = false
                self.muteButton.isEnabled = false
            }
            
            DispatchQueue.global().sync {
                
                if (!muteIsOn) {
                    // Make the button look gray
                    print("\(type(of: self)) > \(#function) > removing tap")
                    sleep(UInt32(0.05))
                    self.localInput?.removeTap(onBus: 0)
                    print("\(type(of: self)) > \(#function) > tap removed")
                    
                    DispatchQueue.main.async {
                        self.muteButton.backgroundColor = UIColor.darkGray
                        self.muteButton.backgroundColor?.withAlphaComponent(0.5)
                    }
                    
                    muteIsOn = true
                }
                else {
                    // Make button go back to black
                    print("\(type(of: self)) > \(#function) > removing tap")
                    sleep(UInt32(0.05))
                    self.localInput?.removeTap(onBus: 0)
                    print("\(type(of: self)) > \(#function) > tap removed")
                    print("\(type(of: self)) > \(#function) > installing tap")
                    self.recordAudio()
                    print("\(type(of: self)) > \(#function) > tap installed")
                    
                    DispatchQueue.main.async {
                        self.muteButton.backgroundColor = UIColor.clear
                        self.muteButton.backgroundColor?.withAlphaComponent(1)
                    }
                    
                    muteIsOn = false
                }
            }
            
            DispatchQueue.main.async {
                self.muteButton.isEnabled = true
                self.muteButton.isUserInteractionEnabled = true
            }
        }
        print("\(type(of: self)) > \(#function) > Exit > mute: \(muteIsOn)")
    }
    
    @IBAction func speakerButtonIsTouched(_ sender: Any) {
        print("\(type(of: self)) > \(#function) > Entry \(speakerIsOn) -> \(!speakerIsOn)")
        if (!speakerIsOn) {
            speakerIsOn = true
            
            // Make the button look gray and disable the buttons
            DispatchQueue.main.async {
                
                self.speakerButton.isUserInteractionEnabled = false
                self.speakerButton.isEnabled = false
                
                self.speakerButton.backgroundColor = UIColor.darkGray
                self.speakerButton.backgroundColor?.withAlphaComponent(0.5)
            }
            
            DispatchQueue.global().sync {
                do {
                    print("\(type(of: self)) > \(#function) > Setting output to speaker")
                    try self.audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
                }
                catch let error as NSError {
                    print("\(type(of: self)) > \(#function) > Could not change to speaker: \(error.description)")
                }
            }
        }
        else {
            speakerIsOn = false
            
            // Make button go back to black
            DispatchQueue.main.async {
                
                self.speakerButton.isUserInteractionEnabled = false
                self.speakerButton.isEnabled = false
                
                self.speakerButton.backgroundColor = UIColor.clear
                self.speakerButton.backgroundColor?.withAlphaComponent(1)
            }
            
            DispatchQueue.global().sync {
                do {
                    print("\(type(of: self)) > \(#function) > Setting output to ear speaker")
                    try self.audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.none)
                }
                catch let error as NSError {
                    print("\(type(of: self)) > \(#function) > Could not change to ear speaker: \(error.description)")
                }
                
            }
        }
        
        DispatchQueue.main.async {
            self.speakerButton.isUserInteractionEnabled = true
            self.speakerButton.isEnabled = true
        }
        
        print("\(type(of: self)) > \(#function) > speaker: \(speakerIsOn)")
    }
    
    @IBAction func endCallButtonIsClicked(_ sender: UIButton) {
        print("\(type(of: self)) > \(#function) > Entry")
        if (sender == nilButton) {
            userEndedCall = false
        }
        else {
            userEndedCall = true
        }
        
        if (userEndedCall) {
            for peer in self.peerOrganizer.peers {
                _ = appDelegate.connectionManager.sendData(stringMessage: leavingCall, toPeer: peer)
            }
        }
        
        DispatchQueue.main.async {
            print("\(type(of: self)) > \(#function) > Ending call")
            self.closeAllResources()
            
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "receivedStandardMessageNotification"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "AVCaptureSessionRuntimeError"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "receivedAVAudioFormat"), object: nil)
            
            self.dismiss(animated: true, completion: nil)
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    // A function which stops recording and closes streams
    func closeAllResources() {
        print("\(type(of: self)) > \(#function) > Entry")
        
        // Ending the background task
        self.endBackgroundTask()
        
        //Stop recording and playing
        if localAudioPlayer.isPlaying {
            print("\(type(of: self)) > \(#function) > localAudioPlayer stopped")
            localAudioPlayer.stop()
        }
        
        if localAudioEngine.isRunning {
            print("\(type(of: self)) > \(#function) > localAudioEngine stopped")
            localAudioEngine.stop()
        }
        
        if (self.isNodeAttached) {
            self.localAudioEngine.detach(self.localAudioPlayer)
            self.isNodeAttached = false
        }
        
        // Stop the timer
        timer?.invalidate()
        
        // Close the output stream
        peerOrganizer.closeAllStreams()
        print("\(type(of: self)) > \(#function) > Streams closed")
        
        isAudioSetup = false
        
        self.testBufferCount = 0
        self.testBuffer.removeAll()
        
        DispatchQueue.main.async {
            UIDevice.current.isProximityMonitoringEnabled = false
        }
            
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    // MARK: - PeerAddedDelegate
    // called when peers need to be added to the call
    func peersToBeAdded(peers: [MCPeerID]) {
        print("\(type(of: self)) > \(#function) > Entry -- \(peers.count) peers to call")
        let isPhoneCall = true
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
        
        // Loop through each peer and send them an invite
        for i in 0..<peers.count {
            
            // If the peer is not already in the session, then send them an invite
            if (!self.appDelegate.connectionManager.sessions[peerOrganizer.sessionIndex!].connectedPeers.contains(peers[i])) {
                
                print("\(type(of: self)) > \(#function) > Adding peer \(peers[i].displayName)")
                self.appDelegate.connectionManager.browser.invitePeer(peers[i],
                                                                      to: self.appDelegate.connectionManager.sessions[peerOrganizer.sessionIndex!],
                                                                      withContext: dataToSend,
                                                                      timeout: 20)
                
            }
            else {
                print("\(type(of: self)) > \(#function) > Peer \(peers[i].displayName) is already in the call")
            }
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    // MARK: - ConnectionManagerDelegate
    func foundPeer(_ newPeer : MCPeerID) {
        // nothing to do
        print("\(type(of: self)) > \(#function) > \(newPeer.displayName)")
    }
    
    func lostPeer(_ lostPeer: MCPeerID) {
        // Nothing to do, since disconnectedFromPeer will run if lostPeer is currently connected to peer
        print("\(type(of: self)) > \(#function) > \(lostPeer.displayName)")
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        //TODO: Need to notify the user that someone is trying to connect
        print("\(type(of: self)) > \(#function) > \(fromPeer.displayName)")
        
        if (!self.appDelegate.connectionManager.checkIfAlreadyConnected(peerID: fromPeer)) {
            let index = self.appDelegate.connectionManager.createNewSession()
            self.appDelegate.connectionManager.invitationHandler!(true, self.appDelegate.connectionManager.sessions[index])
        }
    }
    
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Disconnected from peer: \(peerID.displayName), user ended call: \(userEndedCall)")
        
        // If the peer is in the call
        if self.peerOrganizer.peers.contains(peerID) {
            
            // If the user did not end the call and the peer is not connected, attempt to reconnect
            if (!userEndedCall && !appDelegate.connectionManager.checkIfAlreadyConnected(peerID: peerID)) {
                
                // Closing all resources if this is the only peer currently connected to (this is to save battery while reconnecting)
                if (!peerOrganizer.areAnyStreamsSet()) {
                    DispatchQueue.main.async {
                        self.closeAllResources()
                        self.statusLabel.text = "Reconnecting..."
                    }
                }
                
                // If the user is still available, then attempt a reconnect
                if (self.appDelegate.connectionManager.availablePeers.peers.contains(peerID)) {
                    print("\(type(of: self)) > \(#function) > Attempting reconnect")
//                    self.sessionIndex = self.appDelegate.connectionManager.createNewSession()
                    
                    let isPhoneCall: Bool = true
                    let dataToSend : Data = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
                    
                    self.appDelegate.connectionManager.browser.invitePeer(peerID,
                                                                          to: self.appDelegate.connectionManager.sessions[self.peerOrganizer.sessionIndex!],
                                                                          withContext: dataToSend,
                                                                          timeout: 20)
                }
                    
                // Otherwise, remove the peer from the call
                else {
                    print("\(type(of: self)) > \(#function) > Peer was lost. \(peerOrganizer.peers.count-1) peers left in call.")
                    peerOrganizer.peerWasLost(peer: peerID)
                    
                    if (peerOrganizer.peers.count == 0) {
                        endCallButtonIsClicked(self.endCallButton)
                    }
                }
            }
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > peer \(peerID.displayName)")
        
        if (peerOrganizer.peers.count == 1 && peerOrganizer.peers[0] == peerID) {
            DispatchQueue.main.async {
                self.statusLabel.text = "Connecting"
            }
            
            if !isAudioSetup {
                self.prepareAudio()
            }
        }
        else {
            var peerLabel = peerOrganizer.getPeerLabel()
            peerLabel.append("\nConnecting: \(peerID.displayName)")
            
            self.peerLabel.text = peerLabel
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        // Check if the peer is in the current session
        if (self.appDelegate.connectionManager.sessions[peerOrganizer.sessionIndex!].connectedPeers.contains(peerID)) {
            print("\(type(of: self)) > \(#function) > Connected with the current peer.")
            
            DispatchQueue.main.async {
                self.updatePeerLabelText()
            }
        
            readyToOpenStream(peer: peerID)
        }
        else {
            print("\(type(of: self)) > \(#function) > New connection to \(peerID.displayName)")
        }
        
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        
        print("\(type(of: self)) > \(#function) > Entry > Received inputStream from peer \(peerID.displayName)")
        if (self.appDelegate.connectionManager.sessions[peerOrganizer.sessionIndex!].connectedPeers.contains(peerID)) {
            
            let index = self.peerOrganizer.setInputStream(for: peerID, stream: inputStream)
            
//            let index = inputStreams.count-1
            self.peerOrganizer.inputStreams[index]!.delegate = self
            self.peerOrganizer.inputStreams[index]!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            self.peerOrganizer.inputStreams[index]!.open()
            
            self.peerOrganizer.outputStreams[index]!.delegate = self
            self.peerOrganizer.outputStreams[index]!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            self.peerOrganizer.outputStreams[index]!.open()
            
            self.recordingQueue.async {
                sleep(1)
                print("\(type(of: self)) > \(#function) > installing tap")
                self.recordAudio()
                print("\(type(of: self)) > \(#function) > tap installed")
                
                self.muteButton.isEnabled = true
                self.speakerButton.isEnabled = true
                self.addPeerButton.isEnabled = true
                
                self.muteButton.isUserInteractionEnabled = true
                self.speakerButton.isUserInteractionEnabled = true
                self.addPeerButton.isUserInteractionEnabled = true
            }
        }
        else {
            print("\(type(of: self)) > \(#function) > ERROR: Should not print.")
        }
        
        DispatchQueue.main.async {
            self.statusLabel.text = "Connected"
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func receivedStandardMessage(_ notification: Notification) {
        print("\(type(of: self)) > \(#function) > Entry \(self.peerOrganizer.peers.count)")
        
        let newMessage = notification.object as! StandardMessage
        
        // If there is only one peer
        if (peerOrganizer.peers.count == 1) {
            if (newMessage.peerID == self.peerOrganizer.peers[0]) {
                if newMessage.message == acceptCall {
                    print("\(type(of: self)) > \(#function) > Call accepted")
                    
                    if (!self.peerOrganizer.outputStreamIsSet[0]) {
                        DispatchQueue.main.async {
                            self.statusLabel.text = "Connecting..."
                        }
                    }
                }
                else if newMessage.message == declineCall {
                    print("\(type(of: self)) > \(#function) > Call declined -- Ending")
                    endCallButtonIsClicked(endCallButton)
                }
                
                else if newMessage.message == leavingCall {
                    print("\(type(of: self)) > \(#function) > Peer ended call")
                    //TODO: Need to play a sound to let the user know that the call has ended
                    endCallButtonIsClicked(nilButton)
                }
                
            }
            else {
                print("\(type(of: self)) > \(#function) > Wrong peer")
            }
            
            return
        }
        else {
            // If there are multiple peers
            if newMessage.message == acceptCall {
                print("\(type(of: self)) > \(#function) > Call accepted")
                peerOrganizer.addNewPeer(peer: newMessage.peerID!, didReceiveCall: false)
                
                DispatchQueue.main.async {
                    self.statusLabel.text = self.peerOrganizer.getPeerLabel()
                }
            }
            
            else if newMessage.message == declineCall {
                peerOrganizer.peerWasLost(peer: newMessage.peerID!)
                
                DispatchQueue.main.async {
                    self.statusLabel.text = self.peerOrganizer.getPeerLabel()
                }
                print("\(type(of: self)) > \(#function) > \(newMessage.peerID!.displayName) left the call")
//                endCallButtonIsClicked(endCallButton)
            }
                
            else if newMessage.message == leavingCall {
                print("\(type(of: self)) > \(#function) > Peer ended call")
                peerOrganizer.peerWasLost(peer: newMessage.peerID!)
                
                DispatchQueue.main.async {
                    self.statusLabel.text = self.peerOrganizer.getPeerLabel()
                }
            }
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func receivedPeerStreamInformation(_ notification: NSNotification) {
        print("\(type(of: self)) > \(#function) > Entry \(localAudioEngine.isRunning)")
        
        let data = notification.object as! [NSObject]
        let peer = data[0] as! MCPeerID
        let format = data[1] as! AVAudioFormat
        
        peerOrganizer.updateAudioFormatForPeer(peer: peer, format: format)
        
//        peerAudioFormat = data[1] as! AVAudioFormat
//        peerAudioFormatIsSet = true
        
        if (!didReceiveCall) {
            var data = [NSObject]()
            data.append(appDelegate.connectionManager.peer)
            data.append(localInputFormat!)
            _ = appDelegate.connectionManager.sendData(format: data, toPeer: peer, sessionIndex: peerOrganizer.sessionIndex!)
        }
        
        // TODO: Need to create a new audio player for the peers audio
        // Setting the format for the localAudioPlayer
        let peerAudioFormat = peerOrganizer.formatForPeer(peer: peer)
        
        self.localAudioEngine.disconnectNodeInput(self.localAudioPlayer)
        self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: peerAudioFormat)
        self.localAudioEngine.prepare()
        do {
            try self.localAudioEngine.start()
        }
        catch let error as NSError {
            print("\(type(of: self)) > \(#function) > failed to start audio engine \(error.localizedDescription)")
        }
        
        self.localAudioPlayer.play()
        
        if (!peerOrganizer.isOutputStreamSet(for: peer)) {
            self.setupStream(peer: peer)
        }
        print("\(type(of: self)) > \(#function) > Exit - \(String(describing: peerAudioFormat))")
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
