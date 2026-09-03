import 'package:faceo/services/network_quality_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.zego.im/zego_express_engine'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  late NetworkQualityService service;

  setUp(() {
    service = NetworkQualityService.instance;
    service.resetState();
  });

  group('NetworkQualityService Hysteresis Unit Tests', () {
    test('Degrade Fast: Requires > 2 consecutive Bad/Die readings before triggering fallback', () {
      expect(service.isAudioOnlyFallbackActive.value, isFalse);

      // 1st Bad reading (counter = 1) -> Fallback remains false
      service.processQualityUpdate(
        'stream_1',
        ZegoStreamQualityLevel.Bad,
        ZegoStreamQualityLevel.Good,
      );
      expect(service.isAudioOnlyFallbackActive.value, isFalse);
      expect(service.currentQualityTier.value, equals(NetworkQualityTier.critical));

      // 2nd Bad reading (counter = 2) -> Fallback remains false
      service.processQualityUpdate(
        'stream_1',
        ZegoStreamQualityLevel.Bad,
        ZegoStreamQualityLevel.Bad,
      );
      expect(service.isAudioOnlyFallbackActive.value, isFalse);

      // 3rd Bad reading (counter = 3, > 2) -> Fallback IMMEDIATELY triggers true
      service.processQualityUpdate(
        'stream_1',
        ZegoStreamQualityLevel.Die,
        ZegoStreamQualityLevel.Bad,
      );
      expect(service.isAudioOnlyFallbackActive.value, isTrue);
    });

    test('Recover Slow: Requires exactly 5 consecutive Excellent readings before exiting fallback', () {
      // 1. Force state into fallback mode via 3 Bad readings
      for (int i = 0; i < 3; i++) {
        service.processQualityUpdate(
          'stream_1',
          ZegoStreamQualityLevel.Bad,
          ZegoStreamQualityLevel.Bad,
        );
      }
      expect(service.isAudioOnlyFallbackActive.value, isTrue);

      // 2. Send 1 to 4 consecutive Excellent readings -> Fallback MUST remain true (anti-flicker protection)
      for (int count = 1; count <= 4; count++) {
        service.processQualityUpdate(
          'stream_1',
          ZegoStreamQualityLevel.Excellent,
          ZegoStreamQualityLevel.Excellent,
        );
        expect(
          service.isAudioOnlyFallbackActive.value,
          isTrue,
          reason: 'Fallback should remain active on Excellent reading #$count',
        );
      }

      // 3. Send 5th consecutive Excellent reading -> Fallback MUST exit to false
      service.processQualityUpdate(
        'stream_1',
        ZegoStreamQualityLevel.Excellent,
        ZegoStreamQualityLevel.Excellent,
      );
      expect(service.isAudioOnlyFallbackActive.value, isFalse);
      expect(service.currentQualityTier.value, equals(NetworkQualityTier.good));
    });

    test('Anti-Flicker Interruption: Non-excellent reading resets recovery counter', () {
      // Enter fallback mode
      for (int i = 0; i < 3; i++) {
        service.processQualityUpdate(
          'stream_1',
          ZegoStreamQualityLevel.Bad,
          ZegoStreamQualityLevel.Bad,
        );
      }
      expect(service.isAudioOnlyFallbackActive.value, isTrue);

      // Send 4 Excellent readings (1 step away from recovery)
      for (int i = 0; i < 4; i++) {
        service.processQualityUpdate(
          'stream_1',
          ZegoStreamQualityLevel.Excellent,
          ZegoStreamQualityLevel.Excellent,
        );
      }
      expect(service.isAudioOnlyFallbackActive.value, isTrue);

      // Send a Medium (poor) reading -> Resets recovery counter
      service.processQualityUpdate(
        'stream_1',
        ZegoStreamQualityLevel.Medium,
        ZegoStreamQualityLevel.Good,
      );
      expect(service.isAudioOnlyFallbackActive.value, isTrue);
      expect(service.currentQualityTier.value, equals(NetworkQualityTier.poor));

      // Send 4 Excellent readings again -> Still in fallback because counter was reset
      for (int i = 0; i < 4; i++) {
        service.processQualityUpdate(
          'stream_1',
          ZegoStreamQualityLevel.Excellent,
          ZegoStreamQualityLevel.Excellent,
        );
        expect(service.isAudioOnlyFallbackActive.value, isTrue);
      }

      // 5th consecutive Excellent reading after reset -> Now recovers
      service.processQualityUpdate(
        'stream_1',
        ZegoStreamQualityLevel.Excellent,
        ZegoStreamQualityLevel.Excellent,
      );
      expect(service.isAudioOnlyFallbackActive.value, isFalse);
    });

    test('Degradation Interruption: Good reading resets bad counter before threshold', () {
      expect(service.isAudioOnlyFallbackActive.value, isFalse);

      // 2 Bad readings (threshold is > 2)
      service.processQualityUpdate('stream_1', ZegoStreamQualityLevel.Bad, ZegoStreamQualityLevel.Bad);
      service.processQualityUpdate('stream_1', ZegoStreamQualityLevel.Bad, ZegoStreamQualityLevel.Bad);
      expect(service.isAudioOnlyFallbackActive.value, isFalse);

      // Interrupted by a Good reading
      service.processQualityUpdate('stream_1', ZegoStreamQualityLevel.Good, ZegoStreamQualityLevel.Good);
      expect(service.isAudioOnlyFallbackActive.value, isFalse);
      expect(service.currentQualityTier.value, equals(NetworkQualityTier.good));

      // Requires 3 NEW consecutive Bad readings to trigger fallback
      service.processQualityUpdate('stream_1', ZegoStreamQualityLevel.Bad, ZegoStreamQualityLevel.Bad);
      service.processQualityUpdate('stream_1', ZegoStreamQualityLevel.Bad, ZegoStreamQualityLevel.Bad);
      expect(service.isAudioOnlyFallbackActive.value, isFalse);

      service.processQualityUpdate('stream_1', ZegoStreamQualityLevel.Bad, ZegoStreamQualityLevel.Bad);
      expect(service.isAudioOnlyFallbackActive.value, isTrue);
    });
  });
}
