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

class ConnectionManager : NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
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
    var invitationHandler: ((Bool, MCSession!)-> Void)
    
    
    override init() {
        super.init()
        
        peer = MCPeerID(displayName: UIDevice.currentDevice().name)
//        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: ServiceType)
//        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: ServiceType)
//        
//        super.init()
//        
//        self.serviceAdvertiser.delegate = self
//        self.serviceAdvertiser.startAdvertisingPeer()
//        self.serviceBrowser.delegate = self
//        self.serviceBrowser.startBrowsingForPeers()
//    }
//    
//    deinit {
//        self.serviceAdvertiser.stopAdvertisingPeer()
//        self.serviceBrowser.stopBrowsingForPeers()
    }
    
//    lazy var session : MCSession = {
//        let session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.Required)
//        session.delegate = self
//        return session
//    }()
}

extension MCSessionState {
    
    func stringValue() -> String {
        switch(self) {
        case .NotConnected: return "NotConnected"
        case .Connecting: return "Connecting"
        case .Connected: return "Connected"
        default: return "Unknown"
        }
    }
}

extension ConnectionManager : MCSessionDelegate {
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state.stringValue())")
    }
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
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

extension ConnectionManager : MCNearbyServiceAdvertiserDelegate {
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer\(peerID)")
        invitationHandler(true, self.session)
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
}

extension ConnectionManager : MCNearbyServiceBrowserDelegate {
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
    
    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }
}