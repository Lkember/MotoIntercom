//
//  PhoneViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-12-18.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import AVFoundation
import MultipeerConnectivity

class PhoneViewController: UIViewController, AVAudioRecorderDelegate, ConnectionManagerDelegate {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    // MARK: Properties
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var endCallButton: UIButton!
    
    var peerID: MCPeerID?
    
    var streamingThread: Thread?
    var outputStream: OutputStream?
    var startTime = NSDate.timeIntervalSinceReferenceDate
    var timer = Timer()
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    
    override func viewDidLoad() {
        print("PhoneView > viewDidLoad > Entry")
        super.viewDidLoad()
        
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try recordingSession.setActive(true)
            
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        print("PhoneView > viewDidLoad > Began recording")
                        self.startRecording()
                        self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTime), userInfo: nil, repeats: true)
                    }
                    else {
                        // failed to record
                        print("PhoneView > viewDidLoad > Failed to begin recording 1")
                    }
                }
                
            }
        }
        catch {
            print("PhoneView > viewDidLoad > Failed to begin recording 1")
            // failed to record
        }
        
        self.navigationController?.navigationBar.isHidden = true
        
        print("PhoneView > viewDidLoad > Exit")
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
    
    
    // MARK: Actions
    func startRecording() {
        print("PhoneView > startRecording > Entry")
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder.init(url: audioFilename, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
            
        } catch {
            print("PhoneView > startRecording > Failed to start recording")
            // Failed to record
        }
        print("PhoneView > startRecording > Exit")
    }
    
    func finishRecording(success: Bool) {
        print("PhoneView > finishRecording > Stopping audio recording")
        // TODO: Stop the updateTime() method from working
        audioRecorder.stop()
        audioRecorder = nil
    }
    
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
        
        print("PhoneView > finishRecording > Returning \(documentDirectory)")
        return documentDirectory
    }
    
    
    //MARK: ButtonActions
    @IBAction func endCallButtonIsClicked(_ sender: UIButton) {
        // TODO : need to stop timer from incrementing 
        print("PhoneView > endCallButtonIsClicked > Stopping recording")
        
        audioRecorder.stop()
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    
    // MARK: ConnectionManagerDelegate
    func foundPeer(_ newPeer : MCPeerID) {
        //TODO: implement
    }
    
    func lostPeer(_ lostPeer: MCPeerID) {
        //TODO: implement
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        //TODO: implement
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        //TODO: implement
    }
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
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
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
