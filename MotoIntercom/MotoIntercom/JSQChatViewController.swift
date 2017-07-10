//
//  JSQChatViewController.swift
//  
//
//  Created by Logan Kember on 2017-04-06.
//
//

import UIKit
import MultipeerConnectivity
import JSQMessagesViewController
import DKImagePickerController
import Photos

@available(iOS 10.0, *)
class JSQChatViewController: JSQMessagesViewController, ConnectionManagerDelegate {

    // MARK: Properties
    var messageObject = MessageObject()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var selectedImage: UIImage?
    
    var latestMessageSentIndex = -1
    var latestMessageStatus = ""
    let delivered = "_is_delivered_"
    // TODO: Add a read message
//    let read = "_is_read_"
    
    var isTyping: Bool = false
    let userIsTyping: String = "_user_is_typing_"
    let userHasStoppedTyping: String = "_user_stopped_typing_"
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    // MARK: ViewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.senderId = appDelegate.connectionManager.uniqueID
        self.senderDisplayName = appDelegate.connectionManager.peer.displayName
        
        self.navigationItem.title = messageObject.peerID.displayName    // Setting the title to the display name
        self.updateLatestMessagesIndex()                                // Updating the latest message sent index
        
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
    
    func updateLatestMessagesIndex() {
        for i in 0..<messageObject.messages.count {
            print("Sender ID = \(messageObject.messages[i].senderId) == uniqueID = \(self.appDelegate.connectionManager.uniqueID)")
            if (messageObject.messages[i].senderId == self.appDelegate.connectionManager.uniqueID) {
                self.latestMessageSentIndex = i
            }
        }
        print("\(type(of: self)) > \(#function) > Updated index to \(self.latestMessageSentIndex)")
    }
    
    func nextMessageWasDelivered() {
        print("\(type(of: self)) > \(#function) > Updated index from \(self.latestMessageSentIndex)")
        for i in self.latestMessageSentIndex+1..<messageObject.messages.count {
            if (messageObject.messages[i].senderId == self.appDelegate.connectionManager.uniqueID) {
                self.latestMessageSentIndex = i
                break
            }
        }
        
        // Need to add to main queue since this will affect the layout
        OperationQueue.main.addOperation {
            self.collectionView.reloadData()
        }
        print("\(type(of: self)) > \(#function) > Updated index to \(self.latestMessageSentIndex)")
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
//        if messageObject.messages[indexPath.item].isMediaMessage {
//            print("\(type(of: self)) > \(#function) > Picture message...")
//        }
//        else {
//            print("\(type(of: self)) > \(#function) > \(messageObject.messages[indexPath.item].text)")
//        }
        return messageObject.messages[indexPath.item]
    }
    
    // Sets the number of messages
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("\(type(of: self)) > \(#function) > \(messageObject.messages.count)")
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
        print("\(type(of: self)) > \(#function)")
        let message = messageObject.messages[indexPath.item]
        
