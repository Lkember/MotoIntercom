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
    
    //MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        if (!doesPeerAlreadyExist(peerID: peerID)) {
            foundPeers.append(peerID)
            delegate?.foundPeer()
            print("ConnectionManager > foundPeer > Peer was found with ID: \(peerID)")
        }
        else {
            print("ConnectionManager > foundPeer > Peer was found but already exists with ID: \(peerID)")
        }
    }
    
    // checks to see if the current peer is already in the table
    func doesPeerAlreadyExist(peerID: MCPeerID) -> Bool {
        for peer in foundPeers {
            if peerID == peer {
                return true
            }
        }
        return false
    }
    
    //removes all previously seen peers
    func resetPeerArray() {
        foundPeers.removeAll()
    }
    
    
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
            
            delegate?.lostPeer()
            print("ConnectionManager > lostPeer > lostPeer: \(peerID)")
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
            
        case MCSessionState.connecting:
            print("ConnectionManager > session didChange state > Connecting to peer: \(peerID)")
            
        case MCSessionState.notConnected:
            print("ConnectionManager > session didChange state > Failed to connect to session: \(session)")
            print("ConnectionManager > session didChange state > Currently connected to \(session.connectedPeers.count) sessions")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let dictionary: [String: AnyObject] = ["data": data as AnyObject, "fromPeer": peerID]
        NotificationCenter.default.post(name: Notification.Name(rawValue: "receivedMPCDataNotification"), object: dictionary)
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
