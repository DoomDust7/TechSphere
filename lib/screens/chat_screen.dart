import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:techsphere/models/message_model.dart';
import 'package:techsphere/widgets/full_image_widget.dart';
import 'package:techsphere/widgets/progress_widget.dart';
import 'package:timeago/timeago.dart' as timeago;

// Sticker asset paths (mimi1-9)
const List<String> _stickers = [
  'assets/images/mimi1.gif',
  'assets/images/mimi2.gif',
  'assets/images/mimi3.gif',
  'assets/images/mimi4.gif',
  'assets/images/mimi5.gif',
  'assets/images/mimi6.gif',
  'assets/images/mimi7.gif',
  'assets/images/mimi8.gif',
  'assets/images/mimi9.gif',
];

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _showStickers = false;
  bool _isUploading = false;
  Timer? _typingTimer;

  // Chat ID is always sorted so both sides use the same doc path.
  String get _chatId {
    final ids = [widget.currentUserId, widget.receiverId]..sort();
    return ids.join('_');
  }

  CollectionReference get _messagesRef =>
      _db.collection('messages').doc(_chatId).collection(_chatId);

  @override
  void initState() {
    super.initState();
    _markMessagesRead();
    _setOnline(true);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _stopTyping();
    _setOnline(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setOnline(bool online) {
    final update = online
        ? {'isOnline': true}
        : {'isOnline': false, 'lastSeen': Timestamp.now()};
    _db
        .collection('usersChat')
        .doc(widget.currentUserId)
        .update(update)
        .catchError((_) {});
  }

  void _markMessagesRead() async {
    final unread = await _messagesRef
        .where('idTo', isEqualTo: widget.currentUserId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    if (unread.docs.isNotEmpty) await batch.commit();

    // Reset unread count in conversations
    _db
        .collection('conversations')
        .doc(widget.currentUserId)
        .collection('chats')
        .doc(widget.receiverId)
        .update({'unreadCount': 0}).catchError((_) {});
  }

  void _onTypingChanged(String text) {
    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      _db
          .collection('usersChat')
          .doc(widget.currentUserId)
          .update({'typingTo': widget.receiverId}).catchError((_) {});
      _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
    } else {
      _stopTyping();
    }
  }

  void _stopTyping() {
    _db
        .collection('usersChat')
        .doc(widget.currentUserId)
        .update({'typingTo': null}).catchError((_) {});
  }

  Future<void> _sendMessage(String content, int type) async {
    if (content.trim().isEmpty && type == 0) return;

    final timestamp = Timestamp.now();
    final msg = MessageModel(
      idFrom: widget.currentUserId,
      idTo: widget.receiverId,
      content: content.trim(),
      type: type,
      timestamp: timestamp,
      isRead: false,
    );

    await _messagesRef.add(msg.toMap());

    // Update conversations for both sides
    final lastText = type == 0
        ? content.trim()
        : (type == 1 ? '📷 Image' : '🎭 Sticker');
    _updateConversation(
        myId: widget.currentUserId,
        otherId: widget.receiverId,
        otherName: widget.receiverName,
        otherPhoto: widget.receiverAvatar,
        lastMessage: lastText,
        timestamp: timestamp,
        incrementUnread: false);
    _updateConversation(
        myId: widget.receiverId,
        otherId: widget.currentUserId,
        otherName: '', // will be fetched from prefs on other side
        otherPhoto: '',
        lastMessage: lastText,
        timestamp: timestamp,
        incrementUnread: true);

    _messageController.clear();
    _stopTyping();
    _scrollToBottom();
  }

  void _updateConversation({
    required String myId,
    required String otherId,
    required String otherName,
    required String otherPhoto,
    required String lastMessage,
    required Timestamp timestamp,
    required bool incrementUnread,
  }) async {
    final ref = _db
        .collection('conversations')
        .doc(myId)
        .collection('chats')
        .doc(otherId);
    final snap = await ref.get();

    if (incrementUnread) {
      final currentCount =
          snap.exists ? (snap.data()?['unreadCount'] as int? ?? 0) : 0;
      // Fetch sender info for receiver's side
      final senderSnap =
          await _db.collection('usersChat').doc(myId).get();
      final senderData = senderSnap.data();
      ref.set({
        'otherUserId': myId,
        'otherUserName': senderData?['nickname'] ?? '',
        'otherUserPhoto': senderData?['photoUrl'] ?? '',
        'lastMessage': lastMessage,
        'lastTimestamp': timestamp,
        'unreadCount': currentCount + 1,
      });
    } else {
      ref.set({
        'otherUserId': otherId,
        'otherUserName': otherName,
        'otherUserPhoto': otherPhoto,
        'lastMessage': lastMessage,
        'lastTimestamp': timestamp,
        'unreadCount': 0,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _sendImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      UploadTask task;
      if (kIsWeb) {
        task = ref.putData(await picked.readAsBytes());
      } else {
        task = ref.putFile(File(picked.path));
      }
      await task;
      final url = await ref.getDownloadURL();
      await _sendMessage(url, 1);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Image send failed: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _showStickers = false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.receiverAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(widget.receiverAvatar)
                    : null,
                child: widget.receiverAvatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.receiverName,
                        style: const TextStyle(fontSize: 16)),
                    _OnlineStatus(userId: widget.receiverId),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Typing indicator
            _TypingIndicator(
                receiverId: widget.receiverId,
                currentUserId: widget.currentUserId),
            // Message list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _messagesRef
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return circularProgress();
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('Say hello!',
                            style: TextStyle(color: Colors.grey)));
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent);
                    }
                  });
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, i) {
                      final msg = MessageModel.fromDocument(
                          snapshot.data!.docs[i]);
                      final isMe = msg.idFrom == widget.currentUserId;
                      return _MessageBubble(
                          msg: msg,
                          isMe: isMe,
                          onImageTap: (url) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      FullImageWidget(url: url))));
                    },
                  );
                },
              ),
            ),
            if (_isUploading) linearProgress(),
            // Sticker panel
            if (_showStickers) _StickerPanel(onSelect: (path) {
              _sendMessage(path, 2);
              setState(() => _showStickers = false);
            }),
            // Input bar
            _InputBar(
              controller: _messageController,
              onSend: () => _sendMessage(_messageController.text, 0),
              onImage: _sendImage,
              onSticker: () =>
                  setState(() => _showStickers = !_showStickers),
              onChanged: _onTypingChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────── Sub-widgets ────────────────

class _OnlineStatus extends StatelessWidget {
  final String userId;
  const _OnlineStatus({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usersChat')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();
        final online = data['isOnline'] as bool? ?? false;
        if (online) {
          return const Text('Online',
              style: TextStyle(fontSize: 11, color: Colors.white70));
        }
        final ts = data['lastSeen'] as Timestamp?;
        if (ts == null) return const SizedBox.shrink();
        return Text(
          'Last seen ${timeago.format(ts.toDate())}',
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        );
      },
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final String receiverId;
  final String currentUserId;
  const _TypingIndicator(
      {required this.receiverId, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usersChat')
          .doc(receiverId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>?;
        final typing = data?['typingTo'] as String?;
        if (typing == currentUserId) {
          return Container(
            alignment: Alignment.centerLeft,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: const Text(
              'typing…',
              style: TextStyle(
                  color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final ValueChanged<String> onImageTap;
  const _MessageBubble(
      {required this.msg, required this.isMe, required this.onImageTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (msg.type == 0) // text
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.lightBlueAccent
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(msg.content,
                        style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(msg.timestamp),
                          style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white70
                                  : Colors.grey),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            msg.isRead
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: msg.isRead
                                ? Colors.white
                                : Colors.white54,
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (msg.type == 1) // image
            GestureDetector(
              onTap: () => onImageTap(msg.content),
              child: Hero(
                tag: msg.content,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: msg.content,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => circularProgress(),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 80),
                  ),
                ),
              ),
            )
          else // sticker
            Image.asset(msg.content, width: 120, height: 120),
        ],
      ),
    );
  }

  String _formatTime(Timestamp ts) {
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _StickerPanel extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _StickerPanel({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: GridView.count(
        crossAxisCount: 5,
        padding: const EdgeInsets.all(8),
        children: _stickers
            .map((path) => GestureDetector(
                  onTap: () => onSelect(path),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(path),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final VoidCallback onSticker;
  final ValueChanged<String> onChanged;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onImage,
    required this.onSticker,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image, color: Colors.lightBlueAccent),
              onPressed: onImage,
            ),
            IconButton(
              icon: const Icon(Icons.face, color: Colors.lightBlueAccent),
              onPressed: onSticker,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                maxLines: null,
              ),
            ),
            IconButton(
              icon:
                  const Icon(Icons.send, color: Colors.lightBlueAccent),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}
