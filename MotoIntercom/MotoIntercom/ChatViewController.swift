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
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    // MARK: Properties
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var messageValue: UILabel!
    @IBOutlet weak var senderInfo: UILabel!
    
    // MARK: Actions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.estimatedRowHeight = 60.0
        tableView.rowHeight = UITableViewAutomaticDimension
        
        messageField.delegate = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("handleMPCReceiveDataWithNotification:"), name: "receivedMPCDataNotification", object: nil)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        let messageDictionary: [String: String] = ["message": textField.text!]
        
        if appDelegate.connectionManager.sendData(dictionaryWithData: messageDictionary, toPeer: appDelegate.connectionManager.session.connectedPeers[0] as MCPeerID) {
            let dictionary: [String: String] = ["sender": "self", "message": textField.text!]
            messagesArray.append(dictionary)
            
            self.updateTableView()
        }
        else {
            NSLog("&@", "Could not send data.")
        }
        
        textField.text = ""
        return true
    }
    
    //Displaying messages
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("idCell")! as UITableViewCell
        
        let currentMessage = messagesArray[indexPath.row] as Dictionary<String, String>
        if let sender = currentMessage["Sender"] {
            var senderLabelText: String
            var senderColor : UIColor
            
            if sender == "self" {
                senderLabelText = "I said:"
                senderColor = UIColor.purpleColor()
            }
            else {
                senderLabelText = sender + " said:"
                senderColor = UIColor.orangeColor()
            }
            cell.detailTextLabel?.text = senderLabelText
            cell.detailTextLabel?.textColor = senderColor
        }
        
        if let message = currentMessage["message"] {
            cell.textLabel?.text = message
        }
        
        return cell
    }
    
    //Getting the number of rows in the table there should be
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messagesArray.count
    }
    
    func updateTableView() {
        self.tableView.reloadData()
        
        if self.tableView.contentSize.height > self.tableView.frame.size.height {
            tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: messagesArray.count - 1, inSection: 0), atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
        }
    }
    
    func handleMPCReceivedDataWithNotification(notification: NSNotification) {
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        let data = receivedDataDictionary["data"] as? NSData
        let fromPeer = receivedDataDictionary["fromPeer"] as! MCPeerID
        
        let dataDictionary = NSKeyedUnarchiver.unarchiveObjectWithData(data!) as! Dictionary<String, String>
        
        if let message = dataDictionary["message"] {
            if message != "_end_chat_" {
                let messageDictionary: [String: String] = ["sender": fromPeer.displayName, "message": message]
                messagesArray.append(messageDictionary)
                
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    self.updateTableView()
                })
            }
                
            else {
                let alert = UIAlertController(title: "", message: "\(fromPeer.displayName) ended this chat", preferredStyle: UIAlertControllerStyle.Alert)
                
                let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
                    self.appDelegate.connectionManager.session.disconnect()
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
                
                alert.addAction(doneAction)
                
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    self.presentViewController(alert, animated: true, completion: nil)
                })
            }
        }
    }
}