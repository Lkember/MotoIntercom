//
//  IncomingCallViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-01-04.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit

@available(iOS 10.0, *)
class IncomingCallViewController: UIViewController {
    
    var appDelegate: AppDelegate = AppDelegate.init()
    
    @IBOutlet weak var callDisplayNameLabel: UILabel!
    @IBOutlet weak var peerDisplayNameLabel: UILabel!
    var peerIndex: Int?
    var messages: [MessageObject]?
    var peerDisplayName: String?
    @IBOutlet var backgroundView: UIView!
    @IBOutlet weak var popUpView: UIView!
    
    // Used to determine if the invitation is invalid
    var timer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timer = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(self.declineButtonIsTouched(_:)), userInfo: nil, repeats: false)
    
        // Do any additional setup after loading the view.
        peerDisplayNameLabel.text = peerDisplayName!
        
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.popUpView.layer.cornerRadius = 10
        self.popUpView.layer.borderColor = UIColor.white.cgColor
        self.popUpView.layer.borderWidth = 2
        
        NotificationCenter.default.addObserver(self, selector: #selector(declineButtonIsTouched(_:)), name: NSNotification.Name(rawValue: "peerEndedCall"), object: nil)
        
        self.animate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func acceptButtonIsTouched(_ sender: UIButton) {
//        let peerIndex = getIndexForPeer(peer: fromPeer)
        print("\(type(of: self)) > \(#function) > Entry")
        
        timer.invalidate()
        
        if ((self.navigationController?.viewControllers.count)! >= 2) {
            let superview = navigationController?.viewControllers[(navigationController?.viewControllers.count)! - 1] as? PeerViewController
        
            var index = -1
        
            if (!self.appDelegate.connectionManager.checkIfAlreadyConnected(peerID: messages![peerIndex!].peerID)) {
                print("\(type(of: self)) > \(#function) > Accepting invitation")
                index = self.appDelegate.connectionManager.createNewSession()
                
                if self.appDelegate.connectionManager.invitationHandler != nil {
                    self.appDelegate.connectionManager.invitationHandler!(true, self.appDelegate.connectionManager.sessions[index])
                }
            }
            else {
                print("\(type(of: self)) > \(#function) > Already connected")
                index = peerIndex!
            }
                
            superview!.destinationPeerID = messages?[index].peerID
            superview!.isDestPeerIDSet = true
            superview!.messages[peerIndex!].setConnectionTypeToVoice()
            superview!.didAcceptCall = true
            
            dismissAnimate()
        
            print("\(type(of: self)) > \(#function) > Accepting Call")
            superview!.acceptCall()
        }
        else {
            print("\(type(of: self)) > \(#function) > Failed to accept invitation.")
            //TODO: Notify user that connection failed
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    @IBAction func declineButtonIsTouched(_ sender: UIButton) {
        print("\(type(of: self)) > \(#function)")
        timer.invalidate()
        
        DispatchQueue.main.async {
            if ((self.navigationController?.viewControllers.count)! >= 2) {
                let superview = self.navigationController?.viewControllers[(self.navigationController?.viewControllers.count)! - 1] as? PeerViewController
                
                superview!.destinationPeerID = self.messages?[self.peerIndex!].peerID
                
                self.dismissAnimate()
                
                superview!.didAcceptCall = false
                superview!.declineCall()
                
                NotificationCenter.default.removeObserver(self)
                
                print("\(type(of: self)) > \(#function) > Setting didAcceptCall to false")
            }
            else {
                print("\(type(of: self)) > \(#function) > superview could not be found.")
                NotificationCenter.default.removeObserver(self)
                self.dismissAnimate()
            }
        }
    }
    
    // MARK: - Animation
    
    func animate() {
        self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        self.view.alpha = 0.0;
        UIView.animate(withDuration: 0.5, animations: {
            self.view.alpha = 1.0
            self.view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        });
    }
    
    
    func dismissAnimate()
    {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        UIView.animate(withDuration: 0.5, animations: {
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
