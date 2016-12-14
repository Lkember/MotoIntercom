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
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let endChat = "_end_chat_"
    
    // MARK: Properties
    @IBOutlet weak var viewSwitch: UISwitch!
    @IBOutlet weak var peersTable: UITableView!
    var refreshControl: UIRefreshControl!
    var messages = [MessageObject]()
    
    var destinationPeerID: MCPeerID?
    var isDestPeerIDSet = false
    
    // MARK: Actions
    @IBAction func switchView(_ sender: UISwitch) {
        if viewSwitch.isOn {
            appDelegate.connectionManager.advertiser.startAdvertisingPeer()
            print("PeerView > switchView > Advertising to peers...")
        }
        else {
            appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
            print("PeerView > switchView > Stopped advertising to peers.")
        }
    }
    
    
    // A function which returns the index for a given peer
    func getIndexForPeer(peer: MCPeerID) -> Int {
        for i in 0..<messages.count {
            if (messages[i].peerID == peer) {
                return i
            }
        }
        return -1
    }
    
    //MARK: View Functions
    // If the view disappears than stop advertising and browsing for peers.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.isMovingFromParentViewController {
            appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
            appDelegate.connectionManager.browser.stopBrowsingForPeers()
            print("peerView > viewWillDisappear > Stopped advertising and browsing.")
        }
        
//        appDelegate.connectionManager.resetPeerArray()
//        print("PeerView > viewWillDisappear > Resetting table")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("PeerView > viewDidLoad > Resetting peer array.")
        appDelegate.connectionManager.resetPeerArray()
        navigationItem.leftBarButtonItem?.title = "Back"
        
        peersTable.delegate = self
        peersTable.dataSource = self
        
        refreshControl = UIRefreshControl()
