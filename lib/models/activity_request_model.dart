import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityRequestModel {
  final String uid;
  final String activityId;
  final String status; // 'pending', 'accepted', 'rejected', 'cancelled'
  final String userName;
  final String userUsername;
  final String? userPhotoUrl;
  final DateTime? requestedAt;

  const ActivityRequestModel({
    required this.uid,
    required this.activityId,
    this.status = 'pending',
    required this.userName,
    required this.userUsername,
    this.userPhotoUrl,
    this.requestedAt,
  });

  factory ActivityRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    DateTime? dt;
    final ts = data['requestedAt'];
    if (ts is Timestamp) {
      dt = ts.toDate();
    }

    return ActivityRequestModel(
      uid: doc.id,
      activityId: data['activityId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      userName: data['userName'] as String? ?? 'Player',
      userUsername: data['userUsername'] as String? ?? '',
      userPhotoUrl: data['userPhotoUrl'] as String?,
      requestedAt: dt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'activityId': activityId,
      'status': status,
      'userName': userName,
      'userUsername': userUsername,
      'userPhotoUrl': userPhotoUrl,
      'requestedAt': FieldValue.serverTimestamp(),
    };
  }
}
