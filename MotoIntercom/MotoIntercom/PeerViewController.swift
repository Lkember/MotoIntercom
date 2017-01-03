//
//  FirstViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-05.
//  Copyright © 2016 Logan Kember. All rights reserved.
//
//  Useful link for InputStream and OutputStream https://robots.thoughtbot.com/streaming-audio-to-multiple-listeners-via-ios-multipeer-connectivity
//  Useful link for audio http://www.stefanpopp.de/capture-iphone-microphone/

import UIKit
import MultipeerConnectivity
import AudioToolbox             // For sound and vibration

class PeerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ConnectionManagerDelegate {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let endChat = "_end_chat_"
    
    // MARK: Properties
    @IBOutlet weak var viewSwitch: UISwitch!
    @IBOutlet weak var peersTable: UITableView!
    var refreshControl: UIRefreshControl!
    var messages = [MessageObject]()
    var newMessage: [MCPeerID] = []
    
    var UNSPECIFIED_CONNECTION_TYPE = 0
    var MESSAGE_CONNECTION_TYPE = 1
    var PHONE_CONNECTION_TYPE = 2
    
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
        
        if let loadedData = load() {
            messages = loadedData
        }
        
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
        
        isDestPeerIDSet = false
        viewSwitch.isOn = true
        print("PeerView > viewDidLoad > Advertising and browsing for peers.")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        appDelegate.connectionManager.browser.startBrowsingForPeers()
        appDelegate.connectionManager.advertiser.startAdvertisingPeer()
        
        isDestPeerIDSet = false
        
        self.switchView(viewSwitch)
        
        DispatchQueue.main.async {
            self.peersTable.reloadData()
        }
        
