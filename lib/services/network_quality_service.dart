import 'package:flutter/foundation.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

/// Network connection quality tier categorization.
enum NetworkQualityTier {
  good,
  poor,
  critical,
}

/// Core Quality of Service (QoS) and Hysteresis Engine for FACEO Audio-First Fallback.
///
/// Listens to ZegoCloud stream quality callbacks and manages dynamic state transitions
/// with hysteresis rules to avoid rapid/jarring video stream toggling:
/// - **Degrade Fast:** Triggers audio fallback after > 2 consecutive Bad or Die readings.
/// - **Recover Slow:** Exits audio fallback only after >= 5 consecutive Excellent readings.
class NetworkQualityService {
  static final NetworkQualityService _instance = NetworkQualityService._internal();

  factory NetworkQualityService() => _instance;

  NetworkQualityService._internal();

  static NetworkQualityService get instance => _instance;

  /// Reactive notifier for audio-only fallback state.
  final ValueNotifier<bool> isAudioOnlyFallbackActive = ValueNotifier<bool>(false);

  /// Reactive notifier for categorized quality tier.
  final ValueNotifier<NetworkQualityTier> currentQualityTier =
      ValueNotifier<NetworkQualityTier>(NetworkQualityTier.good);

  /// Reactive notifier for last reported downstream (rx) quality.
  final ValueNotifier<ZegoStreamQualityLevel> lastRxQuality =
      ValueNotifier<ZegoStreamQualityLevel>(ZegoStreamQualityLevel.Excellent);

  /// Reactive notifier for last reported upstream (tx) quality.
  final ValueNotifier<ZegoStreamQualityLevel> lastTxQuality =
      ValueNotifier<ZegoStreamQualityLevel>(ZegoStreamQualityLevel.Excellent);

  int _consecutiveBadReadings = 0;
  int _consecutiveExcellentReadings = 0;

  bool _isMonitoring = false;

  /// Returns whether QoS monitoring is currently active.
  bool get isMonitoring => _isMonitoring;

  /// Starts listening to ZegoExpressEngine network quality callbacks.
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    ZegoExpressEngine.onNetworkQuality = (
      String streamID,
      ZegoStreamQualityLevel rxQuality,
      ZegoStreamQualityLevel txQuality,
    ) {
      processQualityUpdate(streamID, rxQuality, txQuality);
    };
  }

  /// Stops listening to network quality callbacks and resets internal state counters.
  void stopMonitoring() {
    _isMonitoring = false;
    ZegoExpressEngine.onNetworkQuality = null;
    resetState();
  }

  /// Processes network quality updates per stream and applies hysteresis threshold logic.
  void processQualityUpdate(
    String streamID,
    ZegoStreamQualityLevel rxQuality,
    ZegoStreamQualityLevel txQuality,
  ) {
    lastRxQuality.value = rxQuality;
    lastTxQuality.value = txQuality;

    final worstQuality = _determineWorstQuality(rxQuality, txQuality);
    final tier = _categorizeTier(worstQuality);
    currentQualityTier.value = tier;

    if (isAudioOnlyFallbackActive.value) {
      // Currently in fallback mode — check for recovery conditions
      if (rxQuality == ZegoStreamQualityLevel.Excellent &&
          txQuality == ZegoStreamQualityLevel.Excellent) {
        _consecutiveExcellentReadings++;
        _consecutiveBadReadings = 0;

        // Recover Slow: Require at least 5 consecutive Excellent readings (~10-12s)
        if (_consecutiveExcellentReadings >= 5) {
          isAudioOnlyFallbackActive.value = false;
          _consecutiveExcellentReadings = 0;
        }
      } else {
        // Any non-excellent reading resets recovery progress
        _consecutiveExcellentReadings = 0;
      }
    } else {
      // Currently in normal (video) mode — check for degradation conditions
      if (worstQuality == ZegoStreamQualityLevel.Bad ||
          worstQuality == ZegoStreamQualityLevel.Die) {
        _consecutiveBadReadings++;
        _consecutiveExcellentReadings = 0;

        // Degrade Fast: More than 2 consecutive Bad/Die readings (> 2, i.e. >= 3)
        if (_consecutiveBadReadings > 2) {
          isAudioOnlyFallbackActive.value = true;
          _consecutiveBadReadings = 0;
        }
      } else {
        // Quality improved before threshold was met
        _consecutiveBadReadings = 0;
      }
    }
  }

  /// Resets internal counters and sets fallback to false.
  void resetState() {
    _consecutiveBadReadings = 0;
    _consecutiveExcellentReadings = 0;
    isAudioOnlyFallbackActive.value = false;
    currentQualityTier.value = NetworkQualityTier.good;
    lastRxQuality.value = ZegoStreamQualityLevel.Excellent;
    lastTxQuality.value = ZegoStreamQualityLevel.Excellent;
  }

  /// Maps stream quality level to NetworkQualityTier.
  NetworkQualityTier _categorizeTier(ZegoStreamQualityLevel level) {
    switch (level) {
      case ZegoStreamQualityLevel.Excellent:
      case ZegoStreamQualityLevel.Good:
        return NetworkQualityTier.good;
      case ZegoStreamQualityLevel.Medium:
        return NetworkQualityTier.poor;
      case ZegoStreamQualityLevel.Bad:
      case ZegoStreamQualityLevel.Die:
        return NetworkQualityTier.critical;
      case ZegoStreamQualityLevel.Unknown:
        return NetworkQualityTier.good;
    }
  }

  /// Helper to pick the worse of rx or tx stream quality.
  ZegoStreamQualityLevel _determineWorstQuality(
    ZegoStreamQualityLevel rx,
    ZegoStreamQualityLevel tx,
  ) {
    return rx.index > tx.index ? rx : tx;
  }
}
