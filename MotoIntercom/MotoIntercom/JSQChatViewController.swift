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
import Photos

@available(iOS 10.0, *)
class JSQChatViewController: JSQMessagesViewController, ConnectionManagerDelegate {

    // MARK: Properties
    var messageObject = MessageObject()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var selectedImage: UIImage?
    
    var isTyping: Bool = false
    var userIsTyping: String = "_user_is_typing_"
    var userHasStoppedTyping: String = "_user_stopped_typing_"
    
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
        NotificationCenter.default.addObserver(self, selector: #selector(receivedMessageObject(_:)), name: NSNotification.Name(rawValue: "receivedMessageObjectNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedStandardMessage(_:)), name: NSNotification.Name(rawValue: "receivedStandardMessageNotification"), object: nil)
        
        print("Checking... ")
        if (!appDelegate.connectionManager.checkIfAlreadyConnected(peerID: messageObject.peerID)) {
            print("Setting to false...")
            self.inputToolbar.contentView.rightBarButtonItem.isEnabled = false
            self.inputToolbar.contentView.rightBarButtonItem.isUserInteractionEnabled = false
            
            self.inputToolbar.contentView.textView.isEditable = false
            self.inputToolbar.contentView.textView.isUserInteractionEnabled = false
            
            self.inputToolbar.contentView.leftBarButtonItem.isEnabled = false
            self.inputToolbar.contentView.leftBarButtonItem.isUserInteractionEnabled = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        if (segue.identifier == "showMedia") {
            let destVC = segue.destination as! ShowMediaViewController
            destVC.image = self.selectedImage
            
            let backItem = UIBarButtonItem()
            backItem.title = "Back"
            
            self.navigationItem.backBarButtonItem = backItem
        }
    }

    // MARK: - JSQMessagesViewController
    
    // Gets the data for the message at index
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        if messageObject.messages[indexPath.item].isMediaMessage {
            print("\(#file) > \(#function) > Picture message...")
        }
        else {
            print("\(#file) > \(#function) > \(messageObject.messages[indexPath.item].text)")
        }
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
        OperationQueue.main.addOperation {
            self.showTypingIndicator = false
        }
        
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            print("\(#file) > \(#function) > Adding message \(text)")
            messageObject.messages.append(message)
        }
    }
    
    private func addMediaMessage(withId id: String, name: String, media: JSQMessageMediaData) {
        OperationQueue.main.addOperation {
            self.showTypingIndicator = false
        }
        
        if let message = JSQMessage(senderId: id, displayName: name, media: media) {
            print("\(#file) > \(#function) > Adding media message")
            messageObject.messages.append(message)
        }
    }
    
    
    // When the user sends a message
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        isTyping = false
        
        let jsqMessage = JSQMessage(senderId: senderId, senderDisplayName: senderDisplayName, date: date, text: text)
        let message = MessageObject.init(peerID: messageObject.peerID, messages: [jsqMessage!])
        
        if (appDelegate.connectionManager.sendData(message: message, toPeer: message.peerID)) {
            messageObject.messages.append(jsqMessage!)
        }
        
        JSQSystemSoundPlayer.jsq_playMessageSentAlert()
        finishSendingMessage(animated: true)
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        let picker = UIImagePickerController()
        picker.delegate = self
        
        if (!UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            self.present(picker, animated: true, completion: nil)
        }
        else {
            let optionMenu = UIAlertController(title: nil, message: "Select an option", preferredStyle: .actionSheet)
            
            let cameraOption = UIAlertAction(title: "Camera", style: .default, handler: { (alert: UIAlertAction!) -> Void in
                picker.sourceType = UIImagePickerControllerSourceType.camera
                picker.showsCameraControls = true
                picker.allowsEditing = false
                
                self.present(picker, animated: true, completion: nil)
            })
            
            let photoLibraryOption = UIAlertAction(title: "Photo Library", style: .default, handler: { (alert: UIAlertAction!) -> Void in
                picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
                picker.allowsEditing = false
                self.present(picker, animated: true, completion: nil)
            })
            
            let cancelOption = UIAlertAction(title: "Cancel", style: .cancel, handler: { (alert: UIAlertAction!) -> Void in
                // do nothing
            })
            
            optionMenu.addAction(cameraOption)
            optionMenu.addAction(photoLibraryOption)
            optionMenu.addAction(cancelOption)
            
            OperationQueue.main.addOperation { () -> Void in
                self.present(optionMenu, animated: true, completion: nil)
            }
        }
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        let message = messageObject.messages[indexPath.row]
        
        if (message.isMediaMessage) {
            print("\(#file) > \(#function) > media item was touched")
            //TODO: display photo
            let mediaItem = message.media as! JSQPhotoMediaItem
            if let test: UIImage = mediaItem.image {
                self.selectedImage = test
                self.performSegue(withIdentifier: "showMedia", sender: self)
            }
        }
        else {   // Else if message is not a media item, do nothing
            print("\(#file) > \(#function) > message was touched, nothing to do")
        }
    }
    
    
    //MARK: - Message Received
    
    func receivedMessageObject(_ notification: Notification) {
        print("\(#file) > \(#function) > Message received")
        let newMessage = notification.object as! MessageObject
        
        //Vibrate
        JSQSystemSoundPlayer.jsq_playMessageReceivedAlert()
        
        if (!newMessage.messages[0].isMediaMessage) {
            addMessage(withId: newMessage.messages[0].senderId, name: newMessage.messages[0].senderDisplayName, text: newMessage.messages[0].text)
        }
        else {
            addMediaMessage(withId: newMessage.messages[0].senderId, name: newMessage.messages[0].senderDisplayName, media: newMessage.messages[0].media)
        }
        
        OperationQueue.main.addOperation {
            self.collectionView.reloadData()
            
            let lastMessage: IndexPath = IndexPath.init(row: self.messageObject.messages.count-1, section: 0)
            self.collectionView.scrollToItem(at: lastMessage, at: UICollectionViewScrollPosition.bottom, animated: true)
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    func receivedStandardMessage(_ notification: NSNotification) {
        print("\(#file) > \(#function) > Entry")
        let newMessage = notification.object as! StandardMessage
        
        if newMessage.message == userIsTyping {
            print("\(#file) > \(#function) > Peer is typing")
            OperationQueue.main.addOperation {
                self.showTypingIndicator = true
            }
        }
        else if newMessage.message == userHasStoppedTyping {
            print("\(#file) > \(#function) > Peer stopped typing")
            OperationQueue.main.addOperation {
                self.showTypingIndicator = false
            }
        }
        print("\(#file) > \(#function) > Entry")
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
    
    
    // MARK: - TextView
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        
        if (textView.text != "") {
            if (!isTyping) {
                print("\(#file) > \(#function) > Sending isTyping to peer")
                _ = appDelegate.connectionManager.sendData(stringMessage: userIsTyping, toPeer: self.messageObject.peerID)
            }
            isTyping = true
        }
        else {
            print("\(#file) > \(#function) > Sending stopped typing to peer")
            _ = appDelegate.connectionManager.sendData(stringMessage: userHasStoppedTyping, toPeer: self.messageObject.peerID)
            isTyping = false
        }
    }
    
}


@available(iOS 10.0, *)
extension JSQChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // When a photo from the photo library is taken
    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
    {
        print("\(#file) > \(#function) > Entry")
        
        let picture = info[UIImagePickerControllerOriginalImage] as! UIImage
        let mediaItem = JSQPhotoMediaItem(image: nil)
        
        mediaItem!.appliesMediaViewMaskAsOutgoing = true
        mediaItem!.image = UIImage(data: UIImageJPEGRepresentation(picture, 0.5)!)
        
        let jsqMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: mediaItem)
        let message = MessageObject.init(peerID: messageObject.peerID, messages: [jsqMessage!])
        
        print("\(#file) > \(#function) > Attempting to send photo")
        if (appDelegate.connectionManager.sendData(message: message, toPeer: messageObject.peerID)) {
            print("\(#file) > \(#function) > Added image to messages")
            
            messageObject.messages.append(jsqMessage!)
            
            self.collectionView.reloadData()
        }
        else {
            print("\(#file) > \(#function) > Failed to send...")
        }

        self.finishSendingMessage(animated: true)
        print("\(#file) > \(#function) > Exit")
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion:nil)
    }
}