        print("PeerView > viewDidAppear > Advertising and browsing for peers.")
    }
    
    //Called to refresh the table
    func refresh(sender: AnyObject) {
        print("PeerView > refresh > Refreshing table")
        
        DispatchQueue.main.async {
            self.peersTable.reloadData()
        }
        
        refreshControl.endRefreshing()
    }
    
    
    func handleMPCReceivedDataWithNotification(_ notification: Notification) {
        print("PeerView > handleMPCReceivedDataWithNotification > Entry")
        
        if let _ = navigationController?.visibleViewController as? PeerViewController {
            let dictionary = NSKeyedUnarchiver.unarchiveObject(with: notification.object as! Data) as! [String: Any]
            let newMessage = NSKeyedUnarchiver.unarchiveObject(with: dictionary["data"] as! Data) as! MessageObject
            let fromPeer = dictionary["peer"] as! MCPeerID
            
            print("PeerView > handleMPCReceivedDataWithNotification > message: \(newMessage.messages[0]) from \(fromPeer.displayName)")
            
            if newMessage.messages[0] != endChat {
                
                let peerIndex = getIndexForPeer(peer: fromPeer)
                
                messages[peerIndex].messages.append(newMessage.messages[0])
                messages[peerIndex].messageIsFrom.append(newMessage.messageIsFrom[0])
                print("PeerView > handleMPCReceivedDataWithNotification > Adding new message to transcript for peer \(messages[peerIndex].peerID.displayName)")
                
                save()
                
                //Vibrate
                //TODO: Make a noise notification as well
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
                print("PeerView > handleMPCReceivedDataWithNotification > Sending vibration notification to device")
                
//                let currCell = peersTable.cellForRow(at: IndexPath.init(row: peerIndex, section: 0)) as! PeerTableViewCell
//                currCell.newMessageArrived()
                
                //Changes to UI must be done by main thread
                DispatchQueue.main.async {
                    if (!self.newMessage.contains(fromPeer)) {
                        self.newMessage.append(fromPeer)
                    }
                    self.peersTable.reloadRows(at: [IndexPath.init(row: peerIndex, section: 0)], with: .fade)
//                    self.peersTable.reloadData()
                }
            }
            else {
                //TODO: If the incoming message is the end chat message
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
        
        // Section 0 holds all available peers
        if (section == 0) {
            var count = 0
            
            for message in messages {
                if message.isAvailable {
                    count += 1
                }
            }
            
            print("PeerView > numberOfRowsInSection > Exit \(count)")
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
            
            print("PeerView > numberOfRowsInSection > Exit - \(count)")
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
    
    
    // TODO: There is likely a more efficent way to execute this method
    //Displaying the peers
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        print("PeerView > cellForRowAt > Entry - row \(indexPath.row), section \(indexPath.section)")
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell") as! PeerTableViewCell
        
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
        
        if indexPath.section == 0 {
            ///////////////// IF NO PEERS ARE NEARBY
            if (availablePeers.count == 0) {
                print("PeerView > cellForRowAt > Currently no peers available")
                
                let cellIdentifier = "PeerTableViewCell"
                let tempCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as UITableViewCell
                
                tempCell.textLabel?.text = "Searching for peers..."
                tempCell.selectionStyle = UITableViewCellSelectionStyle.none
                
                print("PeerView > cellForRowAt > Exit")
                return tempCell
            }
            //////////////// END
            
            print("PeerView > cellForRowAt > There are \(availablePeers.count) peer(s) available")
            
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
                print("PeerView > cellForRowAt > Updating last message to: \(currPeer.messages[currPeer.messages.count-1])")
                cell.setLatestMessage(latestMessage: currPeer.messages[currPeer.messages.count-1])
            }
            else {
                cell.setLatestMessage(latestMessage: "No history")
            }
            
            //TODO: Add tap gesture recognizer
            
            print("PeerView > cellForRowAt > Exit")
            return cell
        }
        else {      //For section 1 (unavailable peers)
            let currPeer = unavailablePeers[indexPath.row]
            
            cell.peerID = currPeer.peerID
            cell.setPeerDisplayName(displayName: currPeer.peerID.displayName)
            cell.selectionStyle = UITableViewCellSelectionStyle.blue
            cell.peerIsUnavailable()
            
//            cell.messageButton.isHidden = true
//            cell.phoneButton.isHidden = true
            
            if (currPeer.messages.count > 0) {
                cell.setLatestMessage(latestMessage: currPeer.messages[currPeer.messages.count-1])
            }
            else {
                cell.setLatestMessage(latestMessage: "No history")
            }
            
            print("PeerView > cellForRowAt > Exit")
            return cell
        }
    }
    
    
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        
//        print("PeerView > cellForRowAt > Entry")
//        
//        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell") as! PeerTableViewCell
//        
//        print("PeerView > cellForRowAt > Found \(appDelegate.connectionManager.foundPeers.count) peer(s), # of sessions \(appDelegate.connectionManager.sessions.count)")
//        
//        if (indexPath.section == 1) {   // Then the peer is available but is not connected to
//            // TODO: Must change if multiple peers can be connected under 1 session
//            
//            if (appDelegate.connectionManager.foundPeers.count != 0) {
//                print("PeerView > cellForRowAt > Set text label as: \(appDelegate.connectionManager.foundPeers[indexPath.row].displayName)");
//                cell.setPeerDisplayName(displayName: appDelegate.connectionManager.foundPeers[indexPath.row].displayName)
//                cell.selectionStyle = UITableViewCellSelectionStyle.blue
//                cell.peerIsAvailable()
//                
//                var isHistory = false
//                for message in messages {
//                    if message.peerID == appDelegate.connectionManager.foundPeers[indexPath.row] {
//                        
//                        isHistory = true
//                        
//                        if (message.messages.count != 0) {
//                            cell.setLatestMessage(latestMessage: message.messages[message.messages.count-1])
//                            break
//                        }
//                        else {
//                            cell.setLatestMessage(latestMessage: "No history")
//                            break
//                        }
//                    }
//                }
//                
//                if (!isHistory) {
//                    cell.setLatestMessage(latestMessage: "No history")
//                }
//                
//                //TODO: Add tap gesture recognizer
//                
//                print("PeerView > cellForRowAt > Exit")
//                return cell
//            }
//            else {
//                let cellIdentifier = "PeerTableViewCell"
//                let tempCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as UITableViewCell
//                
//                tempCell.textLabel?.text = "Searching for peers..."
//                tempCell.selectionStyle = UITableViewCellSelectionStyle.none
//                
//                print("PeerView > cellForRowAt > Exit")
//                return tempCell
//            }
//        }
//        else {  // The peer is currently connected to
//            //TODO: Must change if allowed to connect to multiple users in one chat
//            print("PeerView > cellForRowAt > # of connectedPeers in session = \(appDelegate.connectionManager.sessions[indexPath.row].connectedPeers.count)")
//            cell.setPeerDisplayName(displayName: appDelegate.connectionManager.sessions[indexPath.row].connectedPeers[0].displayName)
//            
//            let index = getIndexForPeer(peer: appDelegate.connectionManager.sessions[indexPath.row].connectedPeers[0])
//            
//            // Check if messages exist, if so show the last message
//            if (messages[index].messages.count != 0) {
//                let messagesIndex = messages[index].messages.count-1
//                cell.setLatestMessage(latestMessage: messages[index].messages[messagesIndex])
//                print("PeerView > cellForRowAt > Latest message to \(messages[index].messages[messagesIndex])")
//            }
//            else {
//                print("PeerView > cellForRowAt > No history.")
//                cell.setLatestMessage(latestMessage: "No history.")
//            }
//            
//            print("PeerView > cellForRowAt > Set text label as: \(cell.peerDisplayNameLabel?.text)")
//            cell.peerIsAvailable()
//            
//            // TODO: Add tap gesture recognizer
//            
//            cell.selectionStyle = UITableViewCellSelectionStyle.blue
//            
//            print("PeerView > cellForRowAt > Exit")
//            return cell
//        }
//    }
    
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
        print("PeerView > didSelectRowAt > Entry")
        
        if let currCell = peersTable.cellForRow(at: indexPath) as? PeerTableViewCell {
            print("PeerView > didSelectRowAt > Current cell is PeerTableViewCell")
            
            // if the peer selected is available
            if indexPath.section == 0 {
                
                let optionMenu = UIAlertController(title: nil, message: "Select an option", preferredStyle: .actionSheet)
                
                let phoneOption = UIAlertAction(title: "Voice", style: .default, handler: { (alert: UIAlertAction!) -> Void in
                    
                    let check = self.appDelegate.connectionManager.findSinglePeerSession(peer: currCell.peerID!)
                    if (check == -1) {
                        
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
//                            print("PeerView > didSelectRowAt > Successfully created stream")
                            
                        self.destinationPeerID = currCell.peerID!
                        self.isDestPeerIDSet = true
                        
                        OperationQueue.main.addOperation { () -> Void in
                            print("PeerView > didSelectRowAt > Performing segue")
                            self.performSegue(withIdentifier: "callSegue", sender: self)
                        }
                    }
                    else {
                        
                        self.destinationPeerID = currCell.peerID
                        self.isDestPeerIDSet = true
                        
//                        let outputStream = try self.appDelegate.connectionManager.sessions[check].startStream(withName: "motoIntercom", toPeer: currCell.peerID!)
//                        print("PeerView > didSelectRowAt > Successfully created stream.")
                        
                        // Perform segue to phone view
                        OperationQueue.main.addOperation { () -> Void in
                            self.performSegue(withIdentifier: "callSegue", sender: self)
                        }
                    }
                })
                
                let chatOption = UIAlertAction(title: "Message", style: .default, handler: { (alert: UIAlertAction!) -> Void in
                    
                    currCell.removeNewMessageIcon()
                    print("PeerView > didSelectRowAt > Checking if connected to \(currCell.peerID?.displayName)")
                    
                    let check = self.appDelegate.connectionManager.findSinglePeerSession(peer: currCell.peerID!)
                    
                    // if check is -1 then create a new session
                    if (check == -1) {
                        
                        // Set connection type to message
                        let peerIndex = self.getIndexForPeer(peer: currCell.peerID!)
                        self.messages[peerIndex].setConnectionTypeToMessage()
                        
                        print("PeerView > didSelectRowAt > Creating a new session")
                        
                        //Create a new session
                        let index = self.appDelegate.connectionManager.createNewSession()
                        
                        // Set the isPhoneCall to false so that the receiver knows it's a message
                        let isPhoneCall = false
                        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
                        
                        print("PeerView > didSelectRowAt > Setting isPhoneCall=\(isPhoneCall)")
                        
                        // Invite the peer to communicate
                        self.appDelegate.connectionManager.browser.invitePeer(currCell.peerID!, to: self.appDelegate.connectionManager.sessions[index], withContext: dataToSend, timeout: 20)
                        
                        // TODO: If the user declines the invitation, then delete the session
                    }
                    else {  //Session already exists, then perform segue
                        print("PeerView > didSelectRowAt > Session exists")
                        
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
                    // Do nothing
                })
                
                optionMenu.addAction(phoneOption)
                optionMenu.addAction(chatOption)
                optionMenu.addAction(cancelOption)
                
                print("PeerView > didSelectRowAt > Presenting option menu")
                
                OperationQueue.main.addOperation { () -> Void in
                    self.present(optionMenu, animated: true, completion: nil)
                }
            }
            else {  //The peer selected is not available so segue to the conversation
                
                print("PeerView > didSelectRowAt > Performing segue...")
                
                self.isDestPeerIDSet = false
                self.destinationPeerID = currCell.peerID
                
                OperationQueue.main.addOperation { () -> Void in
                    self.performSegue(withIdentifier: "idChatSegue", sender: self)
                }
            }
        }
        print("PeerView > didSelectRowAt > Exit")
        // Else do nothing
    }
    
    
//    //When a cell is selected
//    //TODO
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        print("PeerView > didSelectRowAt > A peer has been selected")
//        if (indexPath.section == 0) {
//            print("PeerView > didSelectRowAt > Performing segue...")
//            OperationQueue.main.addOperation { () -> Void in
//                self.performSegue(withIdentifier: "idChatSegue", sender: self)
//            }
//        }
//        else {
//            if (appDelegate.connectionManager.foundPeers.count != 0) {
//                // get selected peer
//                let selectedPeer = appDelegate.connectionManager.foundPeers[indexPath.row] as MCPeerID
//                
//                print("PeerView > didSelectRowAt > attempting to connect to peer \(selectedPeer.displayName)")
//                
//                //TODO: Create new session first
//                let index = appDelegate.connectionManager.createNewSession()
//                
//                //Send invite to peer
//                appDelegate.connectionManager.browser.invitePeer(selectedPeer, to: appDelegate.connectionManager.sessions[index], withContext: nil, timeout: 20)
//                
//                //TODO: If the peer declines the invitation then delete the session.
//                tableView.reloadData()
//            }
//            else {
//                tableView.reloadData()
//            }
//        }
//    }
    
    
    
    //MARK: Connection Manager
    
    // If a peer was found, then reload data
    func foundPeer(_ newPeer: MCPeerID) {
        print("PeerView > foundPeer > Entry")
        
        let index = doesMessageObjectExist(forPeer: newPeer)
        
        // if message object does not exist, create it
        if index == -1 {
            let messageObject = MessageObject.init(peerID: newPeer, messageFrom: [], messages: [])
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
        print("PeerView > foundPeer > Exit")
    }
    
    // If a peer was lost, then reload data
    func lostPeer(_ lostPeer: MCPeerID) {
        print("PeerView > lostPeer > Entry")
        
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
        print("PeerView > lostPeer > Exit")
    }
    
    // When an invite is received
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        print("PeerView > inviteWasReceived > Entry: isPhoneCall=\(isPhoneCall)")
        
        if (!isPhoneCall) {
            
            let alert = UIAlertController(title: "", message: "\(fromPeer.displayName) wants to chat with you.", preferredStyle: UIAlertControllerStyle.alert)
            
            let acceptAction: UIAlertAction = UIAlertAction(title: "Accept", style: UIAlertActionStyle.default) { (alertAction) -> Void in
                
                // Set the connection type to message
                let peerIndex = self.getIndexForPeer(peer: fromPeer)
                self.messages[peerIndex].setConnectionTypeToMessage()
                
                let index = self.appDelegate.connectionManager.createNewSession()
                    
                print("PeerView > inviteWasReceived > Accepted invitation handler")
                
                if self.appDelegate.connectionManager.invitationHandler != nil {
                    self.appDelegate.connectionManager.invitationHandler!(true, self.appDelegate.connectionManager.sessions[index])
                    
                    self.destinationPeerID = fromPeer
                    self.isDestPeerIDSet = true
                }
                
//                OperationQueue.main.addOperation { () -> Void in
//                    self.performSegue(withIdentifier: "idChatSegue", sender: self)
//                }
            }
            
            let declineAction: UIAlertAction = UIAlertAction(title: "Decline", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
                print("PeerView > inviteWasReceived > Declined invitation")
                
                var sess : MCSession?
                var sessIndex = self.appDelegate.connectionManager.findSinglePeerSession(peer: fromPeer)
                
                if sessIndex == -1 {
                    print("PeerView > inviteWasReceived > Session could not be found...")
                    sessIndex = self.appDelegate.connectionManager.createNewSession()
                }
                
                sess = self.appDelegate.connectionManager.sessions[sessIndex]
                
                if self.appDelegate.connectionManager.invitationHandler != nil && sess != nil {
                    self.appDelegate.connectionManager.invitationHandler!(false, sess!)
                }
                else {
                    print("PeerView > inviteWasReceived > invitationHandler or session is nil")
                }
            }
            
            alert.addAction(acceptAction)
            alert.addAction(declineAction)
            
            OperationQueue.main.addOperation { () -> Void in
                self.present(alert, animated: true, completion: nil)
            }
        }
        else {
            // TODO: Need to make an incoming call overlay
            
            // TODO: Only do the following if the user accepts the call
            let peerIndex = getIndexForPeer(peer: fromPeer)
            messages[peerIndex].setConnectionTypeToVoice()
            
            print("PeerView > foundPeer > Incoming call!")
        }
        print("PeerView > foundPeer > Exit")
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        print("PeerView > connectedWithPeer > Connected to peer \(peerID)")
        
        // Remove the peer from foundPeers
        appDelegate.connectionManager.removeFoundPeer(peerID: peerID)
        
        destinationPeerID = peerID  // This is used so we know what peer was clicked on
        isDestPeerIDSet = true
        
        let peerIndex = getIndexForPeer(peer: peerID)
        let connType = messages[peerIndex].connectionType
        
        
        if (connType == MESSAGE_CONNECTION_TYPE) {
            print("PeerView > connectedWithPeer > Connection type is MESSAGE_CONNECTION_TYPE)")
            OperationQueue.main.addOperation {
                self.performSegue(withIdentifier: "idChatSegue", sender: self)
            }
        }
        else if (connType == PHONE_CONNECTION_TYPE) {
            print("PeerView > connectedWithPeer > Connection type is PHONE_CONNECTION_TYPE)")
            OperationQueue.main.addOperation {
                self.performSegue(withIdentifier: "callSegue", sender: self)
            }
        }
        else {
            print("PeerView > connectedWithPeer > Could NOT recognize a connection type. Cannot perform segue.")
        }
        
    }
    
    // Called when a peer is disconnected from
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("PeerView > disconnectedFromPeer > Entry: Disconnected from peer \(peerID)")
        
        // Resetting the peers connected type
        let peerIndex = getIndexForPeer(peer: peerID)
        messages[peerIndex].resetConnectionType()
        
        if let currView = navigationController?.topViewController as? ChatViewController {
            print("PeerView > disconnectedFromPeeer > topViewController is ChatView. ")
            if (peerID == currView.messages.peerID) {
                let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(currView.messages.peerID.displayName)", preferredStyle: UIAlertControllerStyle.alert)

                let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (alertAction) -> Void in

                    //Go back to PeerView
                    _ = self.navigationController?.popViewController(animated: true)
                }

                alert.addAction(okAction)

//                currView.messages.isAvailable = false
                
                OperationQueue.main.addOperation { () -> Void in
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        else {
            print("PeerView > disconnectedFromPeer > Reloading peer table.")
            
            DispatchQueue.main.async {
                self.peersTable.reloadData()
            }
        }
        print("PeerView > disconnectedFromPeer > Exit")
    }
    
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        // TODO: Need to decide what to do when connecting to peer
    }
    
    
    //MARK: Segue
    
    // This function is run before a segue is performed
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("PeerView > prepare > Entry: \(isDestPeerIDSet) destinationPeerID = \(destinationPeerID?.displayName)")
        
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
                
                save()
                
                print("PeerView > prepare > Could not find message object. Creating a new message object.")
                
                dest!.messages = self.messages[messages.count-1]
            }
        }
        else if (segue.identifier == "idChatSegue") {
            let dest = segue.destination as? ChatViewController
            var messageIsSet = false
            
            for message in messages {
                if message.peerID == destinationPeerID {
                    dest?.messages = message
                    
                    messageIsSet = true
                    break
                }
            }
            
            if (!messageIsSet) {
                print("PeerView > prepare > ERROR: THIS SHOULD NEVER BE PRINTED.")
            }
            
//            dest?.messageField.isEditable = false
//            dest?.messageField.isSelectable = false
//            dest?.messageField.isUserInteractionEnabled = false
        }
        else if (segue.identifier == "callSegue" && isDestPeerIDSet) {
            print("PeerView > prepare > current segue is callSegue")
            
            let dest = segue.destination as? PhoneViewController
            dest?.peerID = destinationPeerID
            
            // TODO: Need to finish
            
        }
        
        print("PeerView > prepare > Exit")
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if (isDestPeerIDSet == true) {
            print("PeerView > shouldPerformSegue > Return true - 1")
            return true
        }
        else if (isDestPeerIDSet == false && destinationPeerID != nil) {
            print("PeerView > shouldPerformSegue > Return true - 2")
            return true
        }
        
        print("PeerView > shouldPerformSegue > Return false")
        return false
    }
    
    
    //MARK: Save and Load
    
    // Save user information
    func save() {
        print("PeerView > save > Saving messages")
        if (!NSKeyedArchiver.archiveRootObject(self.messages, toFile: MessageObject.ArchiveURL.path)) {
            print("CourseTable: save: Failed to save courses and groups.")
        }
    }
    
    // Load user information
    func load() -> [MessageObject]? {
        print("PeerView > load > Loading messages")
        return (NSKeyedUnarchiver.unarchiveObject(withFile: MessageObject.ArchiveURL.path) as! [MessageObject]?)
    }
}
