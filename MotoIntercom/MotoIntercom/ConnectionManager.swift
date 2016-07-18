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
    func inviteWasReceived(fromPeer : String)
    func connectedWithPeer(peerID : MCPeerID)
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
        peer = MCPeerID(displayName: UIDevice.currentDevice().name)
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
        print("Sending data to peer.")
        let dataToSend = NSKeyedArchiver.archivedDataWithRootObject(dictionary)
        let peersArray = NSArray(object: targetPeer)
        do {
            try session.sendData(dataToSend, toPeers: peersArray as! [MCPeerID], withMode: MCSessionSendDataMode.Reliable)
        }
        catch let error as NSError {
            print(error.localizedDescription)
            return false
        }
        return true
    }
    
    //MCNearbyServiceBrowserDelegate
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        foundPeers.append(peerID)
        print( "foundPeer: \(peerID)")
        
        delegate?.foundPeer()
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Removing lost peers...")
        for i in 0 ..< foundPeers.count {
            print("i = \(i)")
            print("Check: \(foundPeers[i]) == \(peerID)")
            
            if foundPeers[i] == peerID {
                print("Removing peer \(foundPeers[i])")
                foundPeers.removeAtIndex(i)
            }
            
            delegate?.lostPeer()
            print( "lostPeer: \(peerID)")
        }
    }
    
    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        print("didNotStartBrowsingForPeers: \(error)")
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
        self.invitationHandler = invitationHandler
        print("didReceiveInvitationFromPeer: \(peerID)")
        delegate?.inviteWasReceived(peerID.displayName)
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        print("didNotStartAdvertisingPeer: \(error.localizedDescription)")
    }
    
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        switch  state {
        case MCSessionState.Connected:
            print( "Connected to peer: \(peerID)")
            delegate?.connectedWithPeer(peerID)
            
        case MCSessionState.Connecting:
            print("Connecting to peer: \(peerID)")
            
        case MCSessionState.NotConnected:
            print("Failed to connect to session: \(session)")
            print("Currently connected to \(session.connectedPeers.count) sessions")
        }
    }
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        let dictionary: [String: AnyObject] = ["data": data, "fromPeer": peerID]
        NSNotificationCenter.defaultCenter().postNotificationName("receivedMPCDataNotification", object: dictionary)
        print( "Received Data: \(data)")
    }
    
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print( "didReceiveStream")
    }
    
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        print( "didFinishReceivingResourceWithName")
    }
    
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
        print( "didStartReceivingResourceWithName")
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