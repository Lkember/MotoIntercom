//
//  ChatViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-11.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import AudioToolbox

class ChatViewController : UIViewController, UITextViewDelegate, UITableViewDelegate, UITableViewDataSource, ConnectionManagerDelegate {
    
    var messages: MessageObject!
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    // MARK: Properties
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var senderInfo: UILabel!
    @IBOutlet weak var messageView: UIView!
    @IBOutlet weak var messageField: UITextView!
    
    var keyboard = 0
    
    let endChat = "_end_chat_"
    
    // MARK: Views
    
    override func viewDidLoad() {
        print("ChatView > viewDidLoad > Entry")
        super.viewDidLoad()
        
        print("ChatView > viewDidLoad > Stopped browsing for peers")
        appDelegate.connectionManager.browser.stopBrowsingForPeers()
        
        tableView.delegate = self
        tableView.dataSource = self
        messageField.delegate = self
        
        messageField.layer.cornerRadius = 10
        messageField.layer.borderColor = UIColor.gray.cgColor
        messageField.layer.borderWidth = 1
        
        print("ChatView > viewDidLoad > current peerID = \(messages.peerID)")
        
        if (!messages.isAvailable) {
            messageField.isSelectable = false
            messageField.isEditable = false
            sendButton.isEnabled = false
        }
        
        // Setting the rowheight to be dynamic
        tableView.rowHeight = UITableViewAutomaticDimension
        
        //Adding an observer for when data is received
        NotificationCenter.default.addObserver(self, selector: #selector(handleMPCReceivedDataWithNotification(_:)), name: NSNotification.Name(rawValue: "receivedMPCDataNotification"), object: nil)
        
        //Adding observers for when the keyboard is toggled
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardToggle(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardToggle(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        print("ChatView > viewDidLoad > Exit")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("ChatView > viewWillDisappear > Starting to browse for peers")
        appDelegate.connectionManager.browser.startBrowsingForPeers()
    }
    
    
    // When the send button is clicked send the message
    // TODO: When a message fails to send, we should notify the user somehow.
    @IBAction func sendButtonIsClicked(_ sender: UIButton) {
        print("ChatView > sendButtonIsClicked > Entry: Current Peer \(messages.peerID)")
        
        if (messageField.text! != "") {
            
            let currentMessage = MessageObject.init(peerID: messages.peerID!, messageFrom: [1], messages: [messageField.text!])
            
            if appDelegate.connectionManager.sendData(message: currentMessage, toPeer: self.messages.peerID!) {
                
                // Add both who the message is from and the actual message to the current transcript
                
                messages.messageIsFrom.append(0)
                messages.messages.append(messageField.text!)
                
                self.updateTableView()
                print("ChatView > sendButtonIsClicked > new message size = \(self.messages.messages.count)")
                
                messageField.text = ""
            }
            else {
                print("ChatView > sendButtonIsClicked > ERROR: Could not send data")
                let alert = UIAlertController(title: "Connection Lost", message: "There was an error sending your message.", preferredStyle: UIAlertControllerStyle.alert)
                
                let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (alertAction) -> Void in
                    // Do nothing
                }
                
                alert.addAction(okAction)
                
                OperationQueue.main.addOperation { () -> Void in
                    self.present(alert, animated: true, completion: nil)
                }
            }
//            let messageDictionary: [String: String] = ["sender": "self", "message": messageField.text!]
//            
//            if appDelegate.connectionManager.sendData(dictionaryWithData: messageDictionary, toPeer: appDelegate.connectionManager.session.connectedPeers[0] as MCPeerID) {
//                let dictionary: [String: String] = ["sender": "self", "message": messageField.text!]
//                
//                messagesArray.append(dictionary)
//                
//                self.updateTableView()
//                print("ChatView > sendButtonIsClicked > New messagesArray size = \(messagesArray.count)")
//                messageField.text = ""
//            }
//            else {
//                print("ChatView > sendButtonIsClicked > Could not send data.")
//            }
        }
        print("ChatView > sendButtonIsClicked > Exit")
    }
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        messageField.text?.append("\n")
        
        return false
    }
    
    //Displaying messages
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("ChatView > tableView > cellForRowAt > Entry")
        let cell = tableView.dequeueReusableCell(withIdentifier: "chatViewCell")! as UITableViewCell
        
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        
//        let currentMessage = messagesArray[indexPath.row] as Dictionary<String, String>
        
        
//        if let sender = currentMessage["sender"] {
            var senderLabelText: String
            var senderColor : UIColor
//
//            if sender == "self" {
//                senderLabelText = "I said:"
//                senderColor = UIColor.purple
//            }
//            else {
//                senderLabelText = sender + " said:"
//                senderColor = UIColor.orange
//            }
//            cell.textLabel?.text = senderLabelText
//            cell.textLabel?.textColor = senderColor
//        }
        
        if messages.messageIsFrom[indexPath.row] == 0 {
            senderLabelText = "I said:"
            senderColor = UIColor.purple
        }
        else {
            senderLabelText = (messages.peerID?.displayName)! + " said:"
            senderColor = UIColor.orange
        }
        
        cell.textLabel?.text = senderLabelText
        cell.textLabel?.textColor = senderColor
        
        print("ChatView > tableView > cellForRowAt the message is: \(messages.messages[indexPath.row])")
        cell.detailTextLabel?.text = messages.messages[indexPath.row]
        
        if (self.tableView.contentSize.height > self.tableView.frame.size.height && indexPath.row == messages.messages.count-1) {
            print("ChatView > tableView > auto scrolling...")
            tableView.scrollToRow(at: IndexPath(row: messages.messages.count - 1, section: 0), at: UITableViewScrollPosition.bottom, animated: true)
        }
        
        return cell
    }
    
