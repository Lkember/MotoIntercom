//
//  MessageObject.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-12-08.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class MessageObject: NSObject, NSCoding {
    
    // MARK: Properties
    var peerID: MCPeerID!
    var selfID: MCPeerID!
    var messageIsFrom = [Int]()     // 0 means from user, 1 means from peer
    var messages = [String]()       // An array of strings, where each string is a message.
    var isAvailable : Bool = false
    
    var connectionType : Int = 0    // 0= not specified, 1 = message, 2 = voice
    
    
    // MARK: init
    override init() {
        print("MessageObject > init > new message object is being created with display name \(UIDevice.current.name).")
        peerID = MCPeerID.init(displayName: UIDevice.current.name)
        selfID = MCPeerID.init(displayName: UIDevice.current.name)
        messageIsFrom = [Int]()
        messages = [String]()
    }
    
    init(peerID: MCPeerID, messageFrom: [Int], messages: [String]) {
        print("MessageObject > init > Correctly initializing message object for peer \(peerID.displayName)")
        self.peerID = peerID
        self.selfID = MCPeerID.init(displayName: UIDevice.current.name)
        self.messageIsFrom = messageFrom
        self.messages = messages
    }
    
    init(peerID: MCPeerID, selfID: MCPeerID, messageFrom: [Int], messages: [String]) {
        print("MessageObject > init > Initializing message object as received.")
        self.peerID = peerID
        self.selfID = selfID
        self.messageIsFrom = messageFrom
        self.messages = messages
    }
    
    // MARK: Functions
    func resetConnectionType() {
        print("MessageObject > resetConnectionType > forPeer \(self.peerID.displayName)")
        connectionType = 0
    }
    
    func setConnectionTypeToMessage() {
        print("MessageObject > setConnectionTypeToMessage > forPeer \(self.peerID.displayName)")
        connectionType = 1
    }
    
    func setConnectionTypeToVoice() {
        print("MessageObject > setConnectionTypeToVoice > forPeer \(self.peerID.displayName)")
        connectionType = 2
    }
    
    func getConnectionType() -> Int {
        print("MessageObject > getConnectionType > RETURN \(connectionType) forPeer \(self.peerID.displayName)")
        return connectionType
    }
    
    // MARK: NSCoding
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("MessageObjects")
    
    struct PropertyKey {
        static let peerID = "peerID"
        static let selfID = "selfID"
        static let messageIsFrom = "messageIsFrom"
        static let messages = "messages"
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(peerID, forKey: PropertyKey.peerID)
        aCoder.encode(selfID, forKey: PropertyKey.selfID)
        aCoder.encode(messageIsFrom, forKey: PropertyKey.messageIsFrom)
        aCoder.encode(messages, forKey: PropertyKey.messages)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let peerID = aDecoder.decodeObject(forKey: PropertyKey.peerID) as! MCPeerID
        let selfID = aDecoder.decodeObject(forKey: PropertyKey.selfID) as! MCPeerID
        let messageIsFrom = aDecoder.decodeObject(forKey: PropertyKey.messageIsFrom) as! [Int]
        let messages = aDecoder.decodeObject(forKey: PropertyKey.messages) as! [String]
        
        self.init(peerID: peerID, selfID: selfID, messageFrom: messageIsFrom, messages: messages)
    }
}
