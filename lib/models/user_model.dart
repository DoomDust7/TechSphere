import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String nickname;
  final String photoUrl;
  final String aboutMe;
  final String createdAt;
  final bool isOnline;
  final Timestamp? lastSeen;
  final String? typingTo;

  UserModel({
    required this.id,
    required this.nickname,
    required this.photoUrl,
    required this.aboutMe,
    required this.createdAt,
    this.isOnline = false,
    this.lastSeen,
    this.typingTo,
  });

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: data['id'] as String? ?? doc.id,
      nickname: data['nickname'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      aboutMe: data['aboutMe'] as String? ?? '',
      createdAt: data['createdAt'] as String? ?? '0',
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: data['lastSeen'] as Timestamp?,
      typingTo: data['typingTo'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nickname': nickname,
        'photoUrl': photoUrl,
        'aboutMe': aboutMe,
        'createdAt': createdAt,
        'isOnline': isOnline,
        'lastSeen': lastSeen,
        'typingTo': typingTo,
      };
}
