import 'dart:async';
import 'package:flutter/foundation.dart';
import 'network_quality_service.dart';
import 'zego_service.dart';

/// Call session coordinator binding ZegoExpressEngine media stream lifecycle
/// with the NetworkQualityService hysteresis engine for automatic Audio-First Fallback.
class CallSessionController {
  static final CallSessionController _instance = CallSessionController._internal();

  factory CallSessionController() => _instance;

  CallSessionController._internal();

  static CallSessionController get instance => _instance;

  final ZegoService _zegoService = ZegoService();
  final NetworkQualityService _networkQualityService = NetworkQualityService.instance;

  bool _isSessionActive = false;

  /// Returns whether an active call session is coordinated.
  bool get isSessionActive => _isSessionActive;

  /// Reactive notifier for audio-only fallback mode.
  ValueListenable<bool> get isAudioOnlyFallbackActive =>
      _networkQualityService.isAudioOnlyFallbackActive;

  /// Reactive notifier for categorized connection quality tier.
  ValueListenable<NetworkQualityTier> get currentQualityTier =>
      _networkQualityService.currentQualityTier;

  /// Initializes a call session, starts network quality monitoring, and binds hysteresis callbacks.
  Future<void> startSession({
    required String roomId,
    required String userId,
    required String userName,
    required String token,
  }) async {
    if (_isSessionActive) return;

    // Login to Zego room via ZegoService
    await _zegoService.loginRoom(
      roomId: roomId,
      userId: userId,
      userName: userName,
      token: token,
    );

    _isSessionActive = true;

    // Bind NetworkQualityService listener to handle stream video muting during fallback
    _networkQualityService.isAudioOnlyFallbackActive.addListener(_handleFallbackStateChange);

    // Start network QoS monitoring
    _networkQualityService.startMonitoring();
  }

  /// Internal listener responding to audio fallback state changes triggered by hysteresis rules.
  void _handleFallbackStateChange() async {
    final isFallback = _networkQualityService.isAudioOnlyFallbackActive.value;

    if (isFallback) {
      // Degrade Fast: Mute local outgoing video publishing stream while keeping audio active
      await _zegoService.mutePublishStreamVideo(true);
    } else {
      // Recover Slow: Resume local outgoing video publishing stream
      await _zegoService.mutePublishStreamVideo(false);
    }
  }

  /// Ends the active call session, stops quality monitoring, restores stream states, and cleans up resources.
  Future<void> endSession() async {
    if (!_isSessionActive) return;

    _networkQualityService.isAudioOnlyFallbackActive.removeListener(_handleFallbackStateChange);
    _networkQualityService.stopMonitoring();

    await _zegoService.leaveRoomAndDestroyEngine();
    _isSessionActive = false;
  }
}
