//
//  FirstViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-05.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class PeerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ConnectionManagerDelegate {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate //    let connectionManager = ConnectionManager()
    
    // MARK: Properties
    @IBOutlet weak var viewSwitch: UISwitch!
    @IBOutlet weak var peersTable: UITableView!
    
    // MARK: Actions
    @IBAction func switchView(_ sender: UISwitch) {
        if viewSwitch.isOn {
            appDelegate.connectionManager.advertiser.startAdvertisingPeer()
            print("Advertising to peers...")
        }
        else {
            appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
            print("Stopped advertising to peers.")
        }
    }
    
    // If the view disappears than stop advertising and browsing for peers.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.isMovingFromParentViewController {
            appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
            appDelegate.connectionManager.browser.stopBrowsingForPeers()
            print("Stopped advertising and browsing.")
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem?.title = "Back"
        // Do any additional setup after loading the view, typically from a nib.
        print("Starting...")
        
        peersTable.delegate = self
        peersTable.dataSource = self
        
        //set the delegate to self, and start browsing for peers
        appDelegate.connectionManager.delegate = self
        appDelegate.connectionManager.browser.startBrowsingForPeers()
        appDelegate.connectionManager.advertiser.startAdvertisingPeer()
        
        viewSwitch.isOn = true
        print("Now advertising and browsing for peers.")
    }
    
    // returns the number of sections in the table view
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    //Getting the number of rows/peers to display
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("Getting number of peers...")
        if appDelegate.connectionManager.foundPeers.count != 0 {
            return appDelegate.connectionManager.foundPeers.count
        }
        else {
            return 1
        }
    }
    
    //Displaying the peers
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        print("Displaying peer(s).")
        
        let cellIdentifier = "PeerTableViewCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as UITableViewCell
        
        print("Found \(appDelegate.connectionManager.foundPeers.count) peer(s)")
        
        if (appDelegate.connectionManager.foundPeers.count != 0) {
            cell.textLabel?.text = appDelegate.connectionManager.foundPeers[indexPath.row].displayName
            print("Set text label as: \(cell.textLabel!.text)");
            return cell
        }
        else {
            cell.textLabel?.text = "Searching for peers..."
            print("Set text label as: \(cell.textLabel!.text)")
            return cell
        }
    }
    
    //Setting the height of each row
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0;
    }
    
    //When a cell is selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("A peer has been selected")
        if (appDelegate.connectionManager.foundPeers.count != 0) {
            // get selected peer
            let selectedPeer = appDelegate.connectionManager.foundPeers[indexPath.row] as MCPeerID
            //send an invite to peer
            appDelegate.connectionManager.browser.invitePeer(selectedPeer, to: appDelegate.connectionManager.session, withContext: nil, timeout: 20)
            tableView.reloadData()
        }
        else {
            tableView.reloadData()
        }
    }
    
    // If a peer was found, then reload data
    func foundPeer() {
        print("New peer was found, updating table.")
        peersTable.reloadData()
    }
    
    // If a peer was lost, then reload data
    func lostPeer() {
        print("Peer was lost, updating table.")
        peersTable.reloadData()
    }
    
    // When an invite is received
    func inviteWasReceived(_ fromPeer : String) {
        print("Invite has been received. Displaying invite.")
        let alert = UIAlertController(title: "", message: "\(fromPeer) wants to chat with you.", preferredStyle: UIAlertControllerStyle.alert)
        
        let acceptAction: UIAlertAction = UIAlertAction(title: "Accept", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.appDelegate.connectionManager.invitationHandler!(true, self.appDelegate.connectionManager.session)
        }
        
        let declineAction: UIAlertAction = UIAlertAction(title: "Decline", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            self.appDelegate.connectionManager.invitationHandler!(false, self.appDelegate.connectionManager.session)
        }
        
        alert.addAction(acceptAction)
        alert.addAction(declineAction)
        
        OperationQueue.main.addOperation { () -> Void in
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        print("Connected to peer")
        OperationQueue.main.addOperation { () -> Void in
            self.performSegue(withIdentifier: "idSegueChat", sender: self)
        }
    }

}
