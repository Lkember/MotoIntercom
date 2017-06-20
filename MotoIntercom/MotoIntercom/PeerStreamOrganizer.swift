//
//  PeerStreamOrganizer.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-06-15.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import AVFoundation

@available(iOS 10.0, *)
class PeerStreamOrganizer: NSObject {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
//    var peersToJoin = [MCPeerID]()              //This array is used to hold peers who have been invited to the phone call
    
    var peers = [MCPeerID]()                    //Holds peers in the current phone call
    var inputStreams = [InputStream]()          //Holds inputStreams for the current peers
    var outputStreams = [OutputStream]()        //Holds outputStreams for the current peers
    var inputStreamIsSet = [Bool]()             //Holds a boolean value for if the inputStreams have been initialized
    var outputStreamIsSet = [Bool]()            //Holds a boolean value for if the outputStreams have been initialized
    var audioFormatForPeer = [AVAudioFormat]()  //Holds the audio format for a given peer
    
    var sessionIndex: Int?
    
    // MARK: - Peers
    
    // A function which adds a new peer
    func addNewPeer(peer: MCPeerID) {
        
        if (!peers.contains(peer)) {
            
            print("\(type(of: self)) > \(#function) > adding peer \(peer.displayName)")
            peers.append(peer)
            inputStreams.append(InputStream())
            outputStreams.append(OutputStream())
            inputStreamIsSet.append(false)
            outputStreamIsSet.append(false)
            audioFormatForPeer.append(AVAudioFormat.init())
        }
        else {
            print("\(type(of: self)) > \(#function) > PEER ALREADY EXISTS!!")
        }
    }
    
    // Returns the index for a peer
    func indexFor(peer: MCPeerID) -> Int {
        if let index = peers.index(of: peer) {
            return index
        }
        return -1
    }
    
    func peerWasLost(peer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Entry")
        if let index = peers.index(of: peer) {
            closeStreamsForPeer(peer: peer)
            
            peers.remove(at: index)
            outputStreamIsSet.remove(at: index)
            outputStreams.remove(at: index)
            inputStreamIsSet.remove(at: index)
            inputStreams.remove(at: index)
            print("\(type(of: self)) > \(#function) > Peer Removed")
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
//    func addPotentialPeer(peer: MCPeerID) {
//        print("\(type(of: self)) > \(#function) > adding peer \(peer.displayName)")
//        peersToJoin.append(peer)
//        
//        var timer = Timer.init(timeInterval: 20, repeats: false, block: {(timer) in
//            if let index = self.peersToJoin.index(of: peer) {
//                print("\(type(of: self)) > \(#function) > Removing peer \(peer.displayName)")
//                self.peersToJoin.remove(at: index)
//                timer.invalidate()
//            }
//        })
//    }
    
    // MARK: Streams
    
    // A function which initializes a peers input stream
    func setInputStream(for peer: MCPeerID, stream: InputStream) -> Int {
        if let index = peers.index(of: peer) {
            print("\(type(of: self)) > \(#function) > for peer \(peer.displayName)")
            
            inputStreams[index] = stream
            inputStreamIsSet[index] = true
            
            return index
        }
        
        print("\(type(of: self)) > \(#function) > Could not find peer \(peer.displayName)")
        return -1
    }
    
    // A function which initializes a peers output stream
    func setOutputStream(for peer: MCPeerID, stream: OutputStream) {
        if let index = peers.index(of: peer) {
            print("\(type(of: self)) > \(#function) > for peer \(peer.displayName)")
            
            outputStreams[index] = stream
            outputStreamIsSet[index] = true
        }
        else {
            print("\(type(of: self)) > \(#function) > Could not find peer \(peer.displayName)")
        }
    }
    
    
    // A function which sets a peers input stream to true
    func isInputStreamSet(for peer: MCPeerID) -> Bool {
        if let index = peers.index(of: peer) {
            print("\(type(of: self)) > \(#function) > for peer \(peer.displayName)")
            
            return inputStreamIsSet[index]
        }
        else {
            print("\(type(of: self)) > \(#function) > Could not find peer \(peer.displayName)")
            return false
        }
    }

    
    // A function which checks if any users streams are set
    func areAnyStreamsSet() -> Bool {
        for i in 0..<peers.count {
            if (outputStreamIsSet[i] == true && inputStreamIsSet[i] == true) {
                return true
            }
        }
        
        return false
    }
    
    // Closes all open streams
    func closeAllStreams() {
        
        for i in 0..<peers.count {
            inputStreams[i].close()
            inputStreamIsSet[i] = false
            
            outputStreams[i].close()
            outputStreamIsSet[i] = false
        }
        
        print("\(type(of: self)) > \(#function) > Streams closed")
    }
    
    func closeStreamsForPeer(peer: MCPeerID) {
        if let index = peers.index(of: peer) {
            inputStreams[index].close()
            outputStreams[index].close()
            inputStreamIsSet[index] = false
            outputStreamIsSet[index] = false
        }
    }
    
    // MARK: Labels
    
    // Creates a label with every peer's display name
    func getPeerLabel() -> String {
        var peerLabel = ""
        
        for i in 0..<peers.count {
            if (i != 0) {
                peerLabel.append(", ")
            }
            peerLabel.append(peers[i].displayName)
        }
        
        return peerLabel
    }
    
}
