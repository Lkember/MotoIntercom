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
    let endingCall = "_user_ended_call_"
    let peerIsTyping = "_user_is_typing_"
    let delivered = "_is_delivered_"
    var peerStoppedTyping: String = "_user_stopped_typing_"
    
    // MARK: - Properties
    @IBOutlet weak var peersTable: UITableView!
    var refreshControl: UIRefreshControl!
    var messages = [MessageObject]()
    
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
        
        navigationItem.leftBarButtonItem?.title = "Back"
        navigationItem.rightBarButtonItem = self.editButtonItem
        
        peersTable.delegate = self
        peersTable.dataSource = self
        
        // Setting up the pull to refresh
        refreshControl = UIRefreshControl()
//        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(PeerViewController.refresh(sender:)), for: UIControlEvents.valueChanged)
        peersTable.addSubview(refreshControl)
        
        //set the delegate to self, and start browsing for peers
        appDelegate.connectionManager.delegate = self
        appDelegate.connectionManager.browser.startBrowsingForPeers()
        appDelegate.connectionManager.advertiser.startAdvertisingPeer()
        
        //Adding an observer for when data is received
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMessageObject(_:)), name: NSNotification.Name(rawValue: "receivedMessageObjectNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveStandardMessage(_:)), name: NSNotification.Name(rawValue: "receivedStandardMessageNotification"), object: nil)
        
        isDestPeerIDSet = false
        didAcceptCall = false
        print("\(type(of: self)) > \(#function) > Advertising and browsing for peers. Thread: \(Thread.current)")
    }
    
    // Called before the view appears, this way the user won't see the view updating
    override func viewWillAppear(_ animated: Bool) {
        print("\(type(of: self)) > \(#function) > Entry")
        
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
        
        print("\(type(of: self)) > \(#function) > Exit: Advertising and browsing for peers.")
    }
    
    
    // MARK: - Actions
    
    
    // A function which returns the index for a given peer
    func getIndexForPeer(peer: MCPeerID) -> Int {
        print("\(type(of: self)) > \(#function) > Entry \(peer)")
        for i in 0..<messages.count {
            print("\(type(of: self)) > \(#function) > \(i) \(messages[i].peerID)")
            if (messages[i].peerID == peer) {
                print("\(type(of: self)) > \(#function) > Exit - Success")
                return i
            }
        }
        print("\(type(of: self)) > \(#function) > Exit - Failure")
        return -1
    }
    
    // Returns a list of unavailablePeers
    func getUnavailablePeers() -> [MCPeerID] {
        var peers = [MCPeerID]()
        
        for message in messages {
            if (!appDelegate.connectionManager.availablePeers.peers.contains(message.peerID)) {
                peers.append(message.peerID)
            }
        }
        
        return peers
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
    
    
    // Function used when the user accepts a call
    func acceptCall() {
        print("\(type(of: self)) > \(#function) > Entry")
        
        _ = self.appDelegate.connectionManager.sendData(stringMessage: self.acceptedCall, toPeer: self.destinationPeerID!)
        
        // If a call has been accepted
        OperationQueue.main.addOperation {
            print("\(type(of: self)) > \(#function) > Performing callSegue")
            super.performSegue(withIdentifier: "callSegue", sender: self)
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func declineCall() {
        print("\(type(of: self)) > \(#function) > Entry")
        
        _ = appDelegate.connectionManager.sendData(stringMessage: declinedCall, toPeer: destinationPeerID!)
        destinationPeerID = nil
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    //Called to refresh the table
    func refresh(sender: AnyObject) {
        print("\(type(of: self)) > \(#function) > Refreshing table")
        
        self.appDelegate.generator.impactOccurred()     // Haptic feedback when the user refreshes the screen
        
        DispatchQueue.main.async {
            self.peersTable.reloadData()
        }
        
        sleep(UInt32(0.5))
        refreshControl.endRefreshing()
    }
    
    
    func didReceiveMessageObject(_ notification: Notification) {
        print("\(type(of: self)) > \(#function) > Entry")
        
        // If currently visible
        if let _ = navigationController?.visibleViewController as? PeerViewController {
            
            print("\(type(of: self)) > \(#function) > PeerViewController is visible controller.")
            let newMessage: MessageObject = notification.object as! MessageObject
            let fromPeer = newMessage.peerID!
            
            let peerIndex = getIndexForPeer(peer: fromPeer)
        
            print("\(type(of: self)) > \(#function) > message: \(newMessage.messages[0].text), from peer \(newMessage.peerID.displayName), peerIndex = \(peerIndex)")
            messages[peerIndex].messages.append(newMessage.messages[0])
            
            _ = appDelegate.connectionManager.sendData(stringMessage: delivered, toPeer: fromPeer)
            
            save()
            
            //Vibrate
            JSQSystemSoundPlayer.jsq_playMessageReceivedAlert()
            
            print("\(type(of: self)) > \(#function) > Test")
            
            //Changes to UI must be done by main thread
            DispatchQueue.main.async {
                let numRows = self.peersTable.numberOfRows(inSection: 0)
                
                for i in 0..<numRows {
                    
                    let currIndexPath = IndexPath.init(row: i, section: 0)
                    let currCell = self.peersTable.cellForRow(at: currIndexPath) as! PeerTableViewCell
                    
                    if currCell.peerID == newMessage.peerID {
                        currCell.newMessageArrived()
                        if (!newMessage.messages[0].isMediaMessage) {
                            currCell.latestMessage?.text = "\(newMessage.messages[0].text!)"
                        }
                        else {
                            currCell.latestMessage?.text = "Image"
                        }
                    }
                }
            }
        }
        else {
            // TODO: Still need to add message to messages
            print("\(type(of: self)) > \(#function) > Not currently visible")
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    func didReceiveStandardMessage(_ notification: NSNotification) {
        
        let newMessage = notification.object as! StandardMessage
        let fromPeer = newMessage.peerID!
        
        print("\(type(of: self)) > \(#function) > Received message = \(newMessage.message)")
        
        if newMessage.message == incomingCall {
            
            print("\(type(of: self)) > \(#function) > Incoming call from peer \(fromPeer.displayName)")
            
            let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "IncomingCall") as! IncomingCallViewController
            self.addChildViewController(popOverView)
            
            popOverView.peerIndex = self.getIndexForPeer(peer: fromPeer)
            popOverView.messages = self.messages
            popOverView.peerDisplayName = fromPeer.displayName
            
            print("\(type(of: self)) > \(#function) > fromPeer=\(fromPeer.displayName)")
            
            OperationQueue.main.addOperation { () -> Void in
                popOverView.view.frame = self.view.frame
                self.view.addSubview(popOverView.view)
                popOverView.didMove(toParentViewController: self)
            }
        }
        else if (newMessage.message == peerIsTyping || newMessage.message == peerStoppedTyping) {
            
            DispatchQueue.main.async {
            
                let numRows = self.peersTable.numberOfRows(inSection: 0)
//                var indexPathsToUpdate: [IndexPath] = []
                
                for i in 0..<numRows {
                    let currIndexPath = IndexPath.init(row: i, section: 0)
                    let currCell = self.peersTable.cellForRow(at: currIndexPath) as! PeerTableViewCell
                    
                    if currCell.peerID == newMessage.peerID {
//                        indexPathsToUpdate.append(currIndexPath)
                        if (newMessage.message == self.peerIsTyping) {
                            currCell.peerIsTyping()
                        }
                        else {
                            currCell.removeNewMessageIcon()
                        }
                    }
                }
            
//                self.peersTable.reloadRows(at: indexPathsToUpdate, with: .fade)
            }
        }
        else if (newMessage.message == self.endingCall) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "peerEndedCall"), object: newMessage)
        }
    }
    
    
    
    // MARK: - TableDelegate Methods
    
    // returns the number of sections in the table view
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    //Getting the number of rows/peers to display
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // Section 0 holds all available peers
        if (section == 0) {
            
            if (appDelegate.connectionManager.availablePeers.peers.count == 0) {
                print("\(type(of: self)) > \(#function) > section: \(section) rows: 1")
                return 1
            }
            else {
                print("\(type(of: self)) > \(#function) > section: \(section) rows: \(appDelegate.connectionManager.availablePeers.peers.count)")
                return appDelegate.connectionManager.availablePeers.peers.count
            }
        }
            
        // Section 0 holds all unavailable peers
        else {
            
            var count = 0
            
            for message in messages {
                if (!appDelegate.connectionManager.availablePeers.peers.contains(message.peerID)) {
                    count += 1
                }
            }
            
            print("\(type(of: self)) > \(#function) > section: \(section) rows: \(count)")
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
        
        print("\(type(of: self)) > \(#function) > Entry - row \(indexPath.row), section \(indexPath.section)")
        
        // For available peers
        if indexPath.section == 0 {
            if (self.appDelegate.connectionManager.availablePeers.peers.count == 0) {
                print("\(type(of: self)) > \(#function) > Currently no peers available")
                
                let cellIdentifier = "PeerTableViewCell"
                let tempCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as UITableViewCell
                
                tempCell.textLabel?.text = "Searching for peers..."
                tempCell.selectionStyle = UITableViewCellSelectionStyle.none
                
                print("\(type(of: self)) > \(#function) > Exit")
                return tempCell
            }
            
            // If peers are nearby:
            let currPeer = appDelegate.connectionManager.availablePeers.peers[indexPath.row]
            
            // If the peer is connected
            if (appDelegate.connectionManager.checkIfAlreadyConnected(peerID: currPeer)) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell") as! PeerTableViewCell
                
                cell.peerID = currPeer
                cell.setPeerDisplayName(displayName: currPeer.displayName)
                cell.selectionStyle = UITableViewCellSelectionStyle.blue
                cell.peerIsAvailable()
                
                let index = getIndexForPeer(peer: currPeer)
                if (index >= 0) {
                    cell.setLatestMessage(latestMessage: self.messages[index].getLastMessage())
                }
                else {
                    // If this is the case, then the peer was added to the availablePeers while in a different view, so add it to messages
                    let message = MessageObject.init(peerID: currPeer, selfID: self.appDelegate.peer, messages: [])
                    messages.append(message)
                    cell.setLatestMessage(latestMessage: self.messages[messages.count-1].getLastMessage())
                }
                
                print("\(type(of: self)) > \(#function) > Exit - Peer is connected")
                return cell
            }
                
            // If the peer is not connected
            else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "connectingPeerCell") as! ConnectingPeerTableViewCell
                
                cell.peerID = currPeer
                cell.setPeerDisplayName(displayName: currPeer.displayName)
                cell.selectionStyle = UITableViewCellSelectionStyle.none
                cell.isUserInteractionEnabled = false
                
                let index = getIndexForPeer(peer: currPeer)
                cell.setLatestMessage(latestMessage: self.messages[index].getLastMessage())
                cell.activityIndicator.startAnimating()
                
                print("\(type(of: self)) > \(#function) > Exit - Connecting to peer")
                return cell
            }
        }
            
        //For section 1 (unavailable peers)
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell") as! PeerTableViewCell
            let unavailablePeers = getUnavailablePeers()
            
            if (indexPath.row >= unavailablePeers.count) {
                print("\(type(of: self)) > \(#function) > Exit - Table needs update")
                self.peersTable.reloadData()
                return cell
            }
            
            let currPeer = unavailablePeers[indexPath.row]
            
            cell.peerID = currPeer
            cell.setPeerDisplayName(displayName: currPeer.displayName)
            cell.selectionStyle = UITableViewCellSelectionStyle.blue
            cell.peerIsUnavailable()
            
            let index = getIndexForPeer(peer: currPeer)
            
            cell.setLatestMessage(latestMessage: messages[index].getLastMessage())
            
            print("\(type(of: self)) > \(#function) > Exit")
            return cell
        }
    }
    
    
    //Setting the height of each row
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    //TODO: Need to change to automatically connect with peer
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("\(type(of: self)) > \(#function) > Entry")
        
        if let currCell = peersTable.cellForRow(at: indexPath) as? PeerTableViewCell {
            print("\(type(of: self)) > \(#function) > Current cell is PeerTableViewCell")
            
            // if the peer selected is available
            if indexPath.section == 0 {
                
                let optionMenu = UIAlertController(title: nil, message: "Select an option", preferredStyle: .actionSheet)
                
                let phoneOption = UIAlertAction(title: "Voice", style: .default, handler: { (alert: UIAlertAction!) -> Void in
                    
                    let check = self.appDelegate.connectionManager.findSinglePeerSession(peer: currCell.peerID!)
                    if (check == -1) {
                        //Setting the connection type to voice
//                        let peerIndex = self.getIndexForPeer(peer: currCell.peerID!)
//                        self.messages[peerIndex].setConnectionTypeToVoice()
                        
                        self.destinationPeerID = currCell.peerID!
                        self.isDestPeerIDSet = true
                        
                        OperationQueue.main.addOperation { () -> Void in
                            print("\(type(of: self)) > \(#function) > Performing segue")
                            self.performSegue(withIdentifier: "callSegue", sender: self)
                        }
                        
                        // TODO: Reconnect to peer first
                    }
                    else {
                        
                        self.destinationPeerID = currCell.peerID
                        self.isDestPeerIDSet = true
                        
                        // Perform segue to phone view
                        OperationQueue.main.addOperation { () -> Void in
                            print("\(type(of: self)) > \(#function) > Performing segue")
                            self.performSegue(withIdentifier: "callSegue", sender: self)
                        }
                        
                        _ = self.appDelegate.connectionManager.sendData(stringMessage: self.incomingCall, toPeer: self.destinationPeerID!)
                    }
                })
                
                let chatOption = UIAlertAction(title: "Chat", style: .default, handler: { (alert: UIAlertAction!) -> Void in
                    
                    currCell.removeNewMessageIcon()
                    print("\(type(of: self)) > \(#function) > Checking if connected to \(String(describing: currCell.peerID?.displayName))")
                    
                    let check = self.appDelegate.connectionManager.findSinglePeerSession(peer: currCell.peerID!)
                    
                    // if check is -1 then create a new session
                    if (check == -1) {
                        
                        // Set connection type to message
//                        let peerIndex = self.getIndexForPeer(peer: currCell.peerID!)
//                        self.messages[peerIndex].setConnectionTypeToMessage()
                        
                        print("\(type(of: self)) > \(#function) > Creating a new session")
                        
                        //Create a new session
                        let index = self.appDelegate.connectionManager.createNewSession()
                        
                        // Set the isPhoneCall to false so that the receiver knows it's a message
                        let isPhoneCall = false
                        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
                        
                        print("\(type(of: self)) > \(#function) > Setting isPhoneCall=\(isPhoneCall)")
                        
                        if (!isPhoneCall) {
                            self.destinationPeerID = currCell.peerID!
                            self.isDestPeerIDSet = true
                        }
                        
                        // Invite the peer to communicate
                        self.appDelegate.connectionManager.browser.invitePeer(currCell.peerID!, to: self.appDelegate.connectionManager.sessions[index], withContext: dataToSend, timeout: 20)
                        
                        // TODO: If the user declines the invitation, then delete the session
                    }
                    else {  //Session already exists, then perform segue
                        print("\(type(of: self)) > \(#function) > Session exists")
                        
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
                
                print("\(type(of: self)) > \(#function) > Presenting option menu")
                
                OperationQueue.main.addOperation { () -> Void in
                    self.present(optionMenu, animated: true, completion: nil)
                }
            }
            else {  //The peer selected is not available so segue to the conversation
                
                print("\(type(of: self)) > \(#function) > Performing segue...")
                
                self.isDestPeerIDSet = false
                self.destinationPeerID = currCell.peerID
                
                OperationQueue.main.addOperation { () -> Void in
                    self.performSegue(withIdentifier: "idChatSegue", sender: self)
                }
            }
        }
        print("\(type(of: self)) > \(#function) > Exit")
        // Else do nothing
    }
    
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        peersTable.setEditing(editing, animated: animated)
    }
    
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if (indexPath.section == 0) {
            if (appDelegate.connectionManager.availablePeers.peers.count == 0) {
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
        print("\(type(of: self)) > \(#function) > Setting buttons")
        
        let clearHistoryAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "Clear", handler:{action, indexPath in
            
            let unavailablePeers = self.getUnavailablePeers()
            
            if (indexPath.section == 0) {
                let currPeer = self.appDelegate.connectionManager.availablePeers.peers[indexPath.row]
                let index = self.getIndexForPeer(peer: currPeer)
                
                self.messages[index].messages.removeAll()
            }
            else {
                let currPeer = unavailablePeers[indexPath.row]
                let index = self.getIndexForPeer(peer: currPeer)
                
                self.messages[index].messages.removeAll()
            }
            
            self.peersTable.reloadData()
            
            self.save()
        });
        
        if (indexPath.section == 0) {
            
            return [clearHistoryAction]
        }
        else {
            let removePeerAction = UITableViewRowAction(style: UITableViewRowActionStyle.destructive, title: "Delete", handler: {action, indexPath in
                
                let unavailablePeers = self.getUnavailablePeers()
                let currPeer = unavailablePeers[indexPath.row]
                let index = self.getIndexForPeer(peer: currPeer)
                
                self.messages.remove(at: index)
                self.peersTable.deleteRows(at: [indexPath], with: UITableViewRowAnimation.fade)
                
                self.save()
            });
            
            return [removePeerAction, clearHistoryAction]
        }
    }
    
    
    //MARK: - Connection Manager
    
    // If a peer was found, then reload data
    func foundPeer(_ newPeer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Entry")
        
        let index = doesMessageObjectExist(forPeer: newPeer)
        
        // if message object does not exist, create it
        if index == -1 {
            let messageObject = MessageObject.init(peerID: newPeer, messages: [])
            messages.append(messageObject)
            print("\(type(of: self)) > \(#function) > Peer added")
        }
        else {
            print("\(type(of: self)) > \(#function) > Peer already exists")
        }
        
        save()

        //TODO: use reload rows isntead of reload data
        DispatchQueue.main.async {
            
//            if (self.appDelegate.connectionManager.availablePeers.count == 1) {
//                self.peersTable.reloadRows(at: [IndexPath.init(row: 0, section: 0)], with: .fade)
//            }
//            else {
//                self.peersTable.insertRows(at: [IndexPath.init(row: self.appDelegate.connectionManager.availablePeers.count, section: 0)], with: .fade)
//            }
            self.peersTable.reloadData()
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    // If a peer was lost, then reload data
    func lostPeer(_ lostPeer: MCPeerID) {
        print("\(type(of: self)) > \(#function) lostPeer > Entry")
        
        appDelegate.connectionManager.cleanSessions()
        
        //TODO: Change from reloadData to moveRow, and move the row to the unavailable section of the table
        /*
         * We can't use availablePeers because this peer has already been removed from there
         */
        DispatchQueue.main.async {
            self.peersTable.reloadData()
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    // When an invite is received
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: UInt8) {
        print("\(type(of: self)) > \(#function) > Entry: isPhoneCall=\(isPhoneCall)")
        
        if (isPhoneCall == 0) {
            // Set the connection type to message
//            let peerIndex = self.getIndexForPeer(peer: fromPeer)
//            if (peerIndex >= 0) {
//                self.messages[peerIndex].setConnectionTypeToMessage()
//            }
//            else {
//                print("\(type(of: self)) > \(#function) > ERROR! COULD NOT FIND PEER!")
//            }
        }
        else {
            // There is an incoming call
            print("\(type(of: self)) > \(#function) > Incoming call!")
            
            // Create call overlay
            let popOverView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "IncomingCall") as! IncomingCallViewController
            self.addChildViewController(popOverView)
            
            // Getting index for the peer
            popOverView.peerIndex = self.getIndexForPeer(peer: fromPeer)
            popOverView.messages = self.messages
            popOverView.peerDisplayName = fromPeer.displayName
            
            // If it is a multipeer call
            if (isPhoneCall == 2) {
                popOverView.isMultipeerCall = true
            }
            
            print("\(type(of: self)) > \(#function) > fromPeer=\(fromPeer.displayName)")
            
            popOverView.view.frame = self.view.frame
            self.view.addSubview(popOverView.view)
            popOverView.didMove(toParentViewController: self)
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        print("\(type(of: self)) > \(#function) > Connected to peer \(peerID)")
        
        DispatchQueue.main.async {
            self.peersTable.reloadData()
        }
    }
    
    // Called when a peer is disconnected from
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Entry: Disconnected from peer \(peerID)")
        
        // Resetting the peers connected type
//        let peerIndex = getIndexForPeer(peer: peerID)
//        messages[peerIndex].resetConnectionType()
        
        if let currView = navigationController?.topViewController as? JSQChatViewController {
            print("\(type(of: self)) > \(#function) > topViewController is ChatView. ")
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
            print("\(type(of: self)) > \(#function) > Reloading peer table.")
            
            DispatchQueue.main.async {
                self.peersTable.reloadData()
            }
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        // Nothing to do
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        print("\(type(of: self)) > \(#function) > Received inputStream from peer \(peerID.displayName)")
        // Nothing to do
    }
    
    
    //MARK: - Segue
    
    // This function is run before a segue is performed
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("\(type(of: self)) > \(#function) > Entry: \(isDestPeerIDSet) destinationPeerID = \(String(describing: destinationPeerID?.displayName))")
        
        if (segue.identifier == "idChatSegue" && isDestPeerIDSet) {
            let dest = segue.destination as? JSQChatViewController
            var messageIsSet = false
            
            for message in messages {
                print("\(type(of: self)) > \(#function) > Currently looking at messages from peer \(message.peerID)")
                if (message.peerID == destinationPeerID) {
                    dest?.messageObject = message
                    messageIsSet = true
                    
                    print("\(type(of: self)) > \(#function) > # of messages \(message.messages.count)")
                    break
                }
            }
            
            if (messageIsSet == false) {
                let newMessageObject = MessageObject.init(peerID: destinationPeerID!, messages: [])
                messages.append(newMessageObject)
                
                save()
                
                print("\(type(of: self)) > \(#function) > Could not find message object. Creating a new message object.")
                
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
                print("\(type(of: self)) > \(#function) > ERROR: THIS SHOULD NEVER BE PRINTED.")
            }
        }
        else if (segue.identifier == "callSegue" && isDestPeerIDSet) {
            print("\(type(of: self)) > \(#function) > current segue is callSegue")
            
            let dest = segue.destination as? PhoneViewController
            if (didAcceptCall) {
                dest?.peerOrganizer.addNewPeer(peer: destinationPeerID!, didReceiveCall: true)
            }
            else {
                dest?.peerOrganizer.addNewPeer(peer: destinationPeerID!, didReceiveCall: false)
            }
            dest?.peerOrganizer.sessionIndex = appDelegate.connectionManager.findSinglePeerSession(peer: destinationPeerID!)
            
            if (didAcceptCall) {
                dest?.didReceiveCall = true
            }
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if (isDestPeerIDSet == true) {
            print("\(type(of: self)) > \(#function) > Return true - 1")
            return true
        }
        else if (isDestPeerIDSet == false && destinationPeerID != nil) {
            print("\(type(of: self)) > \(#function) > Return true - 2")
            return true
        }
        
        print("\(type(of: self)) > \(#function) > Return false")
        return false
    }
    
    
    //MARK: - Save and Load
    
    // Save user information
    func save() {
        DispatchQueue.global().async {
            print("\(type(of: self)) > \(#function) > Saving messages")
            if (!NSKeyedArchiver.archiveRootObject(self.messages, toFile: MessageObject.ArchiveURL.path)) {
                print("CourseTable: save: Failed to save courses and groups.")
            }
        }
    }
    
    // Load user information
    func load() -> [MessageObject]? {
        print("\(type(of: self)) > \(#function) > Loading messages")
        return (NSKeyedUnarchiver.unarchiveObject(withFile: MessageObject.ArchiveURL.path) as! [MessageObject]?)
    }
}