        // if the sender ID is us, then get an outgoingBubbleImage, else get an incomingBubbleImage
        if message.senderId == appDelegate.connectionManager.uniqueID {
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }
    }
    
    // Changes the text colour depending on who the message is from
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("\(type(of: self)) > \(#function)")
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
    
    // Adds a delivered message to chat
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        
        if (self.latestMessageSentIndex == indexPath.row) {
            print("\(type(of: self)) > \(#function) > Setting to delivered")
            
            return NSAttributedString(string: "delivered")
        }
        else {
            print("\(type(of: self)) > \(#function) > Exit")
        
            return nil
        }
    }


    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAt indexPath: IndexPath!) -> CGFloat {
        
        if (self.latestMessageSentIndex == indexPath.row) {
            print("\(type(of: self)) > \(#function) > Updating row")
            
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        else {
            print("\(type(of: self)) > \(#function) > Exit")
            
            return 0.0
        }
        
    }

    // If we want to use text label at the top, this method needs to be used
//    // Adds the name of the user that sent the message
//    override func collectionView(_ collectionView: JSQMessagesCollectionView, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath) -> NSAttributedString? {
//        let message = messageObject.messages[indexPath.row]
//        
//        if message.senderId == self.appDelegate.uniqueID {
//            return nil
//        }
//        
//        return NSAttributedString(string: message.senderDisplayName)
//    }
//    
//    // Creates space for a label for the user's name to appear
//    override func collectionView(_ collectionView: JSQMessagesCollectionView, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout, heightForMessageBubbleTopLabelAt indexPath: IndexPath) -> CGFloat {
//        
//    }
    
    // When a new message is received
    private func addMessage(withId id: String, name: String, text: String) {
        OperationQueue.main.addOperation {
            self.showTypingIndicator = false
        }
        
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            print("\(type(of: self)) > \(#function) > Adding message \(text)")
            messageObject.messages.append(message)
        }
    }
    
    private func addMediaMessage(withId id: String, name: String, media: JSQMessageMediaData) {
        OperationQueue.main.addOperation {
            self.showTypingIndicator = false
        }
        
        if let message = JSQMessage(senderId: id, displayName: name, media: media) {
            print("\(type(of: self)) > \(#function) > Adding media message")
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
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage(animated: true)
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        let picker = DKImagePickerController()
        picker.allowMultipleTypes = false
        picker.assetType = DKImagePickerControllerAssetType.allPhotos
        picker.allowsLandscape = false
        picker.showsCancelButton = true
        picker.showsEmptyAlbums = false
        
        picker.sourceType = DKImagePickerControllerSourceType.both
        self.present(picker, animated: true, completion: nil)
        
        picker.didCancel = { ()
            print("\(type(of: self)) > \(#function) > Cancelled")
        }
        
        picker.didSelectAssets = { [unowned self] (assets: [DKAsset]) in
            let assets = picker.selectedAssets
            print("\(type(of: self)) > \(#function) > Picked \(assets.count) photos/videos")

            if (assets.count == 0) {
                // Nothing to do
                return
            }
            
            var didSend = false
            
            for i in 0..<assets.count {
                let asset = assets[i]
                
                if (!asset.isVideo) {
                    asset.fetchOriginalImageWithCompleteBlock( { (image, info) in
                        if let img = image {
                            if (self.sendPhotoToPeer(image: img)) {
                                didSend = true
                            }
                        }
                    })
                }
                else {
                    //TODO: Need to decide what to do if video
                    asset.fetchAVAsset(.none, completeBlock: { (video, info) in
                        if let asset = video {
                            if self.sendVideoToPeer(video: asset) {
                                didSend = true
                            }
                        }
                    })
                }
            }
            
            if (didSend) {
                JSQSystemSoundPlayer.jsq_playMessageSentSound()
            }
        }
    }
    
    func sendPhotoToPeer(image: UIImage) -> Bool {
        
        let mediaItem = JSQPhotoMediaItem(image: nil)
        mediaItem!.appliesMediaViewMaskAsOutgoing = true
        mediaItem!.image = UIImage(data: UIImageJPEGRepresentation(image, 0.5)!)
        
        let jsqMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: mediaItem)
        let message = MessageObject.init(peerID: messageObject.peerID, messages: [jsqMessage!])

        print("\(type(of: self)) > \(#function) > Attempting to send photo")
        let didSend = appDelegate.connectionManager.sendData(message: message, toPeer: messageObject.peerID)
        if (didSend) {
            print("\(type(of: self)) > \(#function) > Added image to messages")

            messageObject.messages.append(jsqMessage!)
            self.collectionView.reloadData()
        }
        else {
            print("\(type(of: self)) > \(#function) > Failed to send...")
        }

        self.finishSendingMessage(animated: true)
        print("\(type(of: self)) > \(#function) > Exit")
        
        if didSend {
            return true
        }
        return false
    }
    
    func sendVideoToPeer(video: AVAsset) -> Bool {
        let mediaItem = JSQVideoMediaItem()
        
        return true
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        let message = messageObject.messages[indexPath.row]
        
        if (message.isMediaMessage) {
            print("\(type(of: self)) > \(#function) > media item was touched")
            //TODO: display photo
            let mediaItem = message.media as! JSQPhotoMediaItem
            if let test: UIImage = mediaItem.image {
                self.selectedImage = test
                self.performSegue(withIdentifier: "showMedia", sender: self)
            }
        }
        else {   // Else if message is not a media item, do nothing
            print("\(type(of: self)) > \(#function) > message was touched, nothing to do")
        }
    }
    
    
    //MARK: - Message Received
    
    func receivedMessageObject(_ notification: Notification) {
        print("\(type(of: self)) > \(#function) > Message received")
        let newMessage = notification.object as! MessageObject
        
        //Vibrate
        JSQSystemSoundPlayer.jsq_playMessageReceivedAlert()
        
        if (!newMessage.messages[0].isMediaMessage) {
            addMessage(withId: newMessage.messages[0].senderId, name: newMessage.messages[0].senderDisplayName, text: newMessage.messages[0].text)
        }
        else {
            addMediaMessage(withId: newMessage.messages[0].senderId, name: newMessage.messages[0].senderDisplayName, media: newMessage.messages[0].media)
        }
        
        _ = appDelegate.connectionManager.sendData(stringMessage: delivered, toPeer: self.messageObject.peerID)
        
        OperationQueue.main.addOperation {
            self.collectionView.reloadData()
            
            let lastMessage: IndexPath = IndexPath.init(row: self.messageObject.messages.count-1, section: 0)
            self.collectionView.scrollToItem(at: lastMessage, at: UICollectionViewScrollPosition.bottom, animated: true)
        }
        
        print("\(type(of: self)) > \(#function) > Exit")
    }
    
    func receivedStandardMessage(_ notification: NSNotification) {
        print("\(type(of: self)) > \(#function) > Entry")
        let newMessage = notification.object as! StandardMessage
        
        if newMessage.message == userIsTyping {
            print("\(type(of: self)) > \(#function) > Peer is typing")
            OperationQueue.main.addOperation {
                self.showTypingIndicator = true
            }
        }
        else if newMessage.message == userHasStoppedTyping {
            print("\(type(of: self)) > \(#function) > Peer stopped typing")
            OperationQueue.main.addOperation {
                self.showTypingIndicator = false
            }
        }
        else if newMessage.message == delivered {
            self.nextMessageWasDelivered()
        }
        
        print("\(type(of: self)) > \(#function) > Entry")
    }
    
    
    //MARK: - Connection Manager
    func foundPeer(_ newPeer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Peer was found.")
    }
    
    // TODO: Check if the peer lost was the current peer, if so go back to peer view
    func lostPeer(_ lostPeer: MCPeerID) {
        print("\(type(of: self)) > \(#function) > Peer was lost.")
    }
    
    func connectedWithPeer(_ peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > connected to new peer \(peerID)")
    }
    
    func disconnectedFromPeer(_ peerID: MCPeerID) {
        print("\(type(of: self)) > \(#function) > disconnected from peer \(peerID)")
        
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
        print("\(type(of: self)) > \(#function) > Received inputStream from peer \(peerID.displayName)")
    }
    
    
    // MARK: - TextView
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        
        if (textView.text != "") {
            if (!isTyping) {
                print("\(type(of: self)) > \(#function) > Sending isTyping to peer")
                _ = appDelegate.connectionManager.sendData(stringMessage: userIsTyping, toPeer: self.messageObject.peerID)
            }
            isTyping = true
        }
        else {
            print("\(type(of: self)) > \(#function) > Sending stopped typing to peer")
            _ = appDelegate.connectionManager.sendData(stringMessage: userHasStoppedTyping, toPeer: self.messageObject.peerID)
            isTyping = false
        }
    }
    
}


