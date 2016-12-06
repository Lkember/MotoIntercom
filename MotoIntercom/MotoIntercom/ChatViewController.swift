//
//  ChatViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-11.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ChatViewController : UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var messagesArray : [Dictionary<String, String>] = []
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    // MARK: Properties
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var senderInfo: UILabel!
    
    // MARK: Actions
    
    override func viewDidLoad() {
        print("ChatView > viewDidLoad > Entry")
        super.viewDidLoad()
        
        print("ChatView > viewDidLoad > Setting Delegates")
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = UITableViewAutomaticDimension
        
        messageField.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMPCReceivedDataWithNotification(_:)), name: NSNotification.Name(rawValue: "receivedMPCDataNotification"), object: nil)
        
        print("ChatView > viewDidLoad > Exit")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("ChatView > textFieldShouldReturn > Entry")
        messageField.resignFirstResponder()
        
        let messageDictionary: [String: String] = ["message": messageField.text!]
        
        if appDelegate.connectionManager.sendData(dictionaryWithData: messageDictionary, toPeer: appDelegate.connectionManager.session.connectedPeers[0] as MCPeerID) {
            let dictionary: [String: String] = ["sender": "self", "message": messageField.text!]
            
            messagesArray.append(dictionary)
            
            self.updateTableView()
            print("ChatView > textFieldShouldReturn > New messagesArray size = \(messagesArray.count)")
        }
        else {
            print("ChatView > textFieldShouldReturn > Could not send data.")
        }
        
        messageField.text = ""
        
        print("ChatView > textFieldShouldReturn > Exit")
        
        return true
    }
    
    //Displaying messages
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("ChatView > tableView > cellForRowAt > Entry")
        let cell = tableView.dequeueReusableCell(withIdentifier: "chatViewCell")! as UITableViewCell
        
        let currentMessage = messagesArray[indexPath.row] as Dictionary<String, String>
        if let sender = currentMessage["sender"] {
            print("HEREHEREHEREHEREHERE")
            var senderLabelText: String
            var senderColor : UIColor
            
            if sender == "self" {
                senderLabelText = "I said:"
                senderColor = UIColor.purple
            }
            else {
                senderLabelText = sender + " said:"
                senderColor = UIColor.orange
            }
            cell.textLabel?.text = senderLabelText
//            cell.textLabel?.textColor = senderColor
            
//            cell.detailTextLabel?.text = senderLabelText
//            cell.detailTextLabel?.textColor = senderColor
        }
        
        if let message = currentMessage["message"] {
            print("ChatView > tableView > cellForRowAt the message is: \(message)")
            cell.detailTextLabel?.text = message
        }
        else {
            print("ChatView > tableView > cellForRowAt problem getting message...")
        }
        
        return cell
    }
    
    //Getting the number of rows in the table there should be
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("ChatView > tableView > numberOfRowsInSection > Entry")
        return messagesArray.count
    }
    
    func updateTableView() {
        print("ChatView > updateTableView > updating table...")
        self.tableView.reloadData()
        
        if self.tableView.contentSize.height > self.tableView.frame.size.height {
            tableView.scrollToRow(at: IndexPath(row: messagesArray.count - 1, section: 0), at: UITableViewScrollPosition.bottom, animated: true)
        }
    }
    
    func handleMPCReceivedDataWithNotification(_ notification: Notification) {
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        let data = receivedDataDictionary["data"] as? Data
        let fromPeer = receivedDataDictionary["fromPeer"] as! MCPeerID
        
        let dataDictionary = NSKeyedUnarchiver.unarchiveObject(with: data!) as! Dictionary<String, String>
        
        if let message = dataDictionary["message"] {
            if message != "_end_chat_" {
                let messageDictionary: [String: String] = ["sender": fromPeer.displayName, "message": message]
                messagesArray.append(messageDictionary)
                
                OperationQueue.main.addOperation({ () -> Void in
                    self.updateTableView()
                })
            }
                
            else {
                let alert = UIAlertController(title: "", message: "\(fromPeer.displayName) ended this chat", preferredStyle: UIAlertControllerStyle.alert)
                
                let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.default) { (alertAction) -> Void in
                    self.appDelegate.connectionManager.session.disconnect()
                    self.dismiss(animated: true, completion: nil)
                }
                
                alert.addAction(doneAction)
                
                OperationQueue.main.addOperation({ () -> Void in
                    self.present(alert, animated: true, completion: nil)
                })
            }
        }
    }
}
