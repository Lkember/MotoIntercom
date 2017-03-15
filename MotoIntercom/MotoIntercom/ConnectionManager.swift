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


protocol ConnectionManagerDelegate {
    func foundPeer(_ newPeer : MCPeerID)
    func lostPeer(_ lostPeer: MCPeerID)
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool)
    func connectingWithPeer(_ peerID: MCPeerID)
    func connectedWithPeer(_ peerID : MCPeerID)
    func disconnectedFromPeer(_ peerID: MCPeerID)
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream)
}


class ConnectionManager : NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    // MARK: Properties
    
    var delegate : ConnectionManagerDelegate?
    
    //Creating service types, session, peerID, browser and advertiser
    var sessions : [MCSession] = []
    var peer : MCPeerID!
    var browser : MCNearbyServiceBrowser!
    var advertiser : MCNearbyServiceAdvertiser
    
    //Array of peers
    var foundPeers = [MCPeerID]()
    
    //invitation handler
    var invitationHandler: ((Bool, MCSession) -> Void)?
    
    override init() {
        print("\(#file) > \(#function)init > Initializing ConnectionManager with new peer: \(UIDevice.current.name)")
        
        peer = MCPeerID(displayName: UIDevice.current.name)        
        let session = MCSession(peer: peer)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: "moto-intercom")
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "moto-intercom")

        super.init()
        
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
        
        sessions.append(session)
    }
    
    init(peerID : MCPeerID) {
        print("\(#file) > \(#function) > Initializing ConnectionManager with existing peerID: \(peerID.displayName)")
        
        peer = peerID
        let session = MCSession(peer: peer)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: "moto-intercom")
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "moto-intercom")
        
        super.init()
        
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
        
        sessions.append(session)
    }
    
    // a function which returns the index to an unused session
    func checkForReusableSession() -> Int {
        for i in 0..<sessions.count {
            if sessions[i].connectedPeers.count == 0 {
                return i
            }
        }
        return -1
    }
    
    // a function which finds the index for a session with a given peer
    func findSinglePeerSession(peer: MCPeerID) -> Int {
        for i in 0..<sessions.count {
            if (sessions[i].connectedPeers.count == 1 && sessions[i].connectedPeers[0] == peer) {
                return i
            }
        }
        return -1
    }
    
    
    // Creates a new session for a new peer, returns it's index
    func createNewSession() -> Int {
        
        let reusableSession = checkForReusableSession()
        
        if (reusableSession == -1) {
            let session = MCSession(peer: peer)
            session.delegate = self
            sessions.append(session)
            
            print("\(#file) > \(#function) > Creating a new session.")
            return sessions.count - 1
        }
        else {
            print("\(#file) > \(#function) > Found reusable session.")
            return reusableSession
        }
    }
    
    // A function which removes sessions that are not connected with any peers.
    func cleanSessions() {
        print("\(#file) > \(#function) > Entry \(sessions.count)")
        var indexToRemove : [Int] = []
        
        for i in 0..<sessions.count {
            if (sessions[i].connectedPeers.count == 0) {
                indexToRemove.append(i)
            }
        }
        
        indexToRemove.sort()
        
        for i in (0..<sessions.count).reversed() {
            sessions.remove(at: i)
        }
        
        print("\(#file) > \(#function) > Exit \(sessions.count)")
    }
    
    //Send data to recipient
    func sendData(dictionaryWithData dictionary: Dictionary<String, String>, toPeer targetPeer: MCPeerID) -> Bool {
        print("\(#file) > \(#function) > Sending data to peer.")
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: dictionary)
        let peersArray = NSArray(object: targetPeer)
        var sess : MCSession = MCSession(peer: peer)
        
        for session in sessions {
            //TODO: If we allow multi-peer connectivity this method must be modified
            if session.connectedPeers.contains(targetPeer) {
                sess = session
            }
        }
        
        do {
            try sess.send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print(error.localizedDescription)
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
    
    //MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        if (!doesPeerAlreadyExist(peerID: peerID)) {
            foundPeers.append(peerID)
            print("\(#file) > \(#function) > Peer was found with ID: \(peerID.displayName)")
        }
        else {
            print("\(#file) > \(#function) > Peer was found but already exists with ID: \(peerID)")
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
        print("\(#file) > \(#function) > The peer array is being reset!")
        foundPeers.removeAll()
    }
    
    
    // Called when a peer is lost
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("\(#file) > \(#function) > Entry")
        for i in 0 ..< foundPeers.count {
            print("\(#file) > \(#function) > Finding the lost peer... \(i)")
            print("\(#file) > \(#function) > Check: \(foundPeers[i]) == \(peerID)")
            
            if foundPeers[i] == peerID {
                print("\(#file) > \(#function) > Removing peer \(foundPeers[i])")
                foundPeers.remove(at: i)
                break
            }
            
            //Remove the current peer if it is currently connected with
//            if checkIfAlreadyConnected(peerID: peerID) {
//                removeConnectedPeer(peerID: peerID)
//            }
            
            print("\(#file) > \(#function) > lostPeer: \(peerID)")
        }
        
        delegate?.lostPeer(peerID)
    }
    
    
    //Called to check if the current connection is already in the connectedPeers array
    func checkIfAlreadyConnected(peerID: MCPeerID) -> Bool {
        for session in sessions {
            if session.connectedPeers.contains(peerID) {
                return true
            }
        }
        return false
    }
    
    //Called when a new connection with a peer is made.
    func connectedWithPeer(peerID: MCPeerID) {
        if (checkIfAlreadyConnected(peerID: peerID)) {
//            session.connectedPeers.append(peerID)
//            session.connectPeer(peerID, withNearbyConnectionData: nil)
            removeFoundPeer(peerID: peerID)
        }
    }
    
    // Called to remove a peer that is no longer visible or is already connected
    func removeFoundPeer(peerID: MCPeerID) {
        for i in 0..<foundPeers.count {
            if foundPeers[i] == peerID {
                foundPeers.remove(at: i)
                return
            }
        }
    }
    
    
    // MARK: ConnectionManager
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("\(#file) > \(#function) > \(error)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        self.invitationHandler = invitationHandler
        
        let isPhoneCall = NSKeyedUnarchiver.unarchiveObject(with: context!) as! Bool
        
        print("\(#file) > \(#function) > \(peerID), isPhoneCall=\(isPhoneCall)")
        delegate?.inviteWasReceived(peerID, isPhoneCall: isPhoneCall)
    }
    
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("\(#file) > \(#function) > \(error.localizedDescription)")
    }
    
    //MARK: MCSession
    
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
        
        let myDict: [String: AnyObject] = ["data": data as AnyObject, "peer": peerID]
        let archiveData = NSKeyedArchiver.archivedData(withRootObject: myDict)
        
        print("\(#file) > \(#function) > Received \(data) from peer \(peerID.displayName)")
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedMPCDataNotification"), object: archiveData)
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
