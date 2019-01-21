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
        print("\(type(of: self)) > \(#function) > Entry")
        super.viewDidLoad()
        
        let recordPermission = audioSession.recordPermission
        if recordPermission == AVAudioSession.RecordPermission.undetermined {
            print("\(type(of: self)) > \(#function) > Record permission is undetermined")
            
            let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RequestMicrophoneAccess") as! RequestRecordPermissionViewController
            self.addChild(popOverView)
            
            popOverView.view.frame = self.view.frame
            self.view.addSubview(popOverView.view)
            popOverView.didMove(toParent: self)
        }
        else if recordPermission == AVAudioSession.RecordPermission.denied {
            print("\(type(of: self)) > \(#function) > Record permission is denied. Phone calls will be disabled.")
            
            let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RequestMicrophoneAccess") as! RequestRecordPermissionViewController
            
            self.addChild(popOverView)
            
            popOverView.view.frame = self.view.frame
            self.view.addSubview(popOverView.view)
            popOverView.didMove(toParent: self)
            
            popOverView.mainLabel.text = "No Microphone Access"
            popOverView.microphoneAccessLabel.text = "You have not given this app access to your microphone. This means that you will not be able to send any audio to your peers. It is recommended to change this option by going into Settings > Privacy > Microphone and giving access to MotoIntercom."
        }
        else if recordPermission == AVAudioSession.RecordPermission.granted {
            print("\(type(of: self)) > \(#function) > Record permission is granted.")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("\(type(of: self)) > \(#function) > Entry")
        
        appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
        appDelegate.connectionManager.browser.stopBrowsingForPeers()
        appDelegate.connectionManager.cleanSessions()
        appDelegate.connectionManager.resetPeerArray()
        
        print("\(type(of: self)) > \(#function) > Stopped advertising and browsing.")
    }
}
