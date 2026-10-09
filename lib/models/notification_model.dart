import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String recipientId;
  final String type; // 'join_request', 'request_accepted', 'request_rejected', 'new_activity', 'broadcast'
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool isRead;
  final String? relatedActivityId;
  final String? relatedCommunityId;
  final String? relatedUserId;
  final String? actionType;
  final String? senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final String? requestStatus; // 'PENDING', 'APPROVED', 'DECLINED'

  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    this.createdAt,
    this.isRead = false,
    this.relatedActivityId,
    this.relatedCommunityId,
    this.relatedUserId,
    this.actionType,
    this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    this.requestStatus,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime? created;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      created = ts.toDate();
    } else if (ts is String) {
      created = DateTime.tryParse(ts);
    }

    return NotificationModel(
      id: doc.id,
      recipientId: data['recipientId'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: created,
      isRead: data['isRead'] as bool? ?? false,
      relatedActivityId: data['relatedActivityId'] as String?,
      relatedCommunityId: data['relatedCommunityId'] as String?,
      relatedUserId: data['relatedUserId'] as String?,
      actionType: data['actionType'] as String?,
      senderId: data['senderId'] as String?,
      senderName: data['senderName'] as String?,
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
      requestStatus: data['requestStatus'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recipientId': recipientId,
      'type': type,
      'title': title,
      'body': body,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isRead': isRead,
      'relatedActivityId': relatedActivityId,
      'relatedCommunityId': relatedCommunityId,
      'relatedUserId': relatedUserId,
      'actionType': actionType,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'requestStatus': requestStatus,
    };
  }

  NotificationModel copyWith({
    bool? isRead,
    String? requestStatus,
  }) {
    return NotificationModel(
      id: id,
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      relatedActivityId: relatedActivityId,
      relatedCommunityId: relatedCommunityId,
      relatedUserId: relatedUserId,
      actionType: actionType,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }
}
