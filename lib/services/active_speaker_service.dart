import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

/// Active Speaker Detection Service utilizing ZegoCloud sound level monitoring
/// with throttled write operations to Realtime Database `/activeSpeaker/{roomId}`
/// to prevent database hot-spotting.
class ActiveSpeakerService {
  final FirebaseDatabase _realtimeDb;

  ActiveSpeakerService({FirebaseDatabase? realtimeDb})
      : _realtimeDb = realtimeDb ?? FirebaseDatabase.instance;

  String? _currentActiveSpeakerId;
  DateTime _lastWriteTime = DateTime.fromMillisecondsSinceEpoch(0);
  
  // Throttle interval threshold (500 milliseconds)
  static const Duration _throttleInterval = Duration(milliseconds: 500);
  
  // Sound level threshold below which audio is treated as silence
  static const double _soundThreshold = 5.0;

  StreamSubscription<DatabaseEvent>? _activeSpeakerSubscription;
  final StreamController<String?> _activeSpeakerController = StreamController<String?>.broadcast();

  /// Stream of active speaker user IDs for UI consumption.
  Stream<String?> get activeSpeakerStream => _activeSpeakerController.stream;

  /// Currently detected active speaker ID.
  String? get currentActiveSpeakerId => _currentActiveSpeakerId;

  /// Starts sound level monitoring and listens to RTDB `/activeSpeaker/{roomId}`.
  void startMonitoring({
    required String roomId,
    required String localUserId,
  }) {
    // 1. Enable ZegoCloud sound level monitor
    ZegoExpressEngine.instance.startSoundLevelMonitor();

    // Track local sound level
    ZegoExpressEngine.onCapturedSoundLevelUpdate = (double soundLevel) {
      if (soundLevel > _soundThreshold) {
        _evaluateActiveSpeaker(roomId: roomId, speakerId: localUserId, soundLevel: soundLevel);
      }
    };

    // Track remote sound levels
    ZegoExpressEngine.onRemoteSoundLevelUpdate = (Map<String, double> soundLevels) {
      String? topSpeakerId;
      double maxLevel = _soundThreshold;

      soundLevels.forEach((streamId, level) {
        if (level > maxLevel) {
          maxLevel = level;
          // Extracts userId from streamId convention: `${roomId}_${userId}_main`
          final parts = streamId.split('_');
          if (parts.length >= 2) {
            topSpeakerId = parts[1];
          } else {
            topSpeakerId = streamId;
          }
        }
      });

      if (topSpeakerId != null) {
        _evaluateActiveSpeaker(roomId: roomId, speakerId: topSpeakerId!, soundLevel: maxLevel);
      }
    };

    // 2. Listen to RTDB node for active speaker updates across clients
    _activeSpeakerSubscription = _realtimeDb.ref('activeSpeaker/$roomId').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final speakerId = data?['activeSpeakerId'] as String?;

      if (_currentActiveSpeakerId != speakerId) {
        _currentActiveSpeakerId = speakerId;
        _activeSpeakerController.add(speakerId);
      }
    });
  }

  /// Throttles writes to RTDB `/activeSpeaker/{roomId}` to prevent hot-spotting.
  void _evaluateActiveSpeaker({
    required String roomId,
    required String speakerId,
    required double soundLevel,
  }) {
    final now = DateTime.now();

    // Enforce minimum 500ms throttle interval between database writes
    if (now.difference(_lastWriteTime) < _throttleInterval) {
      return;
    }

    if (_currentActiveSpeakerId != speakerId) {
      _lastWriteTime = now;
      _currentActiveSpeakerId = speakerId;

      _realtimeDb.ref('activeSpeaker/$roomId').set({
        'activeSpeakerId': speakerId,
        'soundLevel': soundLevel,
        'updatedAt': ServerValue.timestamp,
      });
    }
  }

  /// Stops monitoring, releases listeners, and clears RTDB active speaker state.
  Future<void> stopMonitoring(String roomId) async {
    await ZegoExpressEngine.instance.stopSoundLevelMonitor();
    ZegoExpressEngine.onCapturedSoundLevelUpdate = null;
    ZegoExpressEngine.onRemoteSoundLevelUpdate = null;

    await _activeSpeakerSubscription?.cancel();
    _activeSpeakerSubscription = null;

    _activeSpeakerController.close();
  }
}
