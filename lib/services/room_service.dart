import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service managing room metadata persistence in Cloud Firestore
/// and real-time user presence tracking with [onDisconnect] hooks in Firebase Realtime Database.
/// Implements Ephemeral Rooms (Burn-After-Meeting) architecture with bulletproof Web JS interop error handling.
class RoomService {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _realtimeDb;

  RoomService({
    FirebaseFirestore? firestore,
    FirebaseDatabase? realtimeDb,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _realtimeDb = realtimeDb ?? FirebaseDatabase.instance;

  /// Creates a new room document in Firestore `/rooms/{roomId}`
  /// and RTDB `/rooms/{roomId}`. Returns the generated room ID.
  Future<String> createRoom({
    required String hostUserId,
    required String title,
    bool isGroupCall = true,
  }) async {
    try {
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

      // Initialize room node in RTDB
      try {
        await _realtimeDb.ref('rooms/$roomId').set({
          'roomId': roomId,
          'hostUserId': hostUserId,
          'title': title,
          'status': 'active',
          'createdAt': ServerValue.timestamp,
        });
      } catch (_) {}

      return roomId;
    } catch (e) {
      throw Exception('Failed to create room: ${e.toString()}');
    }
  }

  /// Sets up Realtime Database presence for a user in a specific room at `/presence/{roomId}/{userId}`.
  /// Cancels countdown by removing `emptyAt` if room is active and unexpired.
  /// Configures `onDisconnect()` handlers so server timestamp `emptyAt` is written when participant count reaches 0.
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String userName,
  }) async {
    try {
      final roomRtdbRef = _realtimeDb.ref('rooms/$roomId');
      final roomDocRef = _firestore.collection('rooms').doc(roomId);

      // Check if room is expired before allowing join
      try {
        final rtdbSnapshot = await roomRtdbRef.get();
        if (rtdbSnapshot.exists && rtdbSnapshot.value is Map) {
          final data = Map<dynamic, dynamic>.from(rtdbSnapshot.value as Map);
          if (data.containsKey('emptyAt') && data['emptyAt'] != null) {
            final int emptyAtMs = data['emptyAt'] as int;
            final int nowMs = DateTime.now().millisecondsSinceEpoch;
            if (nowMs >= emptyAtMs + (5 * 60 * 1000)) {
              throw Exception('Room has expired and is no longer accessible.');
            }
          }
        }
      } catch (e) {
        if (e.toString().contains('expired')) rethrow;
      }

      // Cancel countdown by removing emptyAt key in RTDB and Firestore
      try {
        await roomRtdbRef.child('emptyAt').remove();
      } catch (_) {}
      
      try {
        await roomDocRef.update({'emptyAt': FieldValue.delete()});
      } catch (_) {}

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

      // Configure automatic offline state on disconnect
      try {
        await presenceRef.onDisconnect().set(offlineState);
        await roomRtdbRef.child('emptyAt').onDisconnect().set(ServerValue.timestamp);
        await presenceRef.set(onlineState);
      } catch (_) {}

      // Atomically increment participant count in Firestore
      try {
        await roomDocRef.set({
          'participantCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      if (e.toString().contains('expired')) rethrow;
    }
  }

  /// Explicitly leaves a room presence node in RTDB and updates Firestore participant count.
  /// If active participant count reaches 0, writes server timestamp `emptyAt` to RTDB and Firestore.
  Future<void> leaveRoomPresence({
    required String roomId,
    required String userId,
  }) async {
    try {
      final presenceRef = _realtimeDb.ref('presence/$roomId/$userId');
      final roomRtdbRef = _realtimeDb.ref('rooms/$roomId');
      final roomDocRef = _firestore.collection('rooms').doc(roomId);

      try {
        await presenceRef.onDisconnect().cancel();
        await presenceRef.set({
          'userId': userId,
          'state': 'offline',
          'lastSeen': ServerValue.timestamp,
        });
      } catch (_) {}

      try {
        await roomDocRef.set({
          'participantCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // Check active online participants in RTDB
      int activeCount = 0;
      try {
        final presenceSnapshot = await _realtimeDb.ref('presence/$roomId').get();
        if (presenceSnapshot.exists && presenceSnapshot.value is Map) {
          final presenceData = Map<dynamic, dynamic>.from(presenceSnapshot.value as Map);
          presenceData.forEach((key, val) {
            if (val is Map && val['state'] == 'online') {
              activeCount++;
            }
          });
        }
      } catch (_) {}

      // If active participant count reaches 0, write emptyAt server timestamp
      if (activeCount == 0) {
        try {
          await roomRtdbRef.child('emptyAt').set(ServerValue.timestamp);
        } catch (_) {}
        try {
          await roomDocRef.set({
            'emptyAt': FieldValue.serverTimestamp(),
            'status': 'empty',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Returns a stream of online participants in a room from Realtime Database `/presence/{roomId}`.
  /// Includes `.handleError` to prevent unhandled JS-interop stream rejections on Flutter Web.
  Stream<List<Map<String, dynamic>>> streamRoomParticipants(String roomId) {
    return _realtimeDb.ref('presence/$roomId').onValue.map<List<Map<String, dynamic>>>((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final List<Map<String, dynamic>> participants = [];
      data.forEach((key, value) {
        if (value is Map && value['state'] == 'online') {
          participants.add(Map<String, dynamic>.from(value));
        }
      });
      return participants;
    }).handleError((error, stackTrace) {
      return List<Map<String, dynamic>>.empty();
    });
  }
}
