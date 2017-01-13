//
//  IncomingCallViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-01-04.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit

class IncomingCallViewController: UIViewController {

//    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var callDisplayNameLabel: UILabel!
    var peerIndex: Int?
    var messages: [MessageObject]?
    @IBOutlet var backgroundView: UIView!
    @IBOutlet weak var popUpView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        //only apply blur if the user hasn't disabled transparency effects
        if !UIAccessibilityIsReduceTransparencyEnabled() {
            self.backgroundView.backgroundColor = UIColor.clear
            
            let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.dark)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            
            blurEffectView.frame = self.backgroundView.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            self.backgroundView.insertSubview(blurEffectView, at: 0)
        }
        else {
            self.backgroundView.backgroundColor = UIColor.black
            self.backgroundView.alpha = 0.80
        }
        
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.popUpView.layer.cornerRadius = 10
        self.popUpView.layer.borderColor = UIColor.white.cgColor
        self.popUpView.layer.borderWidth = 2
        
        self.animate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func acceptButtonIsTouched(_ sender: UIButton) {
//        let peerIndex = getIndexForPeer(peer: fromPeer)
        print("IncomingCallView > acceptButtonIsTouched > Entry")
        messages?[peerIndex!].setConnectionTypeToVoice()
        
        if ((self.navigationController?.viewControllers.count)! >= 2) {
            let superview = navigationController?.viewControllers[(navigationController?.viewControllers.count)! - 1] as? PeerViewController
            print("IncomingCallView > acceptButtonIsTouched > Setting didAcceptCall to true")
            
//            superview!.didAcceptCall = true
            superview!.destinationPeerID = messages?[peerIndex!].peerID
            superview!.isDestPeerIDSet = true
            superview!.messages[peerIndex!].setConnectionTypeToVoice()
            
            dismissAnimate()
            
            print("\(#file) > \(#function) > Accepting Call")
            superview!.acceptCall()
        }
        
        print("IncomingCallView > acceptButtonIsTouched > Exit")
    }
    
    @IBAction func declineButtonIsTouched(_ sender: UIButton) {
        print("IncomingCallView > declineButtonIsTouched > Setting didAcceptCall to false")
        dismissAnimate()
    }
    
    
    func animate() {
        self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        self.view.alpha = 0.0;
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 1.0
            self.view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        });
    }
    
    
    func dismissAnimate()
    {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        UIView.animate(withDuration: 0.25, animations: {
            self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            self.view.alpha = 0.0;
        }, completion:{(finished : Bool)  in
            if (finished)
            {
                self.view.removeFromSuperview()
            }
        });
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