//@available(iOS 10.0, *)
//extension JSQChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//    
//    // When a photo from the photo library is taken
//    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
//    {
//        print("\(type(of: self)) > \(#function) > Entry")
//        
//        let picture = info[UIImagePickerControllerOriginalImage] as! UIImage
//        let mediaItem = JSQPhotoMediaItem(image: nil)
//        
//        mediaItem!.appliesMediaViewMaskAsOutgoing = true
//        mediaItem!.image = UIImage(data: UIImageJPEGRepresentation(picture, 0.5)!)
//        
//        let jsqMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: mediaItem)
//        let message = MessageObject.init(peerID: messageObject.peerID, messages: [jsqMessage!])
//        
//        print("\(type(of: self)) > \(#function) > Attempting to send photo")
//        if (appDelegate.connectionManager.sendData(message: message, toPeer: messageObject.peerID)) {
//            print("\(type(of: self)) > \(#function) > Added image to messages")
//            
//            messageObject.messages.append(jsqMessage!)
//            
//            self.collectionView.reloadData()
//        }
//        else {
//            print("\(type(of: self)) > \(#function) > Failed to send...")
//        }
//
//        self.finishSendingMessage(animated: true)
//        print("\(type(of: self)) > \(#function) > Exit")
//        picker.dismiss(animated: true, completion: nil)
//    }
//    
//    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//        picker.dismiss(animated: true, completion:nil)
//    }
//}
