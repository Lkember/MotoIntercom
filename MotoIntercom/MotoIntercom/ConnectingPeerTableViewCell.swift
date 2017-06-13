//
//  ConnectingPeerTableViewCell.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-06-13.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ConnectingPeerTableViewCell: UITableViewCell {

    @IBOutlet weak var peerDisplayName: UILabel!
    @IBOutlet weak var latestMessage: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var peerID: MCPeerID?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        activityIndicator.startAnimating()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setPeerDisplayName(displayName: String) {
        peerDisplayName?.text = displayName
    }
    
    func setLatestMessage(latestMessage: String) {
        self.latestMessage?.text = latestMessage
    }
    
}
