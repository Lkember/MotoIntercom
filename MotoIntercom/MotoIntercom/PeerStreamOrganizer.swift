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
    
    var peers = [MCPeerID]()                    //peers in the current phone call
    var inputStreams = [InputStream?]()          //inputStreams for the current peers
    var outputStreams = [OutputStream?]()        //outputStreams for the current peers
    var inputStreamIsSet = [Bool]()             //a boolean value for if the inputStreams have been initialized
    var outputStreamIsSet = [Bool]()            //a boolean value for if the outputStreams have been initialized
    var audioFormatForPeer = [AVAudioFormat]()  //the audio format for a given peer
    var didReceiveCall = [Bool]()               //a boolean value for whether the call was received or not
    
    var sessionIndex: Int?
    
    // MARK: - Peers
    
    // A function which adds a new peer
    func addNewPeer(peer: MCPeerID, didReceiveCall: Bool) {
        
        if (!peers.contains(peer)) {
            
            print("\(type(of: self)) > \(#function) > adding peer \(peer.displayName)")
            peers.append(peer)
            inputStreams.append(nil)
            outputStreams.append(nil)
            inputStreamIsSet.append(false)
            outputStreamIsSet.append(false)
            audioFormatForPeer.append(AVAudioFormat.init())
            self.didReceiveCall.append(didReceiveCall)
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
    
    
    // MARK: AudioFormat
    func updateAudioFormatForPeer(peer: MCPeerID, format: AVAudioFormat) {
        if let index = peers.index(of: peer) {
            audioFormatForPeer[index] = format
        }
    }
    
    
    func formatForPeer(peer: MCPeerID) -> AVAudioFormat? {
        if let index = peers.index(of: peer) {
            return audioFormatForPeer[index]
        }
        return nil
    }
    
    // MARK: Stream Setters
    
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
    
    // MARK: Stream Getters
    
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

    func isOutputStreamSet(for peer: MCPeerID) -> Bool {
        if let index = peers.index(of: peer) {
            print("\(type(of: self)) > \(#function) > for peer \(peer.displayName)")
            
            return outputStreamIsSet[index]
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
    
    func findIndexForStream(stream: InputStream) -> Int {
        print("\(type(of: self)) > \(#function) > Entry")
        
        for i in 0..<inputStreams.count {
            if inputStreams[i] != nil && inputStreams[i] == stream {
                print("\(type(of: self)) > \(#function) > Exit \(i)")
                return i
            }
        }
        
        print("\(type(of: self)) > \(#function) > Exit -1")
        return -1
    }
    
    // MARK: Stream Closers
    
    // Closes all open streams
    func closeAllStreams() {
        
        for i in 0..<peers.count {
            inputStreams[i]?.close()
            inputStreamIsSet[i] = false
            
            outputStreams[i]?.close()
            outputStreamIsSet[i] = false
        }
        
        print("\(type(of: self)) > \(#function) > Streams closed")
    }
    
    // Closes all open streams for one peer
    func closeStreamsForPeer(peer: MCPeerID) {
        if let index = peers.index(of: peer) {
            inputStreams[index]?.close()
            outputStreams[index]?.close()
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
