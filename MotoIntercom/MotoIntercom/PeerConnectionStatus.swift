//
//  PeerConnectionStatus.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-06-13.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class PeerConnectionStatus: NSObject {
    
    var peers = [MCPeerID]()
    var status = [String]()
    
    let connected = "connected"
    let connecting = "connecting"
    let notConnected = "not connected"
    
    // Adds a new peer to the list
    func addDisconnectedPeer(peer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Adding peer")
        peers.append(peer)
        status.append(notConnected)
    }
    
    // Removes all peers and statuses from the list
    func removeAll() {
        print("\(type(of: self)) > \(#function) > Resetting data")
        peers.removeAll()
        status.removeAll()
    }
    
    // Removes the given peer
    func removePeer(peerID: MCPeerID) {
        if let index = peers.index(of: peerID) {
            peers.remove(at: index)
            status.remove(at: index)
        }
    }
    
    // Returns true if the peer is connected and false otherwise
    func isPeerConnected(peer: MCPeerID) -> Bool {
        
        if status[peers.index(of: peer)!] == connected {
            print("\(type(of: self)) > \(#function) > True")
            return true
        }
        print("\(type(of: self)) > \(#function) > False")
        return false
    }
    
    // Sets the given peers status to connected
    func setToConnected(peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > \(peerID.displayName)")
        if let index = peers.index(of: peerID) {
            status[index] = connected
            return
        }
        print("\(type(of: self)) > \(#function) > Changing status failed")
    }
    
    // Sets the given peers status to connecting
    func setToConnecting(peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > \(peerID.displayName)")
        if let index = peers.index(of: peerID) {
            status[index] = connecting
            return
        }
        print("\(type(of: self)) > \(#function) > Changing status failed")
    }
    
    // Sets the given peers status to not connected
    func setToDisconnected(peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > \(peerID.displayName)")
        if let index = peers.index(of: peerID) {
            status[index] = notConnected
            return
        }
        print("\(type(of: self)) > \(#function) > Changing status failed")
    }
}

