//
//  MessageObject.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-12-08.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import JSQMessagesViewController

class MessageObject: NSObject, NSCoding {
    
    // MARK: Properties
    var senderID: String!
    var peerID: MCPeerID!
    var selfID: MCPeerID!
    var messages = [JSQMessage]()
    var isAvailable : Bool = false
    
    var connectionType : Int = 0    // 0 = not specified, 1 = message, 2 = voice
    
    
    // MARK: init
    override init() {
        print("\(#file) > \(#function) > new message object is being created with display name \(UIDevice.current.name).")
        peerID = MCPeerID.init(displayName: UIDevice.current.name)
        selfID = MCPeerID.init(displayName: UIDevice.current.name)
        messages = [JSQMessage]()
    }
    
    init(peerID: MCPeerID, messages: [JSQMessage]) {
        print("\(#file) > \(#function) > Correctly initializing message object for peer \(peerID.displayName)")
        self.peerID = peerID
        self.selfID = MCPeerID.init(displayName: UIDevice.current.name)
        self.messages = messages
    }
    
    init(peerID: MCPeerID, selfID: MCPeerID, messages: [JSQMessage]) {
        print("\(#file) > \(#function) > Initializing message object as received.")
        self.peerID = peerID
        self.selfID = selfID
        self.messages = messages
    }
    
    // MARK: Functions
    func resetConnectionType() {
        print("\(#file) > \(#function) > forPeer \(self.peerID.displayName)")
        connectionType = 0
    }
    
    func setConnectionTypeToMessage() {
        print("\(#file) > \(#function) > forPeer \(self.peerID.displayName)")
        connectionType = 1
    }
    
    func setConnectionTypeToVoice() {
        print("\(#file) > \(#function) > forPeer \(self.peerID.displayName)")
        connectionType = 2
    }
    
//    // MARK: - JSQMessageData
//    func senderId() -> String! {
//        return self.senderID
//    }
//    
//    func senderDisplayName() -> String! {
//        return self.selfID.displayName
//    }
//    
//    func date() -> Date! {
//        let date = Date.init()
//        return date
//    }
//    
//    func isMediaMessage() -> Bool {
//        return false
//    }
//    
//    public func messageHash() -> UInt {
//        return UInt(RAND_MAX)
//    }
//    
//    public func text() -> String! {
//        return messages[0]
//    }
    
    
    // MARK: - NSCoding
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
//        aCoder.encode(messageIsFrom, forKey: PropertyKey.messageIsFrom)
        aCoder.encode(messages, forKey: PropertyKey.messages)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let peerID = aDecoder.decodeObject(forKey: PropertyKey.peerID) as! MCPeerID
        let selfID = aDecoder.decodeObject(forKey: PropertyKey.selfID) as! MCPeerID
//        let messageIsFrom = aDecoder.decodeObject(forKey: PropertyKey.messageIsFrom) as! [Int]
        let messages = aDecoder.decodeObject(forKey: PropertyKey.messages) as! [JSQMessage]
        
        self.init(peerID: peerID, selfID: selfID, messages: messages)
    }
}
