import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String idFrom;
  final String idTo;
  final String content;
  final int type; // 0 = text, 1 = image, 2 = sticker
  final Timestamp timestamp;
  final bool isRead;

  MessageModel({
    required this.idFrom,
    required this.idTo,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory MessageModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      idFrom: data['idFrom'] as String? ?? '',
      idTo: data['idTo'] as String? ?? '',
      content: data['content'] as String? ?? '',
      type: data['type'] as int? ?? 0,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'idFrom': idFrom,
        'idTo': idTo,
        'content': content,
        'type': type,
        'timestamp': timestamp,
        'isRead': isRead,
      };
}
