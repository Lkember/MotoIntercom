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

    var delegate: PeerAddedDelegate! = nil
    
    // MARK: - Properties
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let peerAddedDelegate: PeerAddedDelegate? = nil
    var sessionIndex = -1
    var peers = [MCPeerID]()
    
    // used to update the table
    var refreshControl: UIRefreshControl!
    
    @IBOutlet weak var peerViewTable: UITableView!
    @IBOutlet var backgroundView: UIView!
    @IBOutlet weak var foregroundView: UIView!
    @IBOutlet weak var addPeerButton: UIButton!
    
    // MARK: - Views
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(AddPeerViewController.refresh(sender:)), for: UIControlEvents.valueChanged)
        peerViewTable.addSubview(refreshControl)
        
        // Setting delegates
        peerViewTable.delegate = self
        peerViewTable.dataSource = self
        
        // Setting the table to allow selection of peers
        peerViewTable.layer.cornerRadius = 10
        peerViewTable.allowsSelectionDuringEditing = true
        peerViewTable.allowsMultipleSelectionDuringEditing = true
        peerViewTable.isEditing = true
        
        // Don't let the user click the button when no users are selected
        addPeerButton.isEnabled = false
        addPeerButton.isUserInteractionEnabled = false
        
        // Getting all the peers available but not in the current session
        peers = self.appDelegate.connectionManager.getPeersNotInSession(sessionIndex: sessionIndex)
        
        self.animate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Setting up the delegates and also searching and advertising to peers
        appDelegate.connectionManager.delegate = self
        appDelegate.connectionManager.browser.startBrowsingForPeers()
        appDelegate.connectionManager.advertiser.startAdvertisingPeer()
        
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
        self.foregroundView.layer.cornerRadius = 10
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addPeerButtonIsTouched(_ sender: UIButton) {
        print("\(type(of: self)) > \(#function) > Entry")
        var peersToAdd = [MCPeerID]()
        
        if let indexPaths = self.peerViewTable.indexPathsForSelectedRows?.sorted() {
            for i in 0..<indexPaths.count {
                peersToAdd.append(self.peers[indexPaths[i].row])
                
                print("\(type(of: self)) > \(#function) > Adding \(self.peers[indexPaths[i].row].displayName)")
            }
        }
        
        dismissAnimate()
        
        delegate.peersToBeAdded(peers: peersToAdd)
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    @IBAction func cancelButtonIsTouched(_ sender: UIButton) {
        print("\(type(of: self)) > \(#function)")
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
    
    //Called to refresh the table
    func refresh(sender: AnyObject) {
        print("\(type(of: self)) > \(#function) > Refreshing table")
        
        self.appDelegate.generator.impactOccurred()     // Haptic feedback when the user refreshes the screen
        
        DispatchQueue.main.async {
            self.peerViewTable.reloadData()
        }
        
        sleep(UInt32(0.5))
        refreshControl.endRefreshing()
    }
    
    // We only ever want 1 section -> the users available
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.peers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let peerName = peers[indexPath.row].displayName
        let cell = UITableViewCell.init()
        cell.textLabel?.text = peerName
        
        return cell
    }
    
    // Called when a row is selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Check to see if the addPeerButton should be enabled
        let indexPaths = tableView.indexPathForSelectedRow?.sorted()
        
        // If some users are selected, then the button can be touched
        if indexPaths!.count >= 1 {
            addPeerButton.isEnabled = true
            addPeerButton.isUserInteractionEnabled = true
        }
        else {
            addPeerButton.isEnabled = false
            addPeerButton.isUserInteractionEnabled = false
        }
    }
    
    
    // MARK: - Connection Manager Delegate
    func foundPeer(_ newPeer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > \(newPeer.displayName)")
        peers = self.appDelegate.connectionManager.getPeersNotInSession(sessionIndex: sessionIndex)
        self.peerViewTable.reloadData()
    }
    
    func lostPeer(_ lostPeer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > \(lostPeer.displayName)")
        peers = self.appDelegate.connectionManager.getPeersNotInSession(sessionIndex: sessionIndex)
        self.peerViewTable.reloadData()
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: UInt8) {
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
