//
//  FirstViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-05.
//  Copyright © 2016 Logan Kember. All rights reserved.

import UIKit
import MultipeerConnectivity
import AudioToolbox             // For sound and vibration
import JSQMessagesViewController

@available(iOS 10.0, *)
class PeerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ConnectionManagerDelegate {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let incomingCall = "_incoming_call_"
    let acceptedCall = "_accept_call_"
    let declinedCall = "_decline_call_"
    
    // MARK: - Properties
    @IBOutlet weak var peersTable: UITableView!
    var refreshControl: UIRefreshControl!
    var messages = [MessageObject]()
    var newMessage: [MCPeerID] = []
    
    var UNSPECIFIED_CONNECTION_TYPE = 0
    var MESSAGE_CONNECTION_TYPE = 1
    var PHONE_CONNECTION_TYPE = 2
    
    var destinationPeerID: MCPeerID?
    var isDestPeerIDSet = false
    var didAcceptCall = false
    
    
    //MARK: - View Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let loadedData = load() {
            messages = loadedData
        }
        
        // Setting the connectionManager delegate to self
        appDelegate.connectionManager.delegate = self
        
        print("\(#file) > \(#function) > Resetting peer array.")
        appDelegate.connectionManager.resetPeerArray()
        navigationItem.leftBarButtonItem?.title = "Back"
        
        peersTable.delegate = self
        peersTable.dataSource = self
        
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        
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
        
        isDestPeerIDSet = false
        didAcceptCall = false
        print("\(#file) > \(#function) > Advertising and browsing for peers. Thread: \(Thread.current)")
    }
    
    
    // If the view disappears than stop advertising and browsing for peers.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.isMovingFromParentViewController {
            appDelegate.connectionManager.advertiser.stopAdvertisingPeer()
            appDelegate.connectionManager.browser.stopBrowsingForPeers()
            appDelegate.connectionManager.cleanSessions()
            
            print("\(#file) > \(#function) > Stopped advertising and browsing.")
        }
        
        //        appDelegate.connectionManager.resetPeerArray()
        //        print("\(#file) > \(#function) viewWillDisappear > Resetting table")
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        print("\(#file) > \(#function) > Entry")
        
        // Setting the connectionManager delegate to self
        appDelegate.connectionManager.delegate = self
        
        appDelegate.connectionManager.browser.startBrowsingForPeers()
        appDelegate.connectionManager.advertiser.startAdvertisingPeer()
        
        DispatchQueue.main.async {
            self.peersTable.reloadData()
        }
        
        isDestPeerIDSet = false
        didAcceptCall = false
        destinationPeerID = nil
        
        print("\(#file) > \(#function) > Exit: Advertising and browsing for peers.")
    }
    
    
    // MARK: - Actions
    
    
    // A function which returns the index for a given peer
    func getIndexForPeer(peer: MCPeerID) -> Int {
        for i in 0..<messages.count {
            if (messages[i].peerID == peer) {
                return i
            }
        }
        return -1
    }
    
    // A function which checks if a message object exists for the current peer
    func doesMessageObjectExist(forPeer: MCPeerID) -> Int {
        for i in 0..<messages.count {
            if (messages[i].peerID == forPeer) {
                return i
            }
        }
        return -1
    }
    
    
    func getNumberOfAvailablePeers() -> Int {
        var count = 0
        
        for message in messages {
            if message.isAvailable {
                count += 1
            }
        }
        return count
    }
    
    
    // Function used when the user accepts a call
    func acceptCall() {
        print("\(#file) > \(#function) > Entry")
        
        // If a call has been accepted
        OperationQueue.main.addOperation { () -> Void in
            print("\(#file) > \(#function) > Performing callSegue")
            super.performSegue(withIdentifier: "callSegue", sender: self)
        }
        
        _ = appDelegate.connectionManager.sendData(stringMessage: acceptedCall, toPeer: destinationPeerID!)
        print("\(#file) > \(#function) > Exit")
    }
    
    func declineCall() {
        print("\(#file) > \(#function) > Entry")
        
        _ = appDelegate.connectionManager.sendData(stringMessage: declinedCall, toPeer: destinationPeerID!)
        destinationPeerID = nil
        
        print("\(#file) > \(#function) > Exit")
    }
    
    
    // A function which returns an array of all available peers and all unavailable peers
    
    func getAllPeers() -> [[MessageObject]] {
        var availablePeers : [MessageObject] = []
        var unavailablePeers : [MessageObject] = []
        
        for message in messages {
            if (message.isAvailable) {
                availablePeers.append(message)
            }
            else {
                unavailablePeers.append(message)
            }
        }
        
        let allPeers: [[MessageObject]] = [availablePeers, unavailablePeers]
        
        return allPeers
    }
    
    
    //Called to refresh the table
    func refresh(sender: AnyObject) {
        print("\(#file) > \(#function) > Refreshing table")
        
        self.appDelegate.generator.impactOccurred()     // Haptic feedback when the user refreshes the screen
        
        DispatchQueue.main.async {
            self.peersTable.reloadData()
        }
        
        refreshControl.endRefreshing()
    }
    
    
    func handleMPCReceivedDataWithNotification(_ notification: Notification) {
        print("\(#file) > \(#function) > Entry")
        
        if let _ = navigationController?.visibleViewController as? PeerViewController {
            print("\(#file) > \(#function) > PeerViewController is visible controller.")
            
            let dictionary = NSKeyedUnarchiver.unarchiveObject(with: notification.object as! Data) as! [String: Any]
            
            // If the incoming message is a MessageObject than do the following
            if let newMessage = NSKeyedUnarchiver.unarchiveObject(with: dictionary["data"] as! Data) as? MessageObject {
            
                let fromPeer = dictionary["peer"] as! MCPeerID
                let peerIndex = getIndexForPeer(peer: fromPeer)
            
                print("\(#file) > \(#function) > message: \(newMessage.messages[0].text), peerID \(newMessage.peerID.displayName), selfID \(newMessage.selfID.displayName)")
                messages[peerIndex].messages.append(newMessage.messages[0])
                
                save()
                
                //Vibrate
                JSQSystemSoundPlayer.jsq_playMessageReceivedAlert()
                
                //Changes to UI must be done by main thread
                DispatchQueue.main.async {
                    if (!self.newMessage.contains(fromPeer)) {
                        self.newMessage.append(fromPeer)
                    }
                    
                    let numRows = self.peersTable.numberOfRows(inSection: 0)
                    var indexPathsToUpdate: [IndexPath] = []
                    
                    for i in 0..<numRows {
                        indexPathsToUpdate.append(IndexPath.init(row: i, section: 0))
                        
                        let currIndexPath = IndexPath.init(row: i, section: 0)
                        let currCell = self.peersTable.cellForRow(at: currIndexPath) as! PeerTableViewCell
                        
                        if currCell.peerID == newMessage.peerID {
                            currCell.newMessageArrived()
                        }
                    }
                    
                    self.peersTable.reloadRows(at: indexPathsToUpdate, with: .fade)
                }
            }
                
            // If this is the case then it is likely a phone call
            else if let newMessage = NSKeyedUnarchiver.unarchiveObject(with: dictionary["data"] as! Data) as? String {
                if newMessage == incomingCall {
                    
                    let fromPeer = dictionary["peer"] as! MCPeerID
                    
                    print("\(#file) > \(#function) > Incoming call from peer \(fromPeer.displayName)")
                    
                    
                    let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "IncomingCall") as! IncomingCallViewController
                    self.addChildViewController(popOverView)
                    
                    popOverView.peerIndex = self.getIndexForPeer(peer: fromPeer)
                    popOverView.messages = self.messages
                    popOverView.peerDisplayName = fromPeer.displayName
                    
                    print("\(#file) > \(#function) > fromPeer=\(fromPeer.displayName)")
                    
                    OperationQueue.main.addOperation { () -> Void in
                        popOverView.view.frame = self.view.frame
                        self.view.addSubview(popOverView.view)
                        popOverView.didMove(toParentViewController: self)
                    }
                }
            }
            else {
                print("\(#file) > \(#function) > ERROR")
            }
        }
        else {
            // TODO: Still need to add message to messages
            print("\(#file) > \(#function) > Not currently visible")
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    
    
    // MARK: - TableDelegate Methods
    
    // returns the number of sections in the table view
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    //Getting the number of rows/peers to display
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("\(#file) > \(#function) > Entry \(section)")
        
        // Section 0 holds all available peers
        if (section == 0) {
            var count = 0
            
            for message in messages {
                if message.isAvailable {
                    count += 1
                }
            }
            
            print("\(#file) > \(#function) > Exit \(count)")
//            return appDelegate.connectionManager.foundPeers.count
            
            if (count == 0) {
                return 1
            }
            else {
                return count
            }
        }
            
        // Section 0 holds all unavailable peers
        else {
            
            var count = 0
            
            for message in messages {
                if (!message.isAvailable) {
                    count += 1
                }
            }
            
            print("\(#file) > \(#function) > Exit - \(count)")
            return count
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
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        print("\(#file) > \(#function) > Entry - row \(indexPath.row), section \(indexPath.section)")
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell") as! PeerTableViewCell
        
        let peers = getAllPeers()
        var availablePeers = peers[0]
        var unavailablePeers = peers[1]
        
        if indexPath.section == 0 {
            ///////////////// IF NO PEERS ARE NEARBY
            if (availablePeers.count == 0) {
                print("\(#file) > \(#function) > Currently no peers available")
                
                let cellIdentifier = "PeerTableViewCell"
                let tempCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as UITableViewCell
                
                tempCell.textLabel?.text = "Searching for peers..."
                tempCell.selectionStyle = UITableViewCellSelectionStyle.none
                
                print("\(#file) > \(#function) > Exit")
                return tempCell
            }
            //////////////// END
            
            print("\(#file) > \(#function) > There are \(availablePeers.count) peer(s) available")
            
            // If peers are nearby:
            let currPeer = availablePeers[indexPath.row]
            
            cell.peerID = currPeer.peerID
            cell.setPeerDisplayName(displayName: currPeer.peerID.displayName)
            cell.selectionStyle = UITableViewCellSelectionStyle.blue
            
            if (self.newMessage.contains(currPeer.peerID)) {
                for i in 0..<newMessage.count {
                    if (newMessage[i] == currPeer.peerID) {
                        newMessage.remove(at: i)
                        break
                    }
                }
                
                cell.newMessageArrived()
            }
            else {
                cell.peerIsAvailable()
            }
            
            if (currPeer.messages.count > 0) {
                print("\(#file) > \(#function) > Updating last message to: \(currPeer.messages[currPeer.messages.count-1])")
                if (!currPeer.messages[currPeer.messages.count-1].isMediaMessage) {
                    cell.setLatestMessage(latestMessage: currPeer.messages[currPeer.messages.count-1].text)
                }
                else {
                    cell.setLatestMessage(latestMessage: "Media")
                }
            }
            else {
                cell.setLatestMessage(latestMessage: "No history")
            }
            
            print("\(#file) > \(#function) > Exit")
            return cell
        }
        else {      //For section 1 (unavailable peers)
            if (indexPath.row > unavailablePeers.count) {
                print("\(#file) > \(#function) > Could not find peer... Updating table...")
                self.peersTable.reloadData()
                return cell
            }
            else {
                let currPeer = unavailablePeers[indexPath.row]
            
                cell.peerID = currPeer.peerID
                cell.setPeerDisplayName(displayName: currPeer.peerID.displayName)
                cell.selectionStyle = UITableViewCellSelectionStyle.blue
                cell.peerIsUnavailable()
                
    //            cell.messageButton.isHidden = true
    //            cell.phoneButton.isHidden = true
                
                if (currPeer.messages.count > 0) {
                    print("\(#file) > \(#function) > Updating last message to: \(currPeer.messages[currPeer.messages.count-1])")
                    if (!currPeer.messages[currPeer.messages.count-1].isMediaMessage) {
                        cell.setLatestMessage(latestMessage: currPeer.messages[currPeer.messages.count-1].text)
                    }
                    else {
                        cell.setLatestMessage(latestMessage: "Media")
                    }
                }
                else {
                    cell.setLatestMessage(latestMessage: "No history")
                }
                
                print("\(#file) > \(#function) > Exit")
                return cell
            }
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
    
    //TODO: Need to change to automatically connect with peer
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("\(#file) > \(#function) > Entry")
        
        if let currCell = peersTable.cellForRow(at: indexPath) as? PeerTableViewCell {
            print("\(#file) > \(#function) > Current cell is PeerTableViewCell")
            
            // if the peer selected is available
            if indexPath.section == 0 {
                
                let optionMenu = UIAlertController(title: nil, message: "Select an option", preferredStyle: .actionSheet)
                
                let phoneOption = UIAlertAction(title: "Voice", style: .default, handler: { (alert: UIAlertAction!) -> Void in
                    
                    let check = self.appDelegate.connectionManager.findSinglePeerSession(peer: currCell.peerID!)
                    if (check == -1) {
                        
                        print("COULD NOT FIND SESSION!!!")
                        
                        //Setting the connection type to voice
                        let peerIndex = self.getIndexForPeer(peer: currCell.peerID!)
                        self.messages[peerIndex].setConnectionTypeToVoice()
                        
//                        let index = self.appDelegate.connectionManager.createNewSession()
                        
                        // The user selected phone call
//                        let isPhoneCall: Bool = true
//                        let dataToSend : Data = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
                        
                        //Inviting peer
//                        self.appDelegate.connectionManager.browser.invitePeer(currCell.peerID!, to: self.appDelegate.connectionManager.sessions[index], withContext: dataToSend, timeout: 20)
                        
//                            let outputStream = try self.appDelegate.connectionManager.sessions[index].startStream(withName: "motoIntercom", toPeer: currCell.peerID!)
//                            print("\(#file) > \(#function) didSelectRowAt > Successfully created stream")
                            
                        self.destinationPeerID = currCell.peerID!
                        self.isDestPeerIDSet = true
                        
                        OperationQueue.main.addOperation { () -> Void in
                            print("\(#file) > \(#function) > Performing segue")
                            self.performSegue(withIdentifier: "callSegue", sender: self)
                        }
                    }
                    else {
                        
                        self.destinationPeerID = currCell.peerID
                        self.isDestPeerIDSet = true
                        
                        // Perform segue to phone view
                        OperationQueue.main.addOperation { () -> Void in
                            self.performSegue(withIdentifier: "callSegue", sender: self)
                        }
                        
                        _ = self.appDelegate.connectionManager.sendData(stringMessage: self.incomingCall, toPeer: self.destinationPeerID!)
                    }
                })
                
                let chatOption = UIAlertAction(title: "Chat", style: .default, handler: { (alert: UIAlertAction!) -> Void in
                    
                    currCell.removeNewMessageIcon()
                    print("\(#file) > \(#function) > Checking if connected to \(String(describing: currCell.peerID?.displayName))")
                    
                    let check = self.appDelegate.connectionManager.findSinglePeerSession(peer: currCell.peerID!)
                    
                    // if check is -1 then create a new session
                    if (check == -1) {
                        
                        // Set connection type to message
                        let peerIndex = self.getIndexForPeer(peer: currCell.peerID!)
                        self.messages[peerIndex].setConnectionTypeToMessage()
                        
                        print("\(#file) > \(#function) > Creating a new session")
                        
                        //Create a new session
                        let index = self.appDelegate.connectionManager.createNewSession()
                        
                        // Set the isPhoneCall to false so that the receiver knows it's a message
                        let isPhoneCall = false
                        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
                        
                        print("\(#file) > \(#function) > Setting isPhoneCall=\(isPhoneCall)")
                        
                        if (!isPhoneCall) {
                            self.destinationPeerID = currCell.peerID!
                            self.isDestPeerIDSet = true
                        }
                        
                        // Invite the peer to communicate
                        self.appDelegate.connectionManager.browser.invitePeer(currCell.peerID!, to: self.appDelegate.connectionManager.sessions[index], withContext: dataToSend, timeout: 20)
                        
                        // TODO: If the user declines the invitation, then delete the session
                    }
                    else {  //Session already exists, then perform segue
                        print("\(#file) > \(#function) > Session exists")
                        
                        self.destinationPeerID = currCell.peerID
                        self.isDestPeerIDSet = true
                        
                        // if already connected, than perform segue
                        OperationQueue.main.addOperation { () -> Void in
                            self.performSegue(withIdentifier: "idChatSegue", sender: self)
                        }
                    }
                    
                })
                
                let cancelOption = UIAlertAction(title: "Cancel", style: .cancel, handler: { (alert: UIAlertAction!) -> Void in
                    self.peersTable.deselectRow(at: indexPath, animated: true)
                })
                
                optionMenu.addAction(phoneOption)
                optionMenu.addAction(chatOption)
                optionMenu.addAction(cancelOption)
                
                print("\(#file) > \(#function) > Presenting option menu")
                
                OperationQueue.main.addOperation { () -> Void in
                    self.present(optionMenu, animated: true, completion: nil)
                }
            }
            else {  //The peer selected is not available so segue to the conversation
                
                print("\(#file) > \(#function) > Performing segue...")
                
                self.isDestPeerIDSet = false
                self.destinationPeerID = currCell.peerID
                
                OperationQueue.main.addOperation { () -> Void in
                    self.performSegue(withIdentifier: "idChatSegue", sender: self)
                }
            }
        }
        print("\(#file) > \(#function) > Exit")
        // Else do nothing
    }
    
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        peersTable.setEditing(editing, animated: animated)
    }
    
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if (indexPath.section == 0) {
            let peers = self.getAllPeers()
            let availablePeers = peers[0]
            
            if (availablePeers.count == 0) {
                return false
            }
            else {
                return true
            }
        }
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.delete
    }
    
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        print("\(#file) > \(#function) > Setting buttons")
        
        let clearHistoryAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "Clear", handler:{action, indexPath in
            
            let peers = self.getAllPeers()
            let availablePeers = peers[0]
            let unavailablePeers = peers[1]
            
            if (indexPath.section == 0) {
                let currPeer = availablePeers[indexPath.row].peerID
                
                for i in 0..<self.messages.count {
                    if (self.messages[i].peerID == currPeer) {
//                        self.messages[i].messageIsFrom.removeAll()
                        self.messages[i].messages.removeAll()
                        break
                    }
                }
            }
            else {
                let currPeer = unavailablePeers[indexPath.row].peerID
                
                for i in 0..<self.messages.count {
                    if (self.messages[i].peerID == currPeer) {
                        self.messages[i].messages.removeAll()
//                        self.messages[i].messageIsFrom.removeAll()
                        
                        break
                    }
                }
            }
            
            self.peersTable.reloadData()
            
            self.save()
        });
        
        if (indexPath.section == 0) {
            
            return [clearHistoryAction]
        }
        else {
            let removePeerAction = UITableViewRowAction(style: UITableViewRowActionStyle.destructive, title: "Delete", handler: {action, indexPath in
                
                let peers = self.getAllPeers()
                let unavailablePeers = peers[1]
                
                let currPeer = unavailablePeers[indexPath.row].peerID
                
                for i in 0..<self.messages.count {
                    if (self.messages[i].peerID == currPeer) {
                        self.messages.remove(at: i)
                        
                        self.peersTable.deleteRows(at: [indexPath], with: UITableViewRowAnimation.fade)
                        
                        break
                    }
                }
                
                self.save()
            });
            
            return [removePeerAction, clearHistoryAction]
        }
    }
    
    
    //MARK: - Connection Manager
    
    // If a peer was found, then reload data
    func foundPeer(_ newPeer: MCPeerID) {
        print("\(#file) > \(#function) foundPeer > Entry")
        
        let index = doesMessageObjectExist(forPeer: newPeer)
        
        // if message object does not exist, create it
        if index == -1 {
            let messageObject = MessageObject.init(peerID: newPeer, messages: [])
            messageObject.isAvailable = true
            messages.append(messageObject)
        }
        else {  // else the peer is available
            messages[index].isAvailable = true
        }
        
        save()
        
        //TODO: Instead of reloading data use the insertRow function
        DispatchQueue.main.async {
//            self.peersTable.insertRows(at: [IndexPath.init(row: self.getNumberOfAvailablePeers(), section: 0)], with: .fade)
            self.peersTable.reloadData()
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    // If a peer was lost, then reload data
    func lostPeer(_ lostPeer: MCPeerID) {
        print("\(#file) > \(#function) lostPeer > Entry")
        
        let index = doesMessageObjectExist(forPeer: lostPeer)
        
        //if message exists
        if index != -1 {
            messages[index].isAvailable = false
        }
        
        appDelegate.connectionManager.cleanSessions()
        
        //TODO: Change from reloadData to moveRow, and move the row to the unavailable section of the table
        DispatchQueue.main.async {
            self.peersTable.reloadData()
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    // When an invite is received
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        print("\(#file) > \(#function) > Entry: isPhoneCall=\(isPhoneCall)")
        
        if (!isPhoneCall) {
            // Set the connection type to message
            let peerIndex = self.getIndexForPeer(peer: fromPeer)
            self.messages[peerIndex].setConnectionTypeToMessage()
        }
        else {
            print("\(#file) > \(#function) > Incoming call!")
            
            let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "IncomingCall") as! IncomingCallViewController
            self.addChildViewController(popOverView)
            
            popOverView.peerIndex = self.getIndexForPeer(peer: fromPeer)
            popOverView.messages = self.messages
            popOverView.peerDisplayName = fromPeer.displayName
            
            print("\(#file) > \(#function) > fromPeer=\(fromPeer.displayName)")
            
            popOverView.view.frame = self.view.frame
            self.view.addSubview(popOverView.view)
            popOverView.didMove(toParentViewController: self)
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        print("\(#file) > \(#function) > \(#line) > Connected to peer \(peerID)")
        
        // Remove the peer from foundPeers
        appDelegate.connectionManager.removeFoundPeer(peerID: peerID)
        
//        destinationPeerID = peerID  // This is used so we know what peer was clicked on
//        isDestPeerIDSet = true
        
        if (isDestPeerIDSet) {
        
            let peerIndex = getIndexForPeer(peer: peerID)
            let connType = messages[peerIndex].connectionType
            
            
            if (connType == MESSAGE_CONNECTION_TYPE) {
                print("\(#file) > \(#function) > Connection type is MESSAGE_CONNECTION_TYPE)")
                OperationQueue.main.addOperation {
                    self.performSegue(withIdentifier: "idChatSegue", sender: self)
                }
            }
            else if (connType == PHONE_CONNECTION_TYPE) {
                print("\(#file) > \(#function) connectedWithPeer > Connection type is PHONE_CONNECTION_TYPE)")
                OperationQueue.main.addOperation {
                    self.performSegue(withIdentifier: "callSegue", sender: self)
                }
            }
            else {
                print("\(#file) > \(#function) > Could NOT recognize a connection type. Cannot perform segue.")
            }
        }
        
    }
    
    // Called when a peer is disconnected from
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > Entry: Disconnected from peer \(peerID)")
        
        // Resetting the peers connected type
        let peerIndex = getIndexForPeer(peer: peerID)
        messages[peerIndex].resetConnectionType()
        
        if let currView = navigationController?.topViewController as? JSQChatViewController {
            print("\(#file) > \(#function) > topViewController is ChatView. ")
            if (peerID == currView.messageObject.peerID) {
                let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(currView.messageObject.peerID.displayName)", preferredStyle: UIAlertControllerStyle.alert)

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
            print("\(#file) > \(#function) > Reloading peer table.")
            
            DispatchQueue.main.async {
                self.peersTable.reloadData()
            }
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        // Nothing to do
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        print("\(#file) > \(#function) > Received inputStream from peer \(peerID.displayName)")
        // Nothing to do
    }
    
    
    //MARK: - Segue
    
    // This function is run before a segue is performed
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("\(#file) > \(#function) > Entry: \(isDestPeerIDSet) destinationPeerID = \(String(describing: destinationPeerID?.displayName))")
        
        if (segue.identifier == "idChatSegue" && isDestPeerIDSet) {
            let dest = segue.destination as? JSQChatViewController
            var messageIsSet = false
            
            for message in messages {
                print("\(#file) > \(#function) > Currently looking at messages from peer \(message.peerID)")
                if (message.peerID == destinationPeerID) {
                    dest?.messageObject = message
                    messageIsSet = true
                    
                    print("\(#file) > \(#function) > # of messages \(message.messages.count)")
                    break
                }
            }
            
            if (messageIsSet == false) {
                let newMessageObject = MessageObject.init(peerID: destinationPeerID!, messages: [])
                messages.append(newMessageObject)
                
                save()
                
                print("\(#file) > \(#function) > Could not find message object. Creating a new message object.")
                
                dest!.messageObject = self.messages[messages.count-1]
            }
        }
        else if (segue.identifier == "idChatSegue") {
            let dest = segue.destination as? JSQChatViewController
            var messageIsSet = false
            
            for message in messages {
                if message.peerID == destinationPeerID {
                    dest?.messageObject = message
                    
                    messageIsSet = true
                    break
                }
            }
            
            if (!messageIsSet) {
                print("\(#file) > \(#function) > ERROR: THIS SHOULD NEVER BE PRINTED.")
            }
        }
        else if (segue.identifier == "callSegue" && isDestPeerIDSet) {
            print("\(#file) > \(#function) > current segue is callSegue")
            
            let dest = segue.destination as? PhoneViewController
            dest?.peerID = destinationPeerID
            
            if (didAcceptCall) {
                dest?.didReceiveCall = true
            }
            
            // TODO: Need to finish
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if (isDestPeerIDSet == true) {
            print("\(#file) > \(#function) > Return true - 1")
            return true
        }
        else if (isDestPeerIDSet == false && destinationPeerID != nil) {
            print("\(#file) > \(#function) > Return true - 2")
            return true
        }
        
        print("\(#file) > \(#function) > Return false")
        return false
    }
    
    
    //MARK: - Save and Load
    
    // Save user information
    func save() {
        DispatchQueue.global().async {
            print("\(#file) > \(#function) > Saving messages")
            if (!NSKeyedArchiver.archiveRootObject(self.messages, toFile: MessageObject.ArchiveURL.path)) {
                print("CourseTable: save: Failed to save courses and groups.")
            }
        }
    }
    
    // Load user information
    func load() -> [MessageObject]? {
        print("\(#file) > \(#function) > Loading messages")
        return (NSKeyedUnarchiver.unarchiveObject(withFile: MessageObject.ArchiveURL.path) as! [MessageObject]?)
    }
}
