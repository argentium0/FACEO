import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Decentralized client-side sweeper service that cleans up expired rooms
/// (rooms empty for > 5 minutes) to adhere to Firebase Spark Plan (zero server cost).
class RoomSweeperService {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _realtimeDb;

  RoomSweeperService({
    FirebaseFirestore? firestore,
    FirebaseDatabase? realtimeDb,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _realtimeDb = realtimeDb ?? FirebaseDatabase.instance;

  /// Runs background sweep to find and purge expired rooms.
  /// A room is considered expired if `emptyAt` timestamp is > 5 minutes (300,000 ms) ago.
  Future<void> sweepExpiredRooms() async {
    try {
      final cutoffTimeMs = DateTime.now().millisecondsSinceEpoch - (5 * 60 * 1000);
      final cutoffTimestamp = Timestamp.fromMillisecondsSinceEpoch(cutoffTimeMs);

      final Set<String> expiredRoomIds = {};

      // 1. Query Realtime Database for expired rooms
      try {
        final rtdbSnapshot = await _realtimeDb.ref('rooms').get();
        if (rtdbSnapshot.exists && rtdbSnapshot.value is Map) {
          final roomsMap = Map<dynamic, dynamic>.from(rtdbSnapshot.value as Map);
          roomsMap.forEach((roomId, data) {
            if (data is Map && data.containsKey('emptyAt')) {
              final emptyAtVal = data['emptyAt'];
              if (emptyAtVal is int && emptyAtVal <= cutoffTimeMs) {
                expiredRoomIds.add(roomId.toString());
              }
            }
          });
        }
      } catch (e) {
        // Quietly catch RTDB read exceptions
      }

      // 2. Query Cloud Firestore for expired rooms
      try {
        final firestoreQuery = await _firestore
            .collection('rooms')
            .where('emptyAt', isLessThanOrEqualTo: cutoffTimestamp)
            .get();

        for (final doc in firestoreQuery.docs) {
          expiredRoomIds.add(doc.id);
        }
      } catch (e) {
        // Quietly catch Firestore query exceptions
      }

      if (expiredRoomIds.isEmpty) return;

      // 3. Execute Batch Deletion across Firestore and Realtime Database
      final batch = _firestore.batch();
      for (final roomId in expiredRoomIds) {
        final roomDocRef = _firestore.collection('rooms').doc(roomId);
        batch.delete(roomDocRef);
      }
      await batch.commit();

      // Clear Realtime Database nodes for expired rooms
      for (final roomId in expiredRoomIds) {
        await _realtimeDb.ref('rooms/$roomId').remove();
        await _realtimeDb.ref('presence/$roomId').remove();
        await _realtimeDb.ref('activeSpeaker/$roomId').remove();
      }
    } catch (e) {
      // Quietly swallow top-level exceptions to keep background process non-blocking
    }
  }
}
