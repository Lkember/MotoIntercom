//
//  AddPeerViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-05-26.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

@available(iOS 10.0, *)
class AddPeerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ConnectionManagerDelegate {

    // MARK: - Properties
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var peerViewTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addPeerButtonIsTouched(_ sender: UIButton) {
        
    }
    
    @IBAction func cancelButtonIsTouched(_ sender: UIButton) {
        
    }
    
    
    // MARK: - TableViewDelegate Methods
    
    // We only ever want 1 section, the users available
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // TODO: Need to return the number of available
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // TODO: Need to return a cell
        return UITableViewCell.init()
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // TODO: Need to show that the row is selected
    }
    
    
    // MARK: - Connection Manager Delegate
    func foundPeer(_ newPeer: MCPeerID) {
        // TODO: need to add peer
    }
    
    func lostPeer(_ lostPeer: MCPeerID) {
        // TODO: need to remove peer
    }
    
    func inviteWasReceived(_ fromPeer : MCPeerID, isPhoneCall: Bool) {
        // TODO: Decide what to do
    }
    
    func connectedWithPeer(_ peerID : MCPeerID) {
        // Nothing to do
    }
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        // TODO: Decide waht to do
    }
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        // Nothing to do
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        // Nothing to do
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}