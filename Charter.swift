//
//  Charter.swift
//  
//
//  Created by Zhenyang Zhong on 6/9/16.
//
//

import UIKit
import FirebaseDatabase
import JSQMessagesViewController
import JSQSystemSoundPlayer
import FirebaseAuth
import KRVideoPlayer
import MJRefresh

class Charter: JSQMessagesViewController{

    var messages = [JSQMessage]()
    var outgoingBubbleImageView: JSQMessagesBubbleImage!
    var incomingBubbleImageView: JSQMessagesBubbleImage!
    var ref = FIRDatabase.database().reference().child("Messages")
    var userRef = FIRDatabase.database().reference().child("users")
    var avatars = [String:JSQMessagesAvatarImage]()
    var videoView:KRVideoPlayerController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        edgesForExtendedLayout = []
        title = "Chatter"
        setupBubbles()
        setupAvatarColor(senderId, incoming: false)
        automaticallyScrollsToMostRecentMessage = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        
        let header = MJRefreshNormalHeader(refreshingBlock: {
            
        })
        collectionView.mj_header = header
    }
    
    func setupVideo(_ url:URL){
        let width = UIScreen.main().bounds.size.width;
        videoView = KRVideoPlayerController(frame: CGRect(x: 0, y: 0, width: width, height: width*9/16))
        videoView.contentURL = url
    }
    
    func dismissKeyboard() {
        isEditing = false
    }
    
    func sortDicByKey(_ lhs:(key: AnyObject, value: AnyObject), rhs: (key: AnyObject, value: AnyObject)) -> Bool{
        return (lhs.key as! String) < (rhs.key as! String)
    }

    func loadMsg(){
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            for msg in snapshot.children.allObjects as! [FIRDataSnapshot]{
                if let dic = msg.value as? Dictionary<String, String>{
                    self.addMessage(dic["senderId"]!, text: dic["text"]!)
                }
            }
            self.finishReceivingMessage()
        })
    }

    var userIsTypingRef: FIRDatabaseReference! // 1
    private var localTyping = false // 2
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    func sendPhoto(_ action:UIAlertAction){
        let photoItem = JSQPhotoMediaItem(image: UIImage(named: "CR7")!)
        let photoMsg = JSQMessage(senderId: senderId, senderDisplayName: senderId, date: Date(), media: photoItem)
        messages.append(photoMsg!)
        finishReceivingMessage()
    }
    
    func sendLocation(_ action:UIAlertAction){
        weak var weakView = collectionView
        addLoction(){
            weakView?.reloadData()
        }
    }
    
    func addLoction(_ completion:JSQLocationMediaItemCompletionBlock) {
        let ferryBuildingInSF = CLLocation(latitude: 37.795313, longitude: -122.393757)
        let locationItem = JSQLocationMediaItem()
        locationItem.setLocation(ferryBuildingInSF, withCompletionHandler: completion)
        let locationMsg = JSQMessage(senderId: senderId, displayName: senderId, media: locationItem)
        messages.append(locationMsg!)
        finishSendingMessage()
    }
    
    func sendVideo(_ action:UIAlertAction){
        let url = Bundle.main().urlForResource("sherry", withExtension: "m4v")
        let video = JSQVideoMediaItem(fileURL: url, isReadyToPlay: true)
        let videoMsg = JSQMessage(senderId: senderId, displayName: senderId, media: video)
        messages.append(videoMsg!)
        finishSendingMessage()
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didDeleteMessageAt indexPath: IndexPath!) {
        if let video = messages[indexPath.item!].media as? JSQVideoMediaItem{
            weak var weakSelf = self
            setupVideo(video.fileURL)
            videoView.dimissCompleteBlock = {
                weakSelf?.videoView = nil
            }
            videoView.showInWindow()
        }
    }
    
    func sendAudio(_ action:UIAlertAction){
        let sample = Bundle.main().pathForResource("hello", ofType: "mp3")
        let url = URL(string: sample!)!
        let data = try! Data(contentsOf: url)
        let audioItem = JSQAudioMediaItem(data: data)
        let audioMsg = JSQMessage(senderId: senderId, displayName: senderId, media: audioItem)
        messages.append(audioMsg!)
        finishSendingMessage()
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        inputToolbar.contentView.textView.resignFirstResponder()
    
        let sheet = UIAlertController(title: "Media messages", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Send photo", style: .default, handler: sendPhoto))
        sheet.addAction(UIAlertAction(title: "Send location", style: .default, handler: sendLocation))
        sheet.addAction(UIAlertAction(title: "Send video", style: .default, handler: sendVideo))
        sheet.addAction(UIAlertAction(title: "Send audio", style: .default, handler: sendAudio))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(sheet, animated: true, completion: nil)
    }
    
    private func observeTyping() {
        let typingIndicatorRef = FIRDatabase.database().reference().child("typingIndicator")
        userIsTypingRef = typingIndicatorRef.child(senderId)
        isTyping = false
        typingIndicatorRef.observe(.value, with:  { (snapshot) in
            for user in snapshot.children.allObjects as! [FIRDataSnapshot]{
                if user.key != self.senderId{
                    if user.value as! Bool{
                        self.showTypingIndicator = true
                        self.scrollToBottom(animated: true)
                    }
                    else {
                        self.showTypingIndicator = false
                    }
                }
            }
        })
    }
    
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        isTyping = textView.text != ""
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item!]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = messages[indexPath.item!]
        setupAvatarColor(message.senderId, incoming: true)
        return UIImageView(image: avatars[message.senderId]!.avatarImage)
    }
    
    // bubble
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item!]
        if message.senderId == senderId{
            return outgoingBubbleImageView
        }
        else {
            return incomingBubbleImageView
        }
    }
    
    private func setupBubbles() {
        let factory = JSQMessagesBubbleImageFactory()
        outgoingBubbleImageView = factory?.outgoingMessagesBubbleImage(
            with: UIColor.jsq_messageBubbleBlue())
        incomingBubbleImageView = factory?.incomingMessagesBubbleImage(
            with: UIColor.jsq_messageBubbleLightGray())
    }
    
    func addMessage(_ id: String, text: String) {
        let message = JSQMessage(senderId: id, displayName: senderDisplayName, text: text)
        messages.append(message!)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // animates the receiving of a new message on the view
        loadMsg()
        observeTyping()
        finishReceivingMessage()
    }
    
    // text color
    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath)
            as! JSQMessagesCollectionViewCell
        
        let message = messages[indexPath.item!]
        
        if let textView = cell.textView{
            if message.senderId == senderId {
                textView.textColor = UIColor.white()
            } else {
                textView.textColor = UIColor.black()
            }
        }
        
        return cell
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        addMessage(senderId, text: text)
        let msgRef = ref.childByAutoId()
        msgRef.child("senderId").setValue(senderId)
        msgRef.child("text").setValue(text)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage()
    }
    
    func setupAvatarColor(_ name: String, incoming: Bool) {
        guard let _ = avatars[name] else{
            let diameter = incoming ? UInt(collectionView!.collectionViewLayout.incomingAvatarViewSize.width) : UInt(collectionView!.collectionViewLayout.outgoingAvatarViewSize.width)
            
            let rgbValue = name.hash
            let r = CGFloat(Float((rgbValue & 0xFF0000) >> 16)/255.0)
            let g = CGFloat(Float((rgbValue & 0xFF00) >> 8)/255.0)
            let b = CGFloat(Float(rgbValue & 0xFF)/255.0)
            let color = UIColor(red: r, green: g, blue: b, alpha: 0.5)
            
//            let initials : String? = name.substring(to: senderId.startIndex.advancedBy(n: min(3, nameLength)))
//            let initials = name.substring(to: senderId.startIndex + 3)
            let initials = (name as NSString).substring(to: 3)
            let userImage = JSQMessagesAvatarImageFactory.avatarImage(withUserInitials: initials, backgroundColor: color, textColor: UIColor.black(), font: UIFont.systemFont(ofSize: CGFloat(13)), diameter: diameter)
            avatars[name] = userImage
            return
        }
    }
    
    // View  usernames above bubbles
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> AttributedString! {
        let message = messages[indexPath.item!];
        // Sent by me, skip
        if message.senderId == senderId {
            return nil;
        }
        // Same as previous sender, skip
        if indexPath.item > 0 {
            let previousMessage = messages[indexPath.item! - 1];
            if previousMessage.senderId == message.senderId {
                return nil;
            }
        }
        let attribute = AttributedString(string:message.senderId)
        return attribute
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        let message = messages[indexPath.item!]
        // Sent by me, skip
        if message.senderId == senderId {
            return CGFloat(0.0);
        }
        // Same as previous sender, skip
        if indexPath.item > 0 {
            let previousMessage = messages[indexPath.item! - 1];
            if previousMessage.senderId == message.senderId {
                return CGFloat(0.0);
            }
        }
        return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
}

extension UIImageView: JSQMessageBubbleImageDataSource, JSQMessageAvatarImageDataSource{
    public func messageBubbleImage() -> UIImage!{
        return image!
    }
    public func messageBubbleHighlightedImage() -> UIImage!{
        return (highlightedImage != nil) ? highlightedImage! : image!
    }
    public func avatarImage() -> UIImage{
        return image!
    }
    public func avatarHighlightedImage() -> UIImage!{
        return (highlightedImage != nil) ? highlightedImage! : image!
    }
    public func avatarPlaceholderImage() -> UIImage!{
        return image!
    }
}

