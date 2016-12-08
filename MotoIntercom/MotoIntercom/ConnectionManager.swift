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
    func foundPeer()
    func lostPeer()
    func inviteWasReceived(_ fromPeer : String)
    func connectedWithPeer(_ peerID : MCPeerID)
}

class ConnectionManager : NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    var delegate : ConnectionManagerDelegate?
    
    //Creating service types, session, peerID, browser and advertiser
    var session : MCSession!
    var peer : MCPeerID!
    var browser : MCNearbyServiceBrowser!
    var advertiser : MCNearbyServiceAdvertiser
    
    //Array of peers
    var foundPeers = [MCPeerID]()
//    var connectedPeers = [MCPeerID]()
    
    //invitation handler
    var invitationHandler: ((Bool, MCSession) -> Void)?
    
    override init() {
        peer = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peer)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: "moto-intercom")
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "moto-intercom")

        super.init()
        
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
    }
    
    //Send data to recipient
    func sendData(dictionaryWithData dictionary: Dictionary<String, String>, toPeer targetPeer: MCPeerID) -> Bool {
        print("ConnectionManager > sendData > Sending data to peer.")
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: dictionary)
        let peersArray = NSArray(object: targetPeer)
        do {
            try session.send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print(error.localizedDescription)
            return false
        }
        return true
    }
    
    //Send MessageObject data to peer
    func sendData(message: MessageObject, toPeer targetPeer: MCPeerID) -> Bool {
        print("ConnectionManager > sendData > Sending message to peer.")
        
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: message)
        let peersArray = NSArray(object: targetPeer)
        
        do {
            try session.send(dataToSend, toPeers: peersArray as! [MCPeerID], with: MCSessionSendDataMode.reliable)
        }
        catch let error as NSError {
            print("ConnectionManager > sendData > Error, data could not be sent for the following reason: \(error.localizedDescription)")
            return false
        }
        return true
    }
    
    //MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        if (!doesPeerAlreadyExist(peerID: peerID)) {
            foundPeers.append(peerID)
            print("ConnectionManager > foundPeer > Peer was found with ID: \(peerID)")
        }
        else {
            print("ConnectionManager > foundPeer > Peer was found but already exists with ID: \(peerID)")
        }
        
        delegate?.foundPeer()
    }
    
    // checks to see if the current peer is already in the table
    func doesPeerAlreadyExist(peerID: MCPeerID) -> Bool {
        for peer in foundPeers {
            if peerID == peer {
                print("ConnectionManager > doesPeerAlreadyExist > True")
                return true
            }
        }
        print("ConnectionManager > doesPeerAlreadyExist > False")
        return false
    }
    
    //removes all previously seen peers
    func resetPeerArray() {
        print("ConnectionManager > resetPeerArray > The peer array is being reset!")
        foundPeers.removeAll()
    }
    
    
    // Called when a peer is lost
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("ConnectionManager > lostPeer > Entry")
        for i in 0 ..< foundPeers.count {
            print("ConnectionManager > lostPeer > Finding the lost peer... \(i)")
            print("ConnectionManager > lostPeer > Check: \(foundPeers[i]) == \(peerID)")
            
            if foundPeers[i] == peerID {
                print("ConnectionManager > lostPeer > Removing peer \(foundPeers[i])")
                foundPeers.remove(at: i)
                break
            }
            
            //Remove the current peer if it is currently connected with
//            if checkIfAlreadyConnected(peerID: peerID) {
//                removeConnectedPeer(peerID: peerID)
//            }
            
            print("ConnectionManager > lostPeer > lostPeer: \(peerID)")
        }
        
        delegate?.lostPeer()
    }
    
    
    //Called to check if the current connection is already in the connectedPeers array
    func checkIfAlreadyConnected(peerID: MCPeerID) -> Bool {
        for peers in session.connectedPeers {
            if (peers == peerID) {
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
    
    //Called when a peer needs to be removed
//    func removeConnectedPeer(peerID: MCPeerID) {
//        for i in 0..<session.connectedPeers.count {
//            if session.connectedPeers[i] == peerID {
////                session.connectedPeers.remove(at: i)
//                return
//            }
//        }
//    }
    
    // Called to remove a peer that is no longer visible or is already connected
    func removeFoundPeer(peerID: MCPeerID) {
        for i in 0..<foundPeers.count {
            if foundPeers[i] == peerID {
                foundPeers.remove(at: i)
                return
            }
        }
    }
    
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("ConnectionManager > didNotStartBrowsingForPeers > \(error)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        self.invitationHandler = invitationHandler
        print("ConnectionManager > didReceiveInvitationFromPeer > \(peerID)")
        delegate?.inviteWasReceived(peerID.displayName)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("ConnectionManager > didNotStartAdvertisingPeer > \(error.localizedDescription)")
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch  state {
        case MCSessionState.connected:
            print("ConnectionManager > session didChange state > Connected to peer: \(peerID)")
            delegate?.connectedWithPeer(peerID)
//            if (!checkIfAlreadyConnected(peerID: peerID)) {
//                connectedPeers.append(peerID)
//            }
            if (doesPeerAlreadyExist(peerID: peerID)) {
                removeFoundPeer(peerID: peerID)
            }
            
        case MCSessionState.connecting:
            print("ConnectionManager > session didChange state > Connecting to peer: \(peerID)")
            
        case MCSessionState.notConnected:
            print("ConnectionManager > session didChange state > Failed to connect to session: \(session)")
            print("ConnectionManager > session didChange state > Currently connected to \(session.connectedPeers.count) sessions")
//            if(checkIfAlreadyConnected(peerID: peerID)) {
//                removeConnectedPeer(peerID: peerID)
//            }
            if (!doesPeerAlreadyExist(peerID: peerID)) {
                foundPeers.append(peerID)
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
//        let dictionary: [String: AnyObject] = ["data": data as AnyObject, "fromPeer": peerID]
//        let newMessage: Data = data as! MessageObject
        NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedMPCDataNotification"), object: data)
        print("ConnectionManager > session didReceive data > Received Data \(data) from peer \(peerID)")
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("ConnectionManager > didReceiveStream")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("ConnectionManager > didFinishReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        print("ConnectionManager > didStartReceivingResourceWithName")
    }
    
}

//extension MCSessionState {
//    
//    func stringValue() -> String {
//        switch(self) {
//        case .NotConnected: return "NotConnected"
//        case .Connecting: return "Connecting"
//        case .Connected: return "Connected"
//        default: return "Unknown"
//        }
//    }
//}
