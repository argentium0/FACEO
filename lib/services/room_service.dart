import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service managing room metadata persistence in Cloud Firestore
/// and real-time user presence tracking with [onDisconnect] hooks in Firebase Realtime Database.
class RoomService {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _realtimeDb;

  RoomService({
    FirebaseFirestore? firestore,
    FirebaseDatabase? realtimeDb,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _realtimeDb = realtimeDb ?? FirebaseDatabase.instance;

  /// Creates a new room document in Firestore `/rooms/{roomId}`
  /// and returns the generated room ID.
  Future<String> createRoom({
    required String hostUserId,
    required String title,
    bool isGroupCall = true,
  }) async {
    final roomRef = _firestore.collection('rooms').doc();
    final roomId = roomRef.id;

    final roomData = {
      'roomId': roomId,
      'hostUserId': hostUserId,
      'title': title,
      'isGroupCall': isGroupCall,
      'status': 'active',
      'participantCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await roomRef.set(roomData);
    return roomId;
  }

  /// Sets up Realtime Database presence for a user in a specific room at `/presence/{roomId}/{userId}`.
  /// Attaches an [onDisconnect] hook so force-kills or backgrounding automatically set presence state to 'offline'.
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String userName,
  }) async {
    final presenceRef = _realtimeDb.ref('presence/$roomId/$userId');

    final onlineState = {
      'userId': userId,
      'userName': userName,
      'state': 'online',
      'joinedAt': ServerValue.timestamp,
      'lastSeen': ServerValue.timestamp,
    };

    final offlineState = {
      'userId': userId,
      'userName': userName,
      'state': 'offline',
      'lastSeen': ServerValue.timestamp,
    };

    // Configure automatic cleanup when connection disconnects
    await presenceRef.onDisconnect().set(offlineState);

    // Write online state
    await presenceRef.set(onlineState);

    // Atomically increment participant count in Firestore
    await _firestore.collection('rooms').doc(roomId).set({
      'participantCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Explicitly leaves a room presence node in RTDB and updates Firestore participant count.
  Future<void> leaveRoomPresence({
    required String roomId,
    required String userId,
  }) async {
    final presenceRef = _realtimeDb.ref('presence/$roomId/$userId');

    // Cancel onDisconnect hook and set offline status immediately
    await presenceRef.onDisconnect().cancel();
    await presenceRef.set({
      'userId': userId,
      'state': 'offline',
      'lastSeen': ServerValue.timestamp,
    });

    // Atomically decrement participant count in Firestore
    await _firestore.collection('rooms').doc(roomId).set({
      'participantCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns a stream of online participants in a room from Realtime Database `/presence/{roomId}`.
  Stream<List<Map<String, dynamic>>> streamRoomParticipants(String roomId) {
    return _realtimeDb.ref('presence/$roomId').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final List<Map<String, dynamic>> participants = [];
      data.forEach((key, value) {
        if (value is Map && value['state'] == 'online') {
          participants.add(Map<String, dynamic>.from(value));
        }
      });

      return participants;
    });
  }
}
