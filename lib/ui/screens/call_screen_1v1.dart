import 'package:flutter/material.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../app/theme/design_tokens.dart';
import '../../services/room_service.dart';
import '../../services/zego_service.dart';

/// Dedicated 1-on-1 Video Call Screen utilizing [ZegoCanvas] and FACEO Design Tokens.
/// Features a full-screen remote stream canvas with a floating local PIP canvas.
class CallScreen1v1 extends StatefulWidget {
  final String roomId;
  final String userId;
  final String userName;
  final ZegoService? zegoService;
  final RoomService? roomService;

  const CallScreen1v1({
    super.key,
    required this.roomId,
    required this.userId,
    required this.userName,
    this.zegoService,
    this.roomService,
  });

  @override
  State<CallScreen1v1> createState() => _CallScreen1v1State();
}

class _CallScreen1v1State extends State<CallScreen1v1> {
  late final ZegoService _zegoService;
  late final RoomService _roomService;

  bool _isLoading = true;
  String? _errorMessage;

  Widget? _localVideoCanvas;
  Widget? _remoteVideoCanvas;
  String? _remoteStreamId;

  bool _isMicMuted = false;
  bool _isCameraEnabled = true;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _zegoService = widget.zegoService ?? ZegoService();
    _roomService = widget.roomService ?? RoomService();
    _initializeCallSession();
  }

  Future<void> _initializeCallSession() async {
    try {
      // 1. Join RTDB Presence Node with onDisconnect hooks
      await _roomService.joinRoomPresence(
        roomId: widget.roomId,
        userId: widget.userId,
        userName: widget.userName,
      );

      // 2. Initialize ZegoCloud Engine using dotenv credentials
      await _zegoService.createEngineWithProfile();

      // 3. Listen for stream updates
      _zegoService.setStreamUpdateListener((roomId, updateType, streamList) {
        _handleStreamUpdate(updateType, streamList);
      });

      // 4. Fetch secure token from Cloud Function
      final token = await _zegoService.fetchZegoToken(
        roomId: widget.roomId,
        userId: widget.userId,
      );

      // 5. Login room and publish stream
      await _zegoService.loginRoom(
        roomId: widget.roomId,
        userId: widget.userId,
        userName: widget.userName,
        token: token,
      );

      // 6. Build local canvas
      final localCanvas = await _zegoService.createLocalCanvasView();

      if (mounted) {
        setState(() {
          _localVideoCanvas = localCanvas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleStreamUpdate(ZegoUpdateType updateType, List<ZegoStream> streamList) async {
    if (updateType == ZegoUpdateType.Add && streamList.isNotEmpty) {
      final stream = streamList.first;
      final remoteWidget = await _zegoService.createRemoteCanvasView(
        streamId: stream.streamID,
      );
      if (mounted) {
        setState(() {
          _remoteStreamId = stream.streamID;
          _remoteVideoCanvas = remoteWidget;
        });
      }
    } else if (updateType == ZegoUpdateType.Delete) {
      for (final stream in streamList) {
        if (stream.streamID == _remoteStreamId) {
          await _zegoService.stopPlayingStream(stream.streamID);
          if (mounted) {
            setState(() {
              _remoteStreamId = null;
              _remoteVideoCanvas = null;
            });
          }
        }
      }
    }
  }

  Future<void> _toggleMic() async {
    final newMute = !_isMicMuted;
    await _zegoService.muteMicrophone(newMute);
    if (mounted) setState(() => _isMicMuted = newMute);
  }

  Future<void> _toggleCamera() async {
    final newCameraState = !_isCameraEnabled;
    await _zegoService.enableCamera(newCameraState);
    if (mounted) setState(() => _isCameraEnabled = newCameraState);
  }

  Future<void> _switchCamera() async {
    final newFrontState = !_isFrontCamera;
    await _zegoService.useFrontCamera(newFrontState);
    if (mounted) setState(() => _isFrontCamera = newFrontState);
  }

  Future<void> _endCall() async {
    await _roomService.leaveRoomPresence(
      roomId: widget.roomId,
      userId: widget.userId,
    );
    await _zegoService.leaveRoomAndDestroyEngine();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _roomService.leaveRoomPresence(
      roomId: widget.roomId,
      userId: widget.userId,
    );
    _zegoService.leaveRoomAndDestroyEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.bgDeepBlack,
      body: SafeArea(
        child: Stack(
          children: [
            // Main 1v1 Stream Surface (Remote Feed or Fullscreen Local)
            _buildMainSurface(),

            // Top Status Bar
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: _buildHeaderBar(),
            ),

            // Bottom Call Controls
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: _buildControlsToolbar(),
            ),

            // Loading / Error Overlay
            if (_isLoading || _errorMessage != null) _buildOverlayState(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSurface() {
    if (_remoteVideoCanvas != null) {
      // 1v1 Mode: Fullscreen Remote Feed + Floating Local PIP
      return Stack(
        children: [
          // Fullscreen Remote Video Canvas
          Positioned.fill(
            child: Container(
              color: DesignTokens.bgDeepBlack,
              child: _remoteVideoCanvas!,
            ),
          ),

          // Floating Local PIP Window
          Positioned(
            top: 70,
            right: 16,
            width: 110,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                color: DesignTokens.cardSurface,
                borderRadius: DesignTokens.radiusCard,
                border: Border.all(color: DesignTokens.bgDeepBlack, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isCameraEnabled && _localVideoCanvas != null
                  ? _localVideoCanvas!
                  : _buildAvatarPlaceholder(widget.userName, isSmall: true),
            ),
          ),
        ],
      );
    }

    // Waiting for peer: Fullscreen local video
    return Container(
      color: DesignTokens.bgDeepBlack,
      child: _isCameraEnabled && _localVideoCanvas != null
          ? _localVideoCanvas!
          : _buildAvatarPlaceholder(widget.userName),
    );
  }

  Widget _buildAvatarPlaceholder(String name, {bool isSmall = false}) {
    return Container(
      color: DesignTokens.cardSurface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: isSmall ? 20 : 36,
              backgroundColor: DesignTokens.accentPeriwinkle,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: DesignTokens.headlineMedium.copyWith(
                  color: DesignTokens.textDark,
                  fontSize: isSmall ? 16 : 24,
                ),
              ),
            ),
            if (!isSmall) ...[
              const SizedBox(height: 12),
              Text(
                'Waiting for peer to join...',
                style: DesignTokens.bodySecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.cardSurface.withValues(alpha: 0.85),
        borderRadius: DesignTokens.radiusPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _remoteVideoCanvas != null ? Colors.greenAccent : Colors.amberAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _remoteVideoCanvas != null ? '1-on-1 Call Active' : 'Connecting Room: ${widget.roomId}',
            style: DesignTokens.caption.copyWith(color: DesignTokens.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          backgroundColor: DesignTokens.accentPeriwinkle,
          onPressed: _toggleMic,
        ),
        _buildControlButton(
          icon: _isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          backgroundColor: DesignTokens.accentPeriwinkle,
          onPressed: _toggleCamera,
        ),
        _buildControlButton(
          icon: Icons.flip_camera_ios_rounded,
          backgroundColor: DesignTokens.accentPeriwinkle,
          onPressed: _switchCamera,
        ),
        _buildControlButton(
          icon: Icons.call_end_rounded,
          backgroundColor: DesignTokens.accentNeonPink,
          isEndCall: true,
          onPressed: _endCall,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool isEndCall = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: DesignTokens.radiusPill,
      child: Container(
        width: isEndCall ? 64 : 52,
        height: isEndCall ? 64 : 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: isEndCall ? 28 : 22,
          color: DesignTokens.textDark,
        ),
      ),
    );
  }

  Widget _buildOverlayState() {
    return Container(
      color: DesignTokens.bgDeepBlack.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading) ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.accentPeriwinkle),
              ),
              const SizedBox(height: 20),
              Text(
                'Initializing 1-on-1 Session...',
                style: DesignTokens.bodyMedium,
              ),
            ] else if (_errorMessage != null) ...[
              const Icon(Icons.error_outline_rounded, color: DesignTokens.accentNeonPink, size: 48),
              const SizedBox(height: 16),
              Text('Connection Error', style: DesignTokens.headlineMedium),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: DesignTokens.caption, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _endCall,
                style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.accentNeonPink),
                child: const Text('Close Session'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
