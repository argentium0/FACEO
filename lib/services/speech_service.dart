import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Singleton service wrapping on-device Speech-to-Text (`speech_to_text`) recognition engine.
/// Exposes real-time recognized word transcripts via reactive [ValueNotifier] properties.
/// Handles permission checks, device availability, and recognition errors gracefully.
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();

  factory SpeechService() => _instance;

  SpeechService._internal();

  static SpeechService get instance => _instance;

  final SpeechToText _speech = SpeechToText();

  /// Real-time recognized transcript string.
  final ValueNotifier<String> recognizedText = ValueNotifier<String>('');

  /// Active listening status.
  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);

  /// Device speech recognition engine availability state.
  final ValueNotifier<bool> isAvailable = ValueNotifier<bool>(false);

  /// Error message state for graceful UI error handling.
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  bool _isInitialized = false;

  /// Returns whether speech service initialization completed.
  bool get isInitialized => _isInitialized;

  /// Initializes the on-device speech recognition engine and requests permissions.
  Future<bool> initialize() async {
    if (_isInitialized) return isAvailable.value;

    try {
      final available = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );

      _isInitialized = true;
      isAvailable.value = available;

      if (!available) {
        errorMessage.value = 'On-device speech recognition is unavailable on this device.';
      } else {
        errorMessage.value = null;
      }

      return available;
    } catch (e) {
      _isInitialized = false;
      isAvailable.value = false;
      errorMessage.value = 'Failed to initialize speech service: $e';
      return false;
    }
  }

  /// Starts listening to the microphone for live speech input and updates [recognizedText].
  Future<void> startListening({String localeId = 'en_US'}) async {
    if (!_isInitialized || !isAvailable.value) {
      final ok = await initialize();
      if (!ok) return;
    }

    if (_speech.isListening) return;

    errorMessage.value = null;
    recognizedText.value = '';

    try {
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          cancelOnError: false,
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
      );
      isListening.value = true;
    } catch (e) {
      isListening.value = false;
      errorMessage.value = 'Error starting speech listening: $e';
    }
  }

  /// Safely stops listening and releases active microphone listening.
  Future<void> stopListening() async {
    if (!_speech.isListening && !isListening.value) return;

    try {
      await _speech.stop();
    } catch (e) {
      errorMessage.value = 'Error stopping speech listening: $e';
    } finally {
      isListening.value = false;
    }
  }

  /// Cancels active listening session immediately.
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (_) {
    } finally {
      isListening.value = false;
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    recognizedText.value = result.recognizedWords;
  }

  void _handleError(SpeechRecognitionError error) {
    // Graceful error logging without crashing
    errorMessage.value = 'Speech Recognition Error: ${error.errorMsg}';
    if (error.permanent) {
      isListening.value = false;
    }
  }

  void _handleStatus(String status) {
    if (status == 'listening') {
      isListening.value = true;
    } else if (status == 'notListening' || status == 'done') {
      isListening.value = false;
    }
  }

  /// Clears active transcript and error states.
  void clear() {
    recognizedText.value = '';
    errorMessage.value = null;
  }
}
