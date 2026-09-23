import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String username;
  final String normalizedUsername;
  final String email;
  final String phoneNumber;
  final String? photoUrl;
  final String selectedCity;
  final String? gender;
  final List<String> interests;
  final bool isProfileComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfileModel({
    required this.uid,
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.normalizedUsername = '',
    this.email = '',
    this.phoneNumber = '',
    this.photoUrl,
    this.selectedCity = '',
    this.gender,
    this.interests = const [],
    this.isProfileComplete = false,
    this.createdAt,
    this.updatedAt,
  });

  String get displayName {
    final full = '$firstName $lastName'.trim();
    if (full.isNotEmpty) return full;
    if (username.isNotEmpty) return username;
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'normalizedUsername': normalizedUsername.isNotEmpty
          ? normalizedUsername
          : username.trim().toLowerCase(),
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'selectedCity': selectedCity,
      'gender': gender,
      'interests': interests,
      'isProfileComplete': isProfileComplete,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return UserProfileModel(
      uid: docId,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      username: map['username'] as String? ?? '',
      normalizedUsername: map['normalizedUsername'] as String? ??
          (map['username'] as String? ?? '').trim().toLowerCase(),
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      selectedCity: map['selectedCity'] as String? ?? '',
      gender: map['gender'] as String?,
      interests: map['interests'] != null
          ? List<String>.from(map['interests'] as List)
          : const [],
      isProfileComplete: map['isProfileComplete'] as bool? ?? false,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory UserProfileModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfileModel.fromMap(data, doc.id);
  }

  UserProfileModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? username,
    String? normalizedUsername,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? selectedCity,
    String? gender,
    List<String>? interests,
    bool? isProfileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      normalizedUsername: normalizedUsername ?? this.normalizedUsername,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      selectedCity: selectedCity ?? this.selectedCity,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
