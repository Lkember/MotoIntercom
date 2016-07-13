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
//    private let ServiceType = "Moto-Intercom"
//    private let myPeerID = MCPeerID(displayName: UIDevice.currentDevice().name)
//    private let serviceAdvertiser : MCNearbyServiceAdvertiser
//    private var serviceBrowser : MCNearbyServiceBrowser
    
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
        NSLog("%@", "foundPeer: \(peerID)")
        
        delegate?.foundPeer()
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if session.connectedPeers[0] == peerID {
            session.disconnect()
        }
        else {
            // changed from original code
            for i in 0 ..< foundPeers.count {
                if foundPeers[i] == peerID {
                    foundPeers.removeAtIndex(i)
                    break
                }
            }
            delegate?.lostPeer()
            NSLog("%@", "lostPeer: \(peerID)")
        }
    }
    
    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
//    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        self.invitationHandler = invitationHandler
        NSLog("%@", "didReceiveInvitationFromPeer: \(peerID)")
        delegate?.inviteWasReceived(peerID.displayName)
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
    
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        switch  state {
        case MCSessionState.Connected:
            NSLog("%@", "Connected to session: \(session)")
            delegate?.connectedWithPeer(peerID)
        case MCSessionState.Connecting:
            NSLog("%@", "Connecting to session: \(session)")
            
        default:
            NSLog("%@", "Failed to connect to session: \(session)")
        }
    }
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        let dictionary: [String: AnyObject] = ["data": data, "fromPeer": peerID]
        NSNotificationCenter.defaultCenter().postNotificationName("receivedMPCDataNotification", object: dictionary)
        NSLog("%@", "didReceiveData: \(data)")
    }
    
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }
    
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
    
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
        NSLog("%@", "didStartReceivingResourceWithName")
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