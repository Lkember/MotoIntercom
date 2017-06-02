//
//  AddPeerViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-05-26.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

protocol PeerAddedDelegate {
    func peersToBeAdded(peers: [MCPeerID])
}

@available(iOS 10.0, *)
class AddPeerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ConnectionManagerDelegate {

    // MARK: - Properties
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let peerAddedDelegate: PeerAddedDelegate? = nil
    
    @IBOutlet weak var peerViewTable: UITableView!
    @IBOutlet var backgroundView: UIView!
    @IBOutlet weak var foregroundView: UIView!
    
    // MARK: - Views
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setting delegates
        peerViewTable.delegate = self
        peerViewTable.dataSource = self
        
        // Setting the table to allow selection of peers
        peerViewTable.layer.cornerRadius = 10
        peerViewTable.allowsSelectionDuringEditing = true
        peerViewTable.allowsMultipleSelectionDuringEditing = true
        peerViewTable.isEditing = true
        
        self.animate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
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
        
        self.foregroundView.alpha = 1.0
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addPeerButtonIsTouched(_ sender: UIButton) {
        print("\(#file) > \(#function) > Entry")
        var peersToAdd = [MCPeerID]()
        
        if let indexPaths = self.peerViewTable.indexPathsForSelectedRows?.sorted() {
            for i in 0..<indexPaths.count {
                peersToAdd.append(self.appDelegate.connectionManager.availablePeers[indexPaths[i].row])
                
                print("\(#file) > \(#function) > Adding \(self.appDelegate.connectionManager.availablePeers[indexPaths[i].row].displayName)")
            }
        }
        
        dismissAnimate()
        
        peerAddedDelegate?.peersToBeAdded(peers: peersToAdd)
        print("\(#file) > \(#function) > Exit")
    }
    
    @IBAction func cancelButtonIsTouched(_ sender: UIButton) {
        print("\(#file) > \(#function)")
        dismissAnimate()
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
    
    
    // MARK: - TableViewDelegate Methods
    
    // We only ever want 1 section -> the users available
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.appDelegate.connectionManager.availablePeers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // TODO: Need to return a cell
        let peerName = appDelegate.connectionManager.availablePeers[indexPath.row].displayName
        let cell = UITableViewCell.init()
        cell.textLabel?.text = peerName
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Nothing to do, the row will be selected automatically
    }
    
    
    // MARK: - Connection Manager Delegate
    func foundPeer(_ newPeer: MCPeerID) {
        self.peerViewTable.reloadData()
    }
    
    func lostPeer(_ lostPeer: MCPeerID) {
        self.peerViewTable.reloadData()
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        // TODO: Decide what to do
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        // Nothing to do
    }
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        // TODO: Decide what to do
    }
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        // Nothing to do
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        // Nothing to do
    }
    
    // MARK: - Navigation
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        // Get the new view controller using segue.destinationViewController.
//        // Pass the selected object to the new view controller.
//    }

}
