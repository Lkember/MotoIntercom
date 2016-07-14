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
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let connectionManager = ConnectionManager()
    
    // MARK: Properties
    @IBOutlet weak var peersTable: UITableView!
//    @IBOutlet weak var peersCell: UITableViewCell!
    @IBOutlet weak var viewSwitch: UISwitch!
    @IBOutlet weak var deviceName: UILabel!
    
    
    // MARK: Actions
    @IBAction func switchView(sender: UISwitch) {
        if viewSwitch.on {
            appDelegate.connectionManager.advertiser.startAdvertisingPeer()
        }
        else {
            appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
        }
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        print("Starting...")
        //set the delegate to self, and start browsing for peers
        appDelegate.connectionManager.delegate = self
        appDelegate.connectionManager.browser.startBrowsingForPeers()
    }
    
    // returns the number of sections in the table view
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    //Getting the number of rows/peers to display
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if appDelegate.connectionManager.foundPeers.count != 0 {
            return appDelegate.connectionManager.foundPeers.count
        }
        else {
            return 1
        }
    }
    
    //Displaying the peers
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) ->UITableViewCell {
        
        print("Searching and displaying peers.")
        
        let cellIdentifier = "PeerTableViewCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as UITableViewCell
        
        print("Found \(appDelegate.connectionManager.foundPeers.count) peer(s)")
        
        if (appDelegate.connectionManager.foundPeers.count != 0) {
            cell.textLabel?.text = appDelegate.connectionManager.foundPeers[indexPath.row].displayName
            print("Set text label as: \(cell.textLabel!.text)");
            return cell
        }
        else {
            cell.textLabel?.text = "Searching for devices..."
            print("Set text label as Searching for devices")
            return cell
        }
    }
    
    //Setting the height of each row
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60.0;
    }
    
    //When a cell is selected
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (appDelegate.connectionManager.foundPeers.count != 0) {
            // get selected peer
            let selectedPeer = appDelegate.connectionManager.foundPeers[indexPath.row] as MCPeerID
            //send an invite to peer
            appDelegate.connectionManager.browser.invitePeer(selectedPeer, toSession: appDelegate.connectionManager.session, withContext: nil, timeout: 20)
        }
        else {
            // do nothing
        }
    }
    
    // If a peer was found, then reload data
    func foundPeer() {
        peersTable.reloadData()
    }
    
    // If a peer was lost, then reload data
    func lostPeer() {
        peersTable.reloadData()
    }
    
    // When an invite is received
    func inviteWasReceived(fromPeer : String) {
        let alert = UIAlertController(title: "", message: "\(fromPeer) wants to chat with you.", preferredStyle: UIAlertControllerStyle.Alert)
        
        let acceptAction: UIAlertAction = UIAlertAction(title: "Accept", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.appDelegate.connectionManager.invitationHandler!(true, self.appDelegate.connectionManager.session)
        }
        
        let declineAction: UIAlertAction = UIAlertAction(title: "Decline", style: UIAlertActionStyle.Cancel) { (alertAction) -> Void in
            self.appDelegate.connectionManager.invitationHandler!(false, self.appDelegate.connectionManager.session)
        }
        
        alert.addAction(acceptAction)
        alert.addAction(declineAction)
        
        NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func connectedWithPeer(peerID : MCPeerID) {
        NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
            self.performSegueWithIdentifier("idSegueChat", sender: self)
        }
    }

}

extension PeerViewController : MCNearbyServiceBrowserDelegate {
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print( "foundPeer: \(peerID)")
        print( "invitePeer: \(peerID)")
        //This could be wrong, supposed to be self.session
        browser.invitePeer(peerID, toSession: connectionManager.session, withContext: nil, timeout: 10)
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
    }
}