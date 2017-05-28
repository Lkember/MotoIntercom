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
    var foundPeers = [MCPeerID]()
    
    //invitation handler
    var invitationHandler: ((Bool, MCSession) -> Void)?
    
    
    // MARK: - Initialization
    
    override init() {
        print("\(#file) > \(#function) > Initializing ConnectionManager with new peer: \(UIDevice.current.name)")
        
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
        print("\(#file) > \(#function) > Initializing ConnectionManager with existing peerID: \(peerID.displayName)")
        
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
        print("\(#file) > \(#function) > Entry")
        print("\(#file) > \(#function) > Number of sessions: \(sessions.count)")
        for session in sessions {
            for peer in session.connectedPeers {
                print("\(#file) > \(#function) > Connected with peer: \(peer)")
            }
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    
    // a function which returns the index to an unused session or -1 if it can't find one
    func checkForReusableSession() -> Int {
        for i in 0..<sessions.count {
            if sessions[i].connectedPeers.count == 0 {
                print("\(#file) > \(#function) > returning \(i)")
                return i
            }
        }
        print("\(#file) > \(#function) > No reusable sessions found")
        return -1
    }
    
    // a function which finds the index for a session with a given peer
    func findSinglePeerSession(peer: MCPeerID) -> Int {
        print("\(#file) > \(#function) > Entry")
        for i in 0..<sessions.count {
            if (sessions[i].connectedPeers.contains(peer) && sessions[i].connectedPeers.count == 1) {
                print("\(#file) > \(#function) > Exit: Found session \(i)")
                return i
            }
        }
        print("\(#file) > \(#function) > Could not find session")
        return -1
    }
    
    
    // Creates a new session for a new peer, returns it's index
    func createNewSession() -> Int {
        print("\(#file) > \(#function) > Entry")
        
        let reusableSession = checkForReusableSession()
        
        if (reusableSession == -1) {
            let session = MCSession(peer: peer)
            session.delegate = self
            sessions.append(session)
            
            print("\(#file) > \(#function) > Exit > Creating a new session.")
            return sessions.count - 1
        }
        else {
            print("\(#file) > \(#function) > Exit > Found reusable session.")
            return reusableSession
        }
    }
    
    // A function which removes sessions that are not connected with any peers.
    func cleanSessions() {
        print("\(#file) > \(#function) > Entry \(sessions.count)")
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
        
        print("\(#file) > \(#function) > Exit \(sessions.count)")
    }
    
    
    // MARK: - Sending Data
    
    // Send a StandardMessage to the peer
    func sendData(stringMessage: String, toPeer targetPeer: MCPeerID) -> Bool {
        print("\(#file) > \(#function) > Sending \(stringMessage) to peer.")
        
        let message = StandardMessage.init(message: stringMessage, peerID: self.appDelegate.connectionManager.peer)
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: message)
        let peersArray = NSArray(object: targetPeer)
        let peerIndex = findSinglePeerSession(peer: targetPeer)
        
        if (peerIndex == -1) {
            print("\(#file) > \(#function) > Could not find peer")
            return false
        }
        
        do {
            try sessions[peerIndex].send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > Error, data could not be sent for the following reason: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    //Send MessageObject data to peer
    func sendData(message: MessageObject, toPeer targetPeer: MCPeerID) -> Bool {
        print("\(#file) > \(#function) > Sending message to peer.")
        
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
                print("\(#file) > \(#function) > Not connected to peer. Message couldn't be sent.")
            }
        }
        
        do {
            try sess.send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > Error, data could not be sent for the following reason: \(error.localizedDescription)")
            return false
        }
        return true
    }
    
    // Send AVAudioFormat to peer - used by PhoneViewController
    func sendData(format: AVAudioFormat, toPeer targetPeer: MCPeerID) -> Bool {
        print("\(#file) > \(#function) > Sending audio format")
        
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: format)
        let peersArray = NSArray(object: targetPeer)
        var sess : MCSession = MCSession(peer: peer)
        
        for session in sessions {
            //TODO: If we allow multi-peer connectivity this method must be modified
            if session.connectedPeers.contains(targetPeer) {
                sess = session
            }
            else {
                // TODO: If message fails to send we need to connect to peer
                print("\(#file) > \(#function) > Not connected to peer. Message couldn't be sent.")
                
                return false
            }
        }
        do {
            try sess.send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print("\(#file) > \(#function) > Error, data could not be sent for the following reason: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    
    // MARK: - Peers
    
    //MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        if (!doesPeerAlreadyExist(peerID: peerID)) {
            foundPeers.append(peerID)
            print("\(#file) > \(#function) > Peer was found with ID: \(peerID.displayName)")
        }
        else {
            print("\(#file) > \(#function) > Peer was found but already exists with ID: \(peerID)")
        }
        
        //Connecting to peer
        if (!checkIfAlreadyConnected(peerID: peerID)) {
            
            let sessionIndex = createNewSession()
            let isPhoneCall = false
            let dataToSend = NSKeyedArchiver.archivedData(withRootObject: isPhoneCall)
            
            self.appDelegate.connectionManager.browser.invitePeer(peerID, to: self.sessions[sessionIndex], withContext: dataToSend, timeout: 20)
        }
        
        delegate?.foundPeer(peerID)
    }
    
    // checks to see if the current peer is already in the table
    func doesPeerAlreadyExist(peerID: MCPeerID) -> Bool {
        for peer in foundPeers {
            if peerID == peer {
                print("\(#file) > \(#function) > True")
                return true
            }
        }
        print("\(#file) > \(#function) > False")
        return false
    }
    
    //removes all previously seen peers
    func resetPeerArray() {
        print("\(#file) > \(#function) > Removing all found peers")
        foundPeers.removeAll()
    }
    
    
    // Called when a peer is lost
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("\(#file) > \(#function) > Entry > lostPeer \(peerID)")
        for i in 0 ..< foundPeers.count {
            
            if foundPeers[i] == peerID {
                print("\(#file) > \(#function) > Return > Removing peer \(foundPeers[i])")
                foundPeers.remove(at: i)
                break
            }
            
            print("\(#file) > \(#function) > lostPeer: \(peerID)")
        }
        
        delegate?.lostPeer(peerID)
    }
    
    
    //Called to check if the current connection is already in the connectedPeers array
    func checkIfAlreadyConnected(peerID: MCPeerID) -> Bool {
        print("\(#file) > \(#function) > Entry")
        for session in sessions {
            if (session.connectedPeers.contains(peerID) && session.connectedPeers.count == 1) {
                print("\(#file) > \(#function) > Return True")
                return true
            }
        }
        print("\(#file) > \(#function) > Return False")
        return false
    }
    
    //Called when a new connection with a peer is made.
    func connectedWithPeer(peerID: MCPeerID) {
        print("\(#file) > \(#function) > Calling connected with peer.")
        if (checkIfAlreadyConnected(peerID: peerID)) {
//            session.connectedPeers.append(peerID)
//            session.connectPeer(peerID, withNearbyConnectionData: nil)
            removeFoundPeer(peerID: peerID)
        }
    }
    
    // Called to remove a peer that is no longer visible or is already connected
    func removeFoundPeer(peerID: MCPeerID) {
        print("\(#file) > \(#function) > Removing peer \(peerID.displayName)")
        for i in 0..<foundPeers.count {
            if foundPeers[i] == peerID {
                foundPeers.remove(at: i)
                return
            }
        }
    }
    
    
    // MARK: - ConnectionManager
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("\(#file) > \(#function) > \(error)")
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
        print("\(#file) > \(#function) > \(error.localizedDescription)")
    }
    
    //MARK: - MCSession
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch  state {
        case MCSessionState.connected:
            print("\(#file) > \(#function) > Connected to peer: \(peerID)")
            delegate?.connectedWithPeer(peerID)

            if (doesPeerAlreadyExist(peerID: peerID)) {
                removeFoundPeer(peerID: peerID)
            }
            
        case MCSessionState.connecting:
            print("\(#file) > \(#function) > Connecting to peer: \(peerID)")
            delegate?.connectingWithPeer(peerID)
            
        case MCSessionState.notConnected:
            print("\(#file) > \(#function) > Failed to connect to session: \(session)")
            
            delegate?.disconnectedFromPeer(peerID)
            if (!doesPeerAlreadyExist(peerID: peerID)) {
                foundPeers.append(peerID)
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        if let newMessage = NSKeyedUnarchiver.unarchiveObject(with: data) as? StandardMessage {
            print("\(#file) > \(#function) > Received \(newMessage.message) from peer \(peerID.displayName)")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedStandardMessageNotification"), object: newMessage)
        }
        else if let newMessage = NSKeyedUnarchiver.unarchiveObject(with: data) as? MessageObject {
            print("\(#file) > \(#function) > Received new message from peer \(peerID.displayName)")
            newMessage.peerID = peerID
            NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedMessageObjectNotification"), object: newMessage)
        }
        else if let newMessage = NSKeyedUnarchiver.unarchiveObject(with: data) as? AVAudioFormat {
            print("\(#file) > \(#function) > Received audio format from peer \(peerID.displayName)")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedAVAudioFormat"), object: newMessage)
        }
        
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("\(#file) > \(#function) > from peer \(peerID.displayName) with streamName \(streamName)")
        delegate?.startedStreamWithPeer(peerID, inputStream: stream)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("\(#file) > \(#function)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        print("\(#file) > \(#function)")
    }
    
}
