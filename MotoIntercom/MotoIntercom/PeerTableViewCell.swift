//
//  PeerTableViewCell.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-12-11.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class PeerTableViewCell: UITableViewCell {

    // MARK: Properties
    @IBOutlet weak var peerDisplayNameLabel: UILabel?
    @IBOutlet weak var latestMessage: UILabel?
    @IBOutlet weak var isAvailableLabel: UILabel?     //🔵 is online, 🔴 is offline
    var peerID: MCPeerID?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        peerDisplayNameLabel?.text = ""
        isAvailableLabel?.text = ""
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    // MARK: Functions
    func peerIsAvailable() {
        isAvailableLabel?.text = ""
    }
    
    func removeNewMessageIcon() {
        isAvailableLabel?.text = ""
    }
    
    func newMessageArrived() {
        isAvailableLabel?.text = "🔵"
    }
    
    func peerIsUnavailable() {
        isAvailableLabel?.text = "🔴"
    }
    
    func setPeerDisplayName(displayName: String) {
        peerDisplayNameLabel?.text = displayName
    }
    
    func setLatestMessage(latestMessage: String) {
        self.latestMessage?.text = latestMessage
    }
}
