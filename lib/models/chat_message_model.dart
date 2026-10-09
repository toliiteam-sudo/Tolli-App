import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String senderId;
  final String sender;
  final String? senderPhotoUrl;
  final String text;
  final String time;
  final bool isMe;
  final DateTime? createdAt;
  final String type; // 'text' | 'image'
  final String? imageUrl;

  const ChatMessageModel({
    required this.id,
    this.senderId = '',
    required this.sender,
    this.senderPhotoUrl,
    required this.text,
    required this.time,
    required this.isMe,
    this.createdAt,
    this.type = 'text',
    this.imageUrl,
  });

  factory ChatMessageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String currentUid,
  ) {
    final data = doc.data() ?? {};
    final String senderId = data['senderId'] as String? ?? '';
    final String senderName = data['senderName'] as String? ?? (data['sender'] as String? ?? 'User');
    final String text = data['text'] as String? ?? '';
    final String? photoUrl = data['senderPhotoUrl'] as String?;
    final String msgType = data['type'] as String? ?? (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty ? 'image' : 'text');
    final String? imageUrl = data['imageUrl'] as String?;

    DateTime? createdDateTime;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      createdDateTime = ts.toDate();
    } else if (ts is String) {
      createdDateTime = DateTime.tryParse(ts);
    }
    createdDateTime ??= DateTime.now();

    final hour = createdDateTime.hour % 12 == 0 ? 12 : createdDateTime.hour % 12;
    final minute = createdDateTime.minute.toString().padLeft(2, '0');
    final period = createdDateTime.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    return ChatMessageModel(
      id: doc.id,
      senderId: senderId,
      sender: senderId == currentUid ? 'You' : senderName,
      senderPhotoUrl: photoUrl,
      text: text,
      time: timeStr,
      isMe: senderId == currentUid,
      createdAt: createdDateTime,
      type: msgType,
      imageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': sender,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'type': type,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
