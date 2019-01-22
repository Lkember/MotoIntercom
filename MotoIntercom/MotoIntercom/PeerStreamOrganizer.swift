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
    var inputStreams = [InputStream?]()         //inputStreams for the current peers
    var outputStreams = [OutputStream?]()       //outputStreams for the current peers
    var inputStreamIsSet = [Bool]()             //a boolean value for if the inputStreams have been initialized
    var outputStreamIsSet = [Bool]()            //a boolean value for if the outputStreams have been initialized
    var audioFormatForPeer = [AVAudioFormat]()  //the audio format for a given peer
    var isFormatSetForPeer = [Bool]()           //Tells whether the audioFormat is set or not
    var audioPlayers = [AVAudioPlayerNode]()    //Stores the audio player for a given peer
    var isAudioPlayerAttached = [Bool]()        //Tells whether the audioPlayer is attached to the audioEngine or not
    var didReceiveCall = [Bool]()               //a boolean value for whether the call was received or not
    
    var sessionIndex: Int?
    
    // MARK: - Peers
    
    // A function which adds a new peer
    func addNewPeer(peer: MCPeerID, didReceiveCall: Bool) {
        print("\(type(of: self)) > \(#function) > \(peer)")
        
        if (!peers.contains(peer)) {
            peers.append(peer)
            inputStreams.append(nil)
            outputStreams.append(nil)
            inputStreamIsSet.append(false)
            outputStreamIsSet.append(false)
            audioFormatForPeer.append(AVAudioFormat.init())
            isFormatSetForPeer.append(false)
            audioPlayers.append(AVAudioPlayerNode.init())
            isAudioPlayerAttached.append(false)
            self.didReceiveCall.append(didReceiveCall)
            print("\(type(of: self)) > \(#function) > peer added: \(peer.displayName)")
        }
        else {
            print("\(type(of: self)) > \(#function) > PEER ALREADY EXISTS!!")
        }
    }
    
    // Returns the index for a peer
    func indexFor(peer: MCPeerID) -> Int {
        print("\(type(of: self)) > \(#function) > Entry")
        if let index = peers.index(of: peer) {
            print("\(type(of: self)) > \(#function) > Return \(index)")
            return index
        }
        print("\(type(of: self)) > \(#function) > Exit > Peer not found")
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
    
    
    // MARK: - Audio
    func updateAudioFormatForPeer(peer: MCPeerID, format: AVAudioFormat) {
        print("\(type(of: self)) > \(#function) > Entry: Peer = \(peer.displayName)")
        if let index = peers.index(of: peer) {
            audioFormatForPeer[index] = format
            isFormatSetForPeer[index] = true
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    
    func formatForPeer(peer: MCPeerID) -> AVAudioFormat? {
        print("\(type(of: self)) > \(#function) > Entry: Peer = \(peer.displayName)")
        if let index = peers.index(of: peer) {
            return audioFormatForPeer[index]
        }
        
        return nil
    }
    
    // Stops all audio players from playing
    func stopAllAudioPlayers() {
        print("\(type(of: self)) > \(#function)")
        for audioPlayer in audioPlayers {
            if audioPlayer.isPlaying {
                audioPlayer.stop()
            }
        }
    }
    
    // MARK: - Stream Setters
    
    // A function which initializes a peers input stream
    func setInputStream(for peer: MCPeerID, stream: InputStream) -> Int {
        print("\(type(of: self)) > \(#function) > Entry: Peer = \(peer.displayName)")
        if let index = peers.index(of: peer) {
            
            inputStreams[index] = stream
            inputStreamIsSet[index] = true
            
            print("\(type(of: self)) > \(#function) > Exit - Success")
            return index
        }
        
        print("\(type(of: self)) > \(#function) > Exit: Could not find peer \(peer.displayName)")
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
    
    // MARK: - Stream Getters
    
    // A function which gets whether an input stream is set
    func isInputStreamSet(for peer: MCPeerID) -> Bool {
        if let index = peers.index(of: peer) {
            print("\(type(of: self)) > \(#function) > for peer \(peer.displayName) > \(inputStreamIsSet[index])")
            
            return inputStreamIsSet[index]
        }
        else {
            print("\(type(of: self)) > \(#function) > Could not find peer \(peer.displayName)")
            return false
        }
    }

    // A function which gets whether an output stream is set
    func isOutputStreamSet(for peer: MCPeerID) -> Bool {
        if let index = peers.index(of: peer) {
            print("\(type(of: self)) > \(#function) > for peer \(peer.displayName) > \(outputStreamIsSet[index])")
            
            return outputStreamIsSet[index]
        }
        else {
            print("\(type(of: self)) > \(#function) > Could not find peer \(peer.displayName)")
            return false
        }
    }
    
    
    // A function which checks if any streams are set
    func areAnyStreamsSet() -> Bool {
        for i in 0..<peers.count {
            if (outputStreamIsSet[i] == true && inputStreamIsSet[i] == true) {
                return true
            }
        }
        
        return false
    }
    
    func findIndexForStream(stream: InputStream) -> Int {
        for i in 0..<inputStreams.count {
            if inputStreams[i] != nil && inputStreams[i] == stream {
                return i
            }
        }
        
        return -1
    }
    
    // MARK: - Stream Closers
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
        print("\(type(of: self)) > \(#function) > Entry")
        if let index = peers.index(of: peer) {
            inputStreams[index]?.close()
            outputStreams[index]?.close()
            inputStreamIsSet[index] = false
            outputStreamIsSet[index] = false
        }
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    // MARK: Labels
    
    // Creates a label with every peer's display name
    func getPeerLabel() -> String {
        print("\(type(of: self)) > \(#function) > Entry")
        var peerLabel = ""
        
        for i in 0..<peers.count {
            if (i != 0) {
                peerLabel.append(", ")
            }
            peerLabel.append(peers[i].displayName)
        }
        print("\(type(of: self)) > \(#function) > Exit \(peerLabel)")
        return peerLabel
    }
    
}
