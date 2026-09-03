import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

/// Callback typedef for stream updates in a room.
typedef StreamUpdateCallback = void Function(
  String roomId,
  ZegoUpdateType updateType,
  List<ZegoStream> streamList,
);

/// Singleton service managing ZegoCloud RTC Engine lifecycle, authentication token
/// retrieval via Firebase Cloud Functions, room entry, media stream publishing/playing,
/// and hardware resource cleanup.
class ZegoService {
  static final ZegoService _instance = ZegoService._internal();

  factory ZegoService() => _instance;

  ZegoService._internal();

  bool _isEngineInitialized = false;
  String? _currentRoomId;
  String? _currentUserId;
  String? _currentStreamId;

  StreamUpdateCallback? _onStreamUpdateListener;

  /// Exposes initialization state.
  bool get isEngineInitialized => _isEngineInitialized;

  /// Current active Room ID.
  String? get currentRoomId => _currentRoomId;

  /// Current active User ID.
  String? get currentUserId => _currentUserId;

  /// Current active local Stream ID.
  String? get currentStreamId => _currentStreamId;

  /// Ensures environment variable configuration is loaded via [flutter_dotenv].
  Future<void> ensureEnvLoaded() async {
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: '.env');
    }
  }

  /// Sets an active listener for room stream updates.
  void setStreamUpdateListener(StreamUpdateCallback listener) {
    _onStreamUpdateListener = listener;
  }

  /// Initializes the ZegoCloud Express Engine singleton dynamically reading
  /// [appId] and [appSign] from environment configuration (.env) loaded via [flutter_dotenv].
  Future<void> createEngineWithProfile({
    int? appId,
    String? appSign,
    ZegoScenario scenario = ZegoScenario.StandardVideoCall,
  }) async {
    if (_isEngineInitialized) return;

    await ensureEnvLoaded();

    final resolvedAppId = appId ?? int.tryParse(dotenv.env['ZEGO_APP_ID'] ?? '');
    final resolvedAppSign = appSign ?? dotenv.env['ZEGO_APP_SIGN'] ?? '';

    if (resolvedAppId == null || resolvedAppId == 0) {
      throw StateError(
        'Invalid or missing ZEGO_APP_ID in environment configuration (.env file).',
      );
    }

    final profile = ZegoEngineProfile(
      resolvedAppId,
      scenario,
      appSign: resolvedAppSign,
    );

    await ZegoExpressEngine.createEngineWithProfile(profile);
    _isEngineInitialized = true;

    // Register engine stream update event callbacks
    ZegoExpressEngine.onRoomStreamUpdate = (
      String roomId,
      ZegoUpdateType updateType,
      List<ZegoStream> streamList,
      Map<String, dynamic> extendedData,
    ) {
      if (_onStreamUpdateListener != null) {
        _onStreamUpdateListener!(roomId, updateType, streamList);
      }
    };
  }

  /// Fetches a secure ZegoCloud Token 04 from Firebase Cloud Functions.
  Future<String> fetchZegoToken({
    required String roomId,
    required String userId,
    int effectiveTimeInSeconds = 3600,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('generateZegoToken');
    final response = await callable.call<Map<String, dynamic>>({
      'roomId': roomId,
      'userId': userId,
      'effectiveTimeInSeconds': effectiveTimeInSeconds,
    });

    final data = response.data;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Failed to retrieve valid ZegoCloud token from backend Cloud Function.');
    }

    return token;
  }

  /// Logs into the specified ZegoCloud Room using a server-generated Token
  /// and immediately initiates local stream publishing.
  Future<void> loginRoom({
    required String roomId,
    required String userId,
    required String userName,
    required String token,
  }) async {
    if (!_isEngineInitialized) {
      throw StateError('ZegoExpressEngine must be initialized before calling loginRoom.');
    }

    _currentRoomId = roomId;
    _currentUserId = userId;

    final user = ZegoUser(userId, userName);
    final config = ZegoRoomConfig(0, true, token);

    await ZegoExpressEngine.instance.loginRoom(roomId, user, config: config);

    // Publish local stream immediately after login
    _currentStreamId = '${roomId}_${userId}_main';
    await startPublishingStream(_currentStreamId!);
  }

  /// Starts publishing local audio/video stream.
  Future<void> startPublishingStream(String streamId) async {
    await ZegoExpressEngine.instance.startPublishingStream(streamId);
  }

  /// Creates a local video canvas view widget.
  Future<Widget?> createLocalCanvasView({
    ZegoViewMode viewMode = ZegoViewMode.AspectFill,
  }) async {
    return await ZegoExpressEngine.instance.createCanvasView((viewId) {
      final canvas = ZegoCanvas(viewId, viewMode: viewMode);
      ZegoExpressEngine.instance.startPreview(canvas: canvas);
    });
  }

  /// Creates a remote video canvas view widget for rendering another user's stream.
  Future<Widget?> createRemoteCanvasView({
    required String streamId,
    ZegoViewMode viewMode = ZegoViewMode.AspectFill,
  }) async {
    return await ZegoExpressEngine.instance.createCanvasView((viewId) {
      final canvas = ZegoCanvas(viewId, viewMode: viewMode);
      ZegoExpressEngine.instance.startPlayingStream(streamId, canvas: canvas);
    });
  }

  /// Stops playing a remote stream.
  Future<void> stopPlayingStream(String streamId) async {
    await ZegoExpressEngine.instance.stopPlayingStream(streamId);
  }

  /// Toggles local microphone mute state.
  Future<void> muteMicrophone(bool mute) async {
    await ZegoExpressEngine.instance.muteMicrophone(mute);
  }

  /// Toggles local camera enable state.
  Future<void> enableCamera(bool enable) async {
    await ZegoExpressEngine.instance.enableCamera(enable);
  }

  /// Switches between front and rear cameras.
  Future<void> useFrontCamera(bool useFront) async {
    await ZegoExpressEngine.instance.useFrontCamera(useFront);
  }

  /// Logs out of current room, stops stream publishing/playing, and releases engine resources.
  Future<void> leaveRoomAndDestroyEngine() async {
    if (_currentRoomId != null) {
      await ZegoExpressEngine.instance.stopPublishingStream();
      await ZegoExpressEngine.instance.logoutRoom(_currentRoomId!);
      _currentRoomId = null;
      _currentUserId = null;
      _currentStreamId = null;
    }

    _onStreamUpdateListener = null;

    if (_isEngineInitialized) {
      await ZegoExpressEngine.destroyEngine();
      _isEngineInitialized = false;
    }
  }
}
