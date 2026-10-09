import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  static FirestoreService get instance => _instance;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  FirebaseFirestore get db => _db;

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get usernamesCollection =>
      _db.collection('usernames');

  CollectionReference<Map<String, dynamic>> get activitiesCollection =>
      _db.collection('activities');

  CollectionReference<Map<String, dynamic>> get communityCollection =>
      _db.collection('community');

  CollectionReference<Map<String, dynamic>> get conversationsCollection =>
      _db.collection('conversations');

  CollectionReference<Map<String, dynamic>> get notificationsCollection =>
      _db.collection('notifications');

  FieldValue get serverTimestamp => FieldValue.serverTimestamp();

  FirestoreService._internal();
}
