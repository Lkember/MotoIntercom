//
//  StartupViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-25.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import AVFoundation

class StartupViewController: UIViewController {
    
    // MARK: Properties
    var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    // MARK: Actions
    @IBAction func startSearching(_ sender: UIButton) {
        // Nothing to do
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
        }
        else if recordPermission == AVAudioSessionRecordPermission.granted {
            print("\(#file) > \(#function) > Record permission is granted.")
        }
    }
}