//        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(PeerViewController.refresh(sender:)), for: UIControlEvents.valueChanged)
        
        peersTable.addSubview(refreshControl)
        
        //set the delegate to self, and start browsing for peers
        appDelegate.connectionManager.delegate = self
        appDelegate.connectionManager.browser.startBrowsingForPeers()
        appDelegate.connectionManager.advertiser.startAdvertisingPeer()
        
        //Adding an observer for when data is received
        NotificationCenter.default.addObserver(self, selector: #selector(handleMPCReceivedDataWithNotification(_:)), name: NSNotification.Name(rawValue: "receivedMPCDataNotification"), object: nil)
        
        viewSwitch.isOn = true
        print("PeerView > viewDidLoad > Advertising and browsing for peers.")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        appDelegate.connectionManager.browser.startBrowsingForPeers()
        appDelegate.connectionManager.advertiser.startAdvertisingPeer()
        
        viewSwitch.isOn = true
        
        peersTable.reloadData()
        
        print("PeerView > viewDidAppear > Advertising and browsing for peers.")
    }
    
    //Called to refresh the table
    func refresh(sender: AnyObject) {
        print("PeerView > refresh > Refreshing table")
        peersTable.reloadData()
        refreshControl.endRefreshing()
    }
    
    
    func handleMPCReceivedDataWithNotification(_ notification: Notification) {
        print("PeerView > handleMPCReceivedDataWithNotification > Entry")
        
        if let _ = navigationController?.visibleViewController as? PeerViewController {
            let dictionary = NSKeyedUnarchiver.unarchiveObject(with: notification.object as! Data) as! [String: Any]
            
    //        let test = NSKeyedUnarchiver.unarchiveObject(with: dictionary) as! [String: Any]
    //        let newMessage = NSKeyedUnarchiver.unarchiveObject(with: notification.object as! Data) as! MessageObject
            
            let newMessage = NSKeyedUnarchiver.unarchiveObject(with: dictionary["data"] as! Data) as! MessageObject
            
    //        let newMessage = dictionary["data"] as! MessageObject
            let fromPeer = dictionary["peer"] as! MCPeerID
            
            print("PeerView > handleMPCReceivedDataWithNotification > message: \(newMessage.messages[0]) from \(fromPeer)")
            
            if newMessage.messages[0] != endChat {
                
                let peerIndex = getIndexForPeer(peer: fromPeer)
                
                messages[peerIndex].messages.append(newMessage.messages[0])
                messages[peerIndex].messageIsFrom.append(newMessage.messageIsFrom[0])
                print("PeerView > handleMPCReceivedDataWithNotification > Adding new message to transcript")
                
                peersTable.reloadRows(at: [IndexPath.init(row: peerIndex, section: 0)], with: .fade)
            }
        }
        
        print("PeerView > handleMPCReceivedDataWithNotification > Exit")
    }
    
    
    
    // MARK: TableDelegate Methods
    
    // returns the number of sections in the table view
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    //Getting the number of rows/peers to display
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("PeerView > numberOfRowsInSection > Entry \(section)")
        if (section == 0) {
            var count = 0
            
            for session in appDelegate.connectionManager.sessions {
                if session.connectedPeers.count != 0 {
                    count += 1
                }
            }
            
            print("PeerView > numberOfRowsInSection > Exit \(count)")
//            return appDelegate.connectionManager.foundPeers.count
            
            return count
        }
        else {
            if appDelegate.connectionManager.foundPeers.count != 0 {
                let numPeers = appDelegate.connectionManager.foundPeers.count
                print("PeerView > numberOfRowsInSection > Exit - \(numPeers) peer(s)")
                return numPeers
            }
            else {
                print("PeerView > numberOfRowsInSection > Exit - No peers found")
                return 1
            }
        }
    }
    
    //Getting the title for the current section
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0) {
            
            var count = 0
            for session in appDelegate.connectionManager.sessions {
                if (session.connectedPeers.count != 0) {
                    count += 1
                    break
                }
            }
            
//            if (count != 0) {
                return "Available"
//            }
        }
        else if (section == 1) {
            return "Unavailable"
        }
        else {
            return "Past Conversations"
        }
    }
    
    //Displaying the peers
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        
//        print("PeerView > cellForRowAt > Entry")
//        
//        let cellIdentifier = "PeerTableViewCell"
//        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as UITableViewCell
//        
//        print("PeerView > cellForRowAt > Found \(appDelegate.connectionManager.foundPeers.count) peer(s), connected to \(appDelegate.connectionManager.session.connectedPeers.count) peer(s)")
//        
//        if (indexPath.section == 1) {
//        
//            if (appDelegate.connectionManager.foundPeers.count != 0) {
//                cell.textLabel?.text = appDelegate.connectionManager.foundPeers[indexPath.row].displayName
//                print("PeerView > cellForRowAt > Set text label as: \(cell.textLabel!.text)");
//                cell.selectionStyle = UITableViewCellSelectionStyle.blue
//                return cell
//            }
//            else {
//                cell.textLabel?.text = "Searching for peers..."
//                cell.selectionStyle = UITableViewCellSelectionStyle.none
//                return cell
//            }
//        }
//        else {
//            cell.textLabel?.text = appDelegate.connectionManager.session.connectedPeers[indexPath.row].displayName
//            print("PeerView > cellForRowAt > Set text label as: \(cell.textLabel!.text)")
//            cell.selectionStyle = UITableViewCellSelectionStyle.blue
//            return cell
//        }
//    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        print("PeerView > cellForRowAt > Entry")
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell") as! PeerTableViewCell
        
        print("PeerView > cellForRowAt > Found \(appDelegate.connectionManager.foundPeers.count) peer(s), # of sessions \(appDelegate.connectionManager.sessions.count)")
        
        if (indexPath.section == 1) {   // Then the peer is available but is not connected to
            
            if (appDelegate.connectionManager.foundPeers.count != 0) {
                print("PeerView > cellForRowAt > Set text label as: \(appDelegate.connectionManager.foundPeers[indexPath.row].displayName)");
                cell.setPeerDisplayName(displayName: appDelegate.connectionManager.foundPeers[indexPath.row].displayName)
                cell.selectionStyle = UITableViewCellSelectionStyle.blue
                cell.peerIsAvailable()
                
                var isHistory = false
                for message in messages {
                    if message.peerID == appDelegate.connectionManager.foundPeers[indexPath.row] {
                        
                        isHistory = true
                        
                        if (message.messages.count != 0) {
                            cell.setLatestMessage(latestMessage: message.messages[message.messages.count-1])
                            break
                        }
                        else {
                            cell.setLatestMessage(latestMessage: "No history")
                            break
                        }
                    }
                }
                
                if (!isHistory) {
                    cell.setLatestMessage(latestMessage: "No history")
                }
                
                //TODO: Add tap gesture recognizer
                
                return cell
            }
            else {
                let cellIdentifier = "PeerTableViewCell"
                let tempCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as UITableViewCell
                
                tempCell.textLabel?.text = "Searching for peers..."
                tempCell.selectionStyle = UITableViewCellSelectionStyle.none
                return tempCell
            }
        }
        else {  // The peer is currently connected to
            //TODO: Must change if allowed to connect to multiple users in one chat
            print("PeerView > cellForRowAt > # of connectedPeers in session = \(appDelegate.connectionManager.sessions[indexPath.row].connectedPeers.count)")
            cell.setPeerDisplayName(displayName: appDelegate.connectionManager.sessions[indexPath.row].connectedPeers[0].displayName)
            
            let index = getIndexForPeer(peer: appDelegate.connectionManager.sessions[indexPath.row].connectedPeers[0])
            let messagesIndex = messages[index].messages.count-1
            
            cell.setLatestMessage(latestMessage: messages[index].messages[messagesIndex])
            
            print("PeerView > cellForRowAt > Set text label as: \(cell.peerDisplayNameLabel?.text)")
            cell.peerIsAvailable()
            
            // TODO: Add tap gesture recognizer
            
            cell.selectionStyle = UITableViewCellSelectionStyle.blue
            return cell
        }
    }
    
    //Setting the height of each row
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath.section == 1) {
            if (appDelegate.connectionManager.foundPeers.count != 0) {
                return 70.0
            }
            else {
                return 60.0
            }
        }
        else {
            return 70
        }
    }
    
    //When a cell is selected
    //TODO
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("PeerView > didSelectRowAt > A peer has been selected")
        if (indexPath.section == 0) {
            print("PeerView > didSelectRowAt > Performing segue...")
            OperationQueue.main.addOperation { () -> Void in
                self.performSegue(withIdentifier: "idChatSegue", sender: self)
            }
        }
        else {
            if (appDelegate.connectionManager.foundPeers.count != 0) {
                // get selected peer
                let selectedPeer = appDelegate.connectionManager.foundPeers[indexPath.row] as MCPeerID
                
                print("PeerView > didSelectRowAt > attempting to connect to peer \(selectedPeer.displayName)")
                
                //TODO: Create new session first
                let index = appDelegate.connectionManager.createNewSession()
//                let index = appDelegate.connectionManager.sessions.count-1
                
                //Send invite to peer
                appDelegate.connectionManager.browser.invitePeer(selectedPeer, to: appDelegate.connectionManager.sessions[index], withContext: nil, timeout: 20)
                
                //TODO: If the peer declines the invitation then delete the session.
                tableView.reloadData()
            }
            else {
                tableView.reloadData()
            }
        }
    }
    
    
    
    //MARK: Connection Manager
    
    // If a peer was found, then reload data
    func foundPeer() {
        print("PeerView > foundPeer > Entry")
        peersTable.reloadData()
        print("PeerView > foundPeer > Exit")
    }
    
    // If a peer was lost, then reload data
    func lostPeer() {
        print("PeerView > lostPeer > Entry")
        appDelegate.connectionManager.cleanSessions()
        peersTable.reloadData()
        print("PeerView > lostPeer > Exit")
    }
    
    // When an invite is received
    func inviteWasReceived(_ fromPeer : MCPeerID) {
        print("PeerView > inviteWasReceived > Entry")
        let alert = UIAlertController(title: "", message: "\(fromPeer.displayName) wants to chat with you.", preferredStyle: UIAlertControllerStyle.alert)
        
        let acceptAction: UIAlertAction = UIAlertAction(title: "Accept", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            
            print("PeerView > inviteWasReceived > User selected Accept")
            
            let index = self.appDelegate.connectionManager.createNewSession()
                
            print("PeerView > inviteWasReceived > Accepted invitation handler")
            self.appDelegate.connectionManager.invitationHandler!(true, self.appDelegate.connectionManager.sessions[index])
        }
        
        let declineAction: UIAlertAction = UIAlertAction(title: "Decline", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
            var sess : MCSession?
            
            for session in self.appDelegate.connectionManager.sessions {
                if session.connectedPeers.contains(fromPeer) {
                    sess = session
                }
            }
            
            self.appDelegate.connectionManager.invitationHandler!(false, sess!)
        }
        
        alert.addAction(acceptAction)
        alert.addAction(declineAction)
        
        OperationQueue.main.addOperation { () -> Void in
            self.present(alert, animated: true, completion: nil)
        }
        print("PeerView > foundPeer > Exit")
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        print("PeerView > connectedWithPeer > Connected to peer \(peerID)")
//        appDelegate.connectionManager.session.connectedPeers.append(peerID)
        appDelegate.connectionManager.removeFoundPeer(peerID: peerID)
        
        destinationPeerID = peerID  // This is used so we know what peer was clicked on
        isDestPeerIDSet = true
        
        OperationQueue.main.addOperation {
            self.performSegue(withIdentifier: "idChatSegue", sender: self)
        }
    }
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("PeerView > disconnectedFromPeer > Disconnected from peer \(peerID)")
        
        if let currView = navigationController?.topViewController as? ChatViewController {
            print("PeerView > disconnectedFromPeeer > topViewController is ChatView. ")
            if (peerID == currView.messages.peerID) {
                let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(currView.messages.peerID.displayName)", preferredStyle: UIAlertControllerStyle.alert)

                let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (alertAction) -> Void in

                    //Go back to PeerView
                    _ = self.navigationController?.popViewController(animated: true)
                }

                alert.addAction(okAction)

                OperationQueue.main.addOperation { () -> Void in
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        else {
            print("PeerView > disconnectedFromPeer > Reloading peer table.")
            peersTable.reloadSections(IndexSet.init(integer: 0), with: .fade)
        }
        
//        if ((navigationController?.isViewLoaded)! && ((navigationController?.view.window != nil))) {
//            print("PeerView > disconnectedFromPeer > Reloading peer table.")
//            peersTable.reloadSections(IndexSet.init(integer: 0), with: .fade)
//        }
//        else {
//            print("PeerView > disconnectedFromPeeer > topViewController is ChatView. ")
//            
//            if let currView = navigationController?.topViewController as? ChatViewController {
//                if (peerID == currView.messages.peerID) {
//                    let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(currView.messages.peerID.displayName)", preferredStyle: UIAlertControllerStyle.alert)
//                    
//                    let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (alertAction) -> Void in
//                        
//                        //Go back to PeerView
//                        _ = self.navigationController?.popViewController(animated: true)
//                    }
//                    
//                    alert.addAction(okAction)
//                    
//                    OperationQueue.main.addOperation { () -> Void in
//                        self.present(alert, animated: true, completion: nil)
//                    }
//                }
//            }
//            
//        }
    }
    
    //MARK: Segue
    
    // This function is run before a segue is performed
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("PeerView > prepare > Entry: destinationPeerID = \(destinationPeerID)")
        if (segue.identifier == "idChatSegue" && isDestPeerIDSet) {
            let dest = segue.destination as? ChatViewController
            
            var messageIsSet = false
            
            for message in messages {
                print("PeerView > prepare > Currently looking at messages from peer \(message.peerID)")
                if (message.peerID == destinationPeerID) {
                    dest?.messages = message
                    messageIsSet = true
                    
                    print("PeerView > prepare > # of messages \(message.messages.count)")
                    break
                }
            }
            
            if (messageIsSet == false) {
                let newMessageObject = MessageObject.init(peerID: destinationPeerID!, messageFrom: [], messages: [])
                messages.append(newMessageObject)
                
                print("PeerView > prepare > Could not find message object. Creating a new message object.")
                
                dest!.messages = self.messages[messages.count-1]
            }
        }
        print("PeerView > prepare > Exit")
    }
}
