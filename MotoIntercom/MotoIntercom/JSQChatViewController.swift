//
//  JSQChatViewController.swift
//  
//
//  Created by Logan Kember on 2017-04-06.
//
//

import UIKit
import MultipeerConnectivity
import AudioToolbox
import JSQMessagesViewController

class JSQChatViewController: JSQMessagesViewController, ConnectionManagerDelegate {

    // MARK: Properties
    var messageObject = MessageObject()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.senderId = appDelegate.connectionManager.uniqueID
        self.senderDisplayName = appDelegate.connectionManager.peer.displayName
        
        // Setting the title to the display name
        self.navigationItem.title = messageObject.peerID.displayName
        
        appDelegate.connectionManager.browser.stopBrowsingForPeers()
        
        // Removes avatars
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        // Adding an observer for when a message is received
        NotificationCenter.default.addObserver(self, selector: #selector(handleMPCReceivedDataWithNotification(_:)), name: NSNotification.Name(rawValue: "receivedMPCDataNotification"), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - JSQMessagesViewController
    
    // Gets the data for the message at index
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        print("\(#file) > \(#function) > \(messageObject.messages[indexPath.item])")
        return messageObject.messages[indexPath.item]
    }
    
    // Sets the number of messages
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("\(#file) > \(#function) > \(messageObject.messages.count)")
        return messageObject.messages.count
    }
    
    // Sets up the outgoing and incoming message bubbles
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleGreen())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    // Checks if the message is from the curr user or the peer
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        print("\(#file) > \(#function)")
        let message = messageObject.messages[indexPath.item] // 1
        if message.senderId == appDelegate.connectionManager.uniqueID { // 2
            return outgoingBubbleImageView
        } else { // 3
            return incomingBubbleImageView
        }
    }
    
    // Changes the text colour depending on who the message is from
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("\(#file) > \(#function)")
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messageObject.messages[indexPath.item]
        
        if message.senderId == senderId {
            cell.textView?.textColor = UIColor.white
        } else {
            cell.textView?.textColor = UIColor.black
        }
        return cell
    }
    
    // Removes avatars
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    // When a new message is received
    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            print("\(#file) > \(#function) > Adding message \(text)")
            messageObject.messages.append(message)
        }
    }
    
    
    // When the user sends a message
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        let jsqMessage = JSQMessage(senderId: senderId, senderDisplayName: senderDisplayName, date: date, text: text)
        let message = MessageObject.init(peerID: messageObject.peerID, messages: [jsqMessage!])
        
        if (appDelegate.connectionManager.sendData(message: message, toPeer: message.peerID)) {
            messageObject.messages.append(jsqMessage!)
            
//            self.collectionView.reloadData()
        }
        
        JSQSystemSoundPlayer.jsq_playMessageSentAlert()
        finishSendingMessage()
    }
    
    override func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        if appDelegate.connectionManager.checkIfAlreadyConnected(peerID: messageObject.peerID) {
            return false
        }
        else {
            return true
        }
    }
    
    
    //MARK: - Message Received
    
    func handleMPCReceivedDataWithNotification(_ notification: Notification) {
        print("\(#file) > \(#function) > Message received")
        
        let dictionary = NSKeyedUnarchiver.unarchiveObject(with: notification.object as! Data) as! [String: Any]
        let newMessage = NSKeyedUnarchiver.unarchiveObject(with: dictionary["data"] as! Data) as! MessageObject
        
//        let fromPeer = newMessage.peerID
        
        //Vibrate
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        
//        if newMessage.messages[0].text != endChat {
//        self.messageObject.messages.append(newMessage.messages[0])
        addMessage(withId: newMessage.messages[0].senderId, name: newMessage.messages[0].senderDisplayName, text: newMessage.messages[0].text)
            
        OperationQueue.main.addOperation {
            self.collectionView.reloadData()
        }
        
        print("\(#file) > \(#function) > Message: \(newMessage.messages[0].text)")
        
//        }
//        else {
//            let alert = UIAlertController(title: "", message: "\(fromPeer!.displayName) ended this chat", preferredStyle: UIAlertControllerStyle.alert)
//            
//            let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertActionStyle.default) { (alertAction) -> Void in
//                
//                var sess : MCSession?
//                let sessIndex = self.appDelegate.connectionManager.findSinglePeerSession(peer: fromPeer!)
//                
//                if sessIndex != -1 {
//                    sess = self.appDelegate.connectionManager.sessions[sessIndex]
//                    sess?.disconnect()
//                }
//                self.dismiss(animated: true, completion: nil)
//            }
//            
//            alert.addAction(doneAction)
//            
//            OperationQueue.main.addOperation {
//                self.present(alert, animated: true, completion: nil)
//            }
//        }
    }
    
    //MARK: - Connection Manager
    func foundPeer(_ newPeer: MCPeerID) {
        print("\(#file) > \(#function) > Peer was found.")
    }
    
    // TODO: Check if the peer lost was the current peer, if so go back to peer view
    func lostPeer(_ lostPeer: MCPeerID) {
        print("\(#file) > \(#function) > Peer was lost.")
    }
    
    func connectedWithPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > connected to new peer \(peerID)")
    }
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("\(#file) > \(#function) > disconnected from peer \(peerID)")
        
        if (peerID == messageObject.peerID) {
            let alert = UIAlertController(title: "Connection Lost", message: "You have lost connection to \(messageObject.peerID.displayName)", preferredStyle: UIAlertControllerStyle.alert)
            
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
    
    func connectingWithPeer(_ peerID: MCPeerID) {
        // Nothing to do here
    }
    
    func inviteWasReceived(_ fromPeer: MCPeerID, isPhoneCall: Bool) {
        //TODO: Need to decide what to do if invite is received.
        
    }
    
    func startedStreamWithPeer(_ peerID: MCPeerID, inputStream: InputStream) {
        // Nothing to do here
        print("\(#file) > \(#function) > Received inputStream from peer \(peerID.displayName)")
    }
    
}
