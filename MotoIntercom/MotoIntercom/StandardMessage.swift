//
//  StandardMessage.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-05-10.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class StandardMessage: NSObject, NSCoding {
    var message: String = ""
    var peerID: MCPeerID?
    
    override init() {
        message = ""
    }
    
    init(message: String, peerID: MCPeerID) {
        self.message = message
        self.peerID = peerID
    }

    
    // MARK: - NSCoding
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("StandardMessage")
    
    struct PropertyKey {
        static let message = "message"
        static let peerID = "peerID"
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(message, forKey: PropertyKey.message)
        aCoder.encode(peerID, forKey: PropertyKey.peerID)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let message = aDecoder.decodeObject(forKey: PropertyKey.message) as! String
        let peerID = aDecoder.decodeObject(forKey: PropertyKey.peerID) as! MCPeerID
        
        self.init(message: message, peerID: peerID)
    }

    
}
