//
//  StartupViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-25.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import AVFoundation

@available(iOS 10.0, *)
class StartupViewController: UIViewController {
    
    // MARK: Properties
    var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    // MARK: Actions
    @IBAction func startSearching(_ sender: UIButton) {
        DispatchQueue.global().sync {
            appDelegate.generator.impactOccurred()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        navigationItem.backBarButtonItem?.title = "Stop Search"
    }
    
    override func viewDidLoad() {
        print("\(#file) > \(#function) > Entry")
        super.viewDidLoad()
        
        let recordPermission = audioSession.recordPermission()
        if recordPermission == AVAudioSessionRecordPermission.undetermined {
            print("\(#file) > \(#function) > Record permission is undetermined")
            
            let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RequestMicrophoneAccess") as! RequestRecordPermissionViewController
            self.addChildViewController(popOverView)
            
            popOverView.view.frame = self.view.frame
            self.view.addSubview(popOverView.view)
            popOverView.didMove(toParentViewController: self)
        }
        else if recordPermission == AVAudioSessionRecordPermission.denied {
            print("\(#file) > \(#function) > Record permission is denied. Phone calls will be disabled.")
            
            let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RequestMicrophoneAccess") as! RequestRecordPermissionViewController
            
            self.addChildViewController(popOverView)
            
            popOverView.view.frame = self.view.frame
            self.view.addSubview(popOverView.view)
            popOverView.didMove(toParentViewController: self)
            
            popOverView.mainLabel.text = "No Microphone Access"
            popOverView.microphoneAccessLabel.text = "You have not given this app access to your microphone. This means that you will not be able to send any audio to your peers. It is recommended to change this option by going into Settings > Privacy > Microphone and giving access to MotoIntercom."
        }
        else if recordPermission == AVAudioSessionRecordPermission.granted {
            print("\(#file) > \(#function) > Record permission is granted.")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if self.isMovingFromParentViewController {
            appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
            appDelegate.connectionManager.browser.stopBrowsingForPeers()
            appDelegate.connectionManager.cleanSessions()
            appDelegate.connectionManager.resetPeerArray()
            
            print("\(#file) > \(#function) > Stopped advertising and browsing.")
        }
    }
}
