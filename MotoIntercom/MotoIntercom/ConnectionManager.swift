//
//  ConnectionManager.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-07.
//  Copyright © 2016 Logan Kember. All rights reserved.
//  https://www.ralfebert.de/tutorials/ios-swift-multipeer-connectivity/
//  http://www.appcoda.com/chat-app-swift-tutorial/

import Foundation
import MultipeerConnectivity
import JSQMessagesViewController

protocol ConnectionManagerDelegate {
    func foundPeer(_ newPeer : MCPeerID)
    func lostPeer(_ lostPeer: MCPeerID)
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool)
    func connectingWithPeer(_ peerID: MCPeerID)
    func connectedWithPeer(_ peerID : MCPeerID)
    func disconnectedFromPeer(_ peerID: MCPeerID)
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream)
}


@available(iOS 10.0, *)
class ConnectionManager : NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    // MARK: - Properties
    // Delegates
    var delegate : ConnectionManagerDelegate?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //Creating service types, session, peerID, browser and advertiser
    var uniqueID : String!
    var sessions : [MCSession] = []
    var peer : MCPeerID!
    var browser : MCNearbyServiceBrowser!
    var advertiser : MCNearbyServiceAdvertiser
    
    //Array of peers
    var availablePeers = PeerConnectionStatus.init()
    
    //invitation handler
    var invitationHandler: ((Bool, MCSession) -> Void)?
    
    
    // MARK: - Initialization
    
    override init() {
        print("\(type(of: self)) > \(#function) > Initializing ConnectionManager with new peer: \(UIDevice.current.name)")
        
        self.peer = MCPeerID(displayName: UIDevice.current.name)
        let session = MCSession(peer: peer)
        self.browser = MCNearbyServiceBrowser(peer: peer, serviceType: "moto-intercom")
        self.advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "moto-intercom")
        self.uniqueID = String(NSUUID().uuidString)
        
        super.init()
        
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
        
        sessions.append(session)
    }
    
    init(peerID : MCPeerID, uniqueID : String) {
        print("\(type(of: self)) > \(#function) > Initializing ConnectionManager with existing peerID: \(peerID.displayName)")
        
        self.peer = peerID
        self.uniqueID = uniqueID
        let session = MCSession(peer: peer)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: "moto-intercom")
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "moto-intercom")
        
        super.init()
        
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
        
        sessions.append(session)
    }
    
    
    // MARK: - Sessions
    // A method used to print out how many total sessions and each session
    func debugSessions() {
        print("\(type(of: self)) > \(#function) > Entry > Number of sessions: \(sessions.count)")
        for i in 0..<sessions.count {
            for peer in sessions[i].connectedPeers {
                print("\(type(of: self)) > \(#function) > session \(i): \(peer)")
            }
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    // a function which returns the index to an unused session or -1 if it can't find one
    func checkForReusableSession() -> Int {
        for i in 0..<sessions.count {
            if sessions[i].connectedPeers.count == 0 {
                print("\(type(of: self)) > \(#function) > returning \(i)")
                return i
            }
        }
        print("\(type(of: self)) > \(#function) > No reusable sessions found")
        return -1
    }
    
    // a function which finds the index for a session with a given peer
    func findSinglePeerSession(peer: MCPeerID) -> Int {
        print("\(type(of: self)) > \(#function) > Entry \(sessions.count)")
        for i in 0..<sessions.count {
            if (sessions[i].connectedPeers.contains(peer) && sessions[i].connectedPeers.count == 1) {
                print("\(type(of: self)) > \(#function) > Exit: Found session \(i)")
                return i
            }
        }
        print("\(type(of: self)) > \(#function) > Could not find session")
        return -1
    }
    
    
    // Creates a new session for a new peer, returns it's index
    func createNewSession() -> Int {
        print("\(type(of: self)) > \(#function) > Entry")
        
        let reusableSession = checkForReusableSession()
        
        if (reusableSession == -1) {
            let session = MCSession(peer: peer)
            session.delegate = self
            sessions.append(session)
            
            print("\(type(of: self)) > \(#function) > Exit > Creating a new session.")
            return sessions.count - 1
        }
        else {
            print("\(type(of: self)) > \(#function) > Exit > Found reusable session.")
            return reusableSession
        }
    }
    
    // A function which removes sessions that are not connected with any peers.
    func cleanSessions() {
        print("\(type(of: self)) > \(#function) > Entry \(sessions.count)")
        var indexesToRemove : [Int] = []
        
        for i in 0..<sessions.count {
            if (sessions[i].connectedPeers.count == 0) {
                indexesToRemove.append(i)
            }
        }
        
        indexesToRemove.sort()
        
        for i in (0..<sessions.count).reversed() {
            sessions.remove(at: i)
        }
        
        print("\(type(of: self)) > \(#function) > Exit \(sessions.count)")
    }
    
    
    // MARK: - Sending Data
    
    // Send a StandardMessage to the peer
    func sendData(stringMessage: String, toPeer targetPeer: MCPeerID) -> Bool {
        print("\(type(of: self)) > \(#function) > Sending \(stringMessage) to peer.")
        
        let message = StandardMessage.init(message: stringMessage, peerID: self.appDelegate.connectionManager.peer)
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: message)
        let peersArray = NSArray(object: targetPeer)
        let peerIndex = findSinglePeerSession(peer: targetPeer)
        
        if (peerIndex == -1) {
            print("\(type(of: self)) > \(#function) > Could not find peer")
            return false
        }
        
        do {
            try sessions[peerIndex].send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print("\(type(of: self)) > \(#function) > Error, data could not be sent for the following reason: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    //Send MessageObject data to peer
    func sendData(message: MessageObject, toPeer targetPeer: MCPeerID) -> Bool {
        print("\(type(of: self)) > \(#function) > Sending message to peer.")
        
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: message)
        let peersArray = NSArray(object: targetPeer)
        var sess : MCSession = MCSession(peer: peer)
        
        for session in sessions {
            //TODO: If we allow multi-peer connectivity this method must be modified
            if session.connectedPeers.contains(targetPeer) {
                sess = session
            }
            else {
                // TODO: If message fails to send we need to connect to peer
                print("\(type(of: self)) > \(#function) > Not connected to peer. Message couldn't be sent.")
            }
        }
        
        do {
            try sess.send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print("\(type(of: self)) > \(#function) > Error, data could not be sent for the following reason: \(error.localizedDescription)")
            return false
        }
        return true
    }
    
//    // Send AVAudioFormat to peer - used by PhoneViewController
//    func sendData(format: AVAudioFormat, toPeer targetPeer: MCPeerID) -> Bool {
//        print("\(type(of: self)) > \(#function) > Sending audio format")
//        
//        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: format)
//        let peersArray = NSArray(object: targetPeer)
//        var sess : MCSession = MCSession(peer: peer)
//        
//        for session in sessions {
//            //TODO: If we allow multi-peer connectivity this method must be modified
//            if session.connectedPeers.contains(targetPeer) {
//                sess = session
//            }
//            else {
//                // TODO: If message fails to send we need to connect to peer
//                print("\(type(of: self)) > \(#function) > Not connected to peer. Message couldn't be sent.")
//                
//                return false
//            }
//        }
//        do {
//            try sess.send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
//        }
//        catch let error as NSError {
//            print("\(type(of: self)) > \(#function) > Error, data could not be sent for the following reason: \(error.localizedDescription)")
//            return false
//        }
//        
//        return true
//    }
    
    // Send AVAudioFormat to peer - used by PhoneViewController
    func sendData(format: [NSObject], toPeer targetPeer: MCPeerID, sessionIndex: Int) -> Bool {
        print("\(type(of: self)) > \(#function) > Sending audio format")
        
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: format)
        let peersArray = NSArray(object: targetPeer)
        
        do {
            try sessions[sessionIndex].send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print("\(type(of: self)) > \(#function) > Error, data could not be sent for the following reason: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    
    // MARK: - Peers
    
    //MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        if (!availablePeers.peers.contains(peerID)) {
            availablePeers.addDisconnectedPeer(peer: peerID)
            connectToPeer(peerID: peerID, isPhoneCall: false)
        }
        
        delegate?.foundPeer(peerID)
    }

    // Checks to see if a peer is already in the availablePeers array
    func doesPeerExist(peerID: MCPeerID) -> Bool {
        
        if availablePeers.peers.contains(peerID) {
            print("\(type(of: self)) > \(#function) > True")
            return true
        }
        
        print("\(type(of: self)) > \(#function) > False")
        return false
    }
    
    //removes all previously seen peers
    func resetPeerArray() {
        print("\(type(of: self)) > \(#function) > Removing all found peers")
        availablePeers.removeAll()
    }
    
    
    // Called when a peer is lost
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
        print("\(type(of: self)) > \(#function) > Return > Removing peer \(peerID.displayName)")
        availablePeers.removePeer(peerID: peerID)
        
        delegate?.lostPeer(peerID)
    }
    
    
    //Called to check if the current connection is already in the connectedPeers array
    func checkIfAlreadyConnected(peerID: MCPeerID) -> Bool {
        print("\(type(of: self)) > \(#function) > Entry")
        for session in sessions {
            if (session.connectedPeers.contains(peerID) && session.connectedPeers.count == 1) {
                print("\(type(of: self)) > \(#function) > Return True")
                return true
            }
        }
        print("\(type(of: self)) > \(#function) > Return False")
        return false
    }
    
    
    // Called to get all available peers that are not in the session given by sessionIndex
    func getPeersNotInSession(sessionIndex: Int) -> [MCPeerID] {
        var peers = [MCPeerID]()
        
        for peer in availablePeers.peers {
            if (!sessions[sessionIndex].connectedPeers.contains(peer)) {
                peers.append(peer)
            }
        }
        
        return peers
    }
    
    func connectToPeer(peerID: MCPeerID, isPhoneCall: Bool) {
        print("\(type(of: self)) > \(#function) > Sending connection request to peer \(peerID)")
        //Connecting to peer
        if (!checkIfAlreadyConnected(peerID: peerID)) {
            
            let sessionIndex = createNewSession()
            let dataToSend = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
            
            if (sessionIndex < self.sessions.count) {
                self.appDelegate.connectionManager.browser.invitePeer(peerID, to: self.sessions[sessionIndex], withContext: dataToSend, timeout: 20)
            }
        }
    }
    
    // MARK: - ConnectionManager
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("\(type(of: self)) > \(#function) > \(error)")
    }

    
    /*
        This function will automatically accept invitations if it is not a phone call. This way there will always be a session
        for each peer. The reason for this is to avoid connection times. So when a user clicks on a peer to chat, it will 
        immediately go into the chat.
     */
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        self.invitationHandler = invitationHandler
        let isPhoneCall = NSKeyedUnarchiver.unarchiveObject(with: context!) as! Bool
        
        
        // Automatically connecting to the user if it is not a phone call
        if (!isPhoneCall) {
            if (findSinglePeerSession(peer: peerID) == -1) {
                
                let index = self.createNewSession()
                invitationHandler(true, sessions[index])    //Accepting connection
            }
        }
        
        delegate?.inviteWasReceived(peerID, isPhoneCall: isPhoneCall)
    }
    
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("\(type(of: self)) > \(#function) > \(error.localizedDescription)")
    }
    
    //MARK: - MCSession
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch  state {
        case MCSessionState.connected:
            print("\(type(of: self)) > \(#function) > Connected to peer: \(peerID)")
            
            availablePeers.setToConnected(peerID: peerID)
            delegate?.connectedWithPeer(peerID)
            
        case MCSessionState.connecting:
            print("\(type(of: self)) > \(#function) > Connecting to peer: \(peerID)")
            
            availablePeers.setToConnecting(peerID: peerID)
            delegate?.connectingWithPeer(peerID)
            
        case MCSessionState.notConnected:
            print("\(type(of: self)) > \(#function) > Failed to connect to session: \(session)")
            
            availablePeers.setToDisconnected(peerID: peerID)
            delegate?.disconnectedFromPeer(peerID)
            
            connectToPeer(peerID: peerID, isPhoneCall: false)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        if let newMessage = NSKeyedUnarchiver.unarchiveObject(with: data) as? StandardMessage {
            print("\(type(of: self)) > \(#function) > Received \(newMessage.message) from peer \(peerID.displayName)")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedStandardMessageNotification"), object: newMessage)
        }
        else if let newMessage = NSKeyedUnarchiver.unarchiveObject(with: data) as? MessageObject {
            print("\(type(of: self)) > \(#function) > Received new message from peer \(peerID.displayName)")
            newMessage.peerID = peerID
            NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedMessageObjectNotification"), object: newMessage)
        }
        else if let newMessage = NSKeyedUnarchiver.unarchiveObject(with: data) as? [NSObject] {
            print("\(type(of: self)) > \(#function) > Received audio format from peer \(peerID.displayName)")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedAVAudioFormat"), object: newMessage)
        }
        
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > from peer \(peerID.displayName) with streamName \(streamName)")
        delegate?.startedStreamWithPeer(peerID, inputStream: stream)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("\(type(of: self)) > \(#function)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("\(type(of: self)) > \(#function)")
    }
    
}