    //Getting the number of rows in the table there should be
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("ChatView > tableView > numberOfRowsInSection > returning \(messages.messages.count)")
        return messages.messages.count
//        return messagesArray.count
    }
    
    func updateTableView() {
        print("ChatView > updateTableView > updating table...")
        self.tableView.reloadData()
        
        if self.tableView.contentSize.height > self.tableView.frame.size.height {
            tableView.scrollToRow(at: IndexPath(row: messages.messages.count - 1, section: 0), at: UITableViewScrollPosition.bottom, animated: true)
        }
    }
    
    func handleMPCReceivedDataWithNotification(_ notification: Notification) {
        print("ChatView > handleMPCReceivedDataWithNotification > Message received \(messages.messages.count).")
        
//        tableView.insertRows(at: [IndexPath.init(row: messages.messages.count-1, section: 0)], with: .fade)
//        tableView.reloadData()
        
        let dictionary = NSKeyedUnarchiver.unarchiveObject(with: notification.object as! Data) as! [String: Any]
        
//        let newMessage = NSKeyedUnarchiver.unarchiveObject(with: notification.object as! Data) as! MessageObject
        let newMessage = NSKeyedUnarchiver.unarchiveObject(with: dictionary["data"] as! Data) as! MessageObject
//        let fromPeer = dictionary["peer"] as! MCPeerID
        
        let fromPeer = newMessage.peerID
        
        //Vibrate
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        
        if newMessage.messages[0] != endChat {
            self.messages.messages.append(newMessage.messages[0])
            self.messages.messageIsFrom.append(newMessage.messageIsFrom[0])
            
            OperationQueue.main.addOperation {
                self.updateTableView()
            }
        }
        else {
            let alert = UIAlertController(title: "", message: "\(fromPeer?.displayName) ended this chat", preferredStyle: UIAlertControllerStyle.alert)
            
            let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.default) { (alertAction) -> Void in
                
                var sess : MCSession?
                
                for session in self.appDelegate.connectionManager.sessions {
                    if session.connectedPeers.contains(fromPeer!) {
                        sess = session
                        break
                    }
                }
                
                sess!.disconnect()
                
                self.dismiss(animated: true, completion: nil)
            }

            alert.addAction(doneAction)

            OperationQueue.main.addOperation {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    

    func keyboardToggle(_ notification: Notification) {
        print("ChatView > keyboardToggle > keyboard = \(keyboard), notification = \(notification.name)")
        let userInfo = (notification as NSNotification).userInfo!
        
        let keyboardScreenEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: tableView)
//        let navHeight = self.navigationController!.navigationBar.frame.height
        
        if notification.name == NSNotification.Name.UIKeyboardWillHide {
            if (keyboard != 0) {
                tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                messageView.frame.origin.y += keyboardViewEndFrame.height
    //            scrollView.contentInset = UIEdgeInsets(top: navHeight + 20, left: 0, bottom: 0, right: 0)
                print("ChatView > keyboardToggle > Keyboard is hidden.")
                keyboard -= 1
            }
        } else if notification.name == NSNotification.Name.UIKeyboardWillShow {
            if (keyboard != 1) {
    //            scrollView.contentInset = UIEdgeInsets(top: navHeight + 20, left: 0, bottom: keyboardViewEndFrame.height, right: 0)
                tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height, right: 0)
                messageView.frame.origin.y -= keyboardViewEndFrame.height
                print("ChatView > keyboardToggle > Keyboard is showing.")
                keyboard += 1
            }
        }
    }
    
    
    // MARK: TextViewDelegate
    func textViewDidChange(_ textView: UITextView) {
//        let textViewFixedWidth: CGFloat = self.messageField.frame.size.width
//        let newSize: CGSize = self.messageField.sizeThatFits(CGSize(width: textViewFixedWidth, height: CGFloat(MAXFLOAT)))
//        var newFrame: CGRect = self.messageField.frame
//        
//        var textViewYPosition = self.messageField.frame.origin.y
//        var heightDifference = self.messageField.frame.height - newSize.height
//        
//        if (abs(heightDifference) > 20) {
//            newFrame.size = CGSize(width: fmax(newSize.width, textViewFixedWidth), height: newSize.height)
//            newFrame.offsetBy(dx: 0.0, dy: 0)
//        }
//        self.messageField.frame = newFrame
    }
    
    
    //MARK: Connection Manager
    func foundPeer(_ newPeer: MCPeerID) {
        print("ChatView > foundPeer > Peer was found.")
    }
    
    // TODO: Check if the peer lost was the current peer, if so go back to peer view
    func lostPeer(_ lostPeer: MCPeerID) {
        print("ChatView > lostPeer > Peer was lost.")
    }
    
    func connectedWithPeer(_ peerID: MCPeerID) {
        print("ChatView > connectedWithPeer > connected to new peer \(peerID)")
    }
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("ChatView > disconnectedFromPeeer > disconnected from peer \(peerID)")
        
        if (peerID == messages.peerID) {
            let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(messages.peerID.displayName)", preferredStyle: UIAlertControllerStyle.alert)
            
            let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (alertAction) -> Void in
                
                //Go back to PeerView
                _ = self.navigationController?.popViewController(animated: true)
            }
            
            alert.addAction(okAction)
            
            OperationQueue.main.addOperation { () -> Void in
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    func inviteWasReceived(_ fromPeer: MCPeerID, isPhoneCall: Bool) {
        //TODO: Need to decide what to do if invite is received.
        
    }
}

