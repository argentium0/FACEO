import 'package:flutter/material.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../app/theme/design_tokens.dart';
import '../../services/zego_service.dart';

/// Active Video Call Screen adhering strictly to FACEO Design System tokens.
///
/// Features:
/// - Deep Black (#1F1F1F) canvas background
/// - Borderless responsive video tile grid for local and remote streams
/// - Periwinkle (#B7BEFE) control toggles for Microphone, Camera, and Camera Flip
/// - Neon Pink (#FF95DD) End Call button
/// - Automatic hardware cleanup via [ZegoService.leaveRoomAndDestroyEngine] in [dispose]
class ActiveCallScreen extends StatefulWidget {
  final String roomId;
  final String userId;
  final String userName;
  final int? appId;
  final ZegoService? zegoService;

  const ActiveCallScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.userName,
    this.appId,
    this.zegoService,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  late final ZegoService _zegoService;

  bool _isLoading = true;
  String? _errorMessage;

  Widget? _localVideoWidget;
  final Map<String, Widget> _remoteVideoWidgets = {};

  bool _isMicMuted = false;
  bool _isCameraEnabled = true;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _zegoService = widget.zegoService ?? ZegoService();
    _initializeAndJoinRoom();
  }

  Future<void> _initializeAndJoinRoom() async {
    try {
      await _zegoService.createEngineWithProfile(appId: widget.appId);

      _zegoService.setStreamUpdateListener((roomId, updateType, streamList) {
        _handleStreamUpdate(updateType, streamList);
      });

      final token = await _zegoService.fetchZegoToken(
        roomId: widget.roomId,
        userId: widget.userId,
      );

      await _zegoService.loginRoom(
        roomId: widget.roomId,
        userId: widget.userId,
        userName: widget.userName,
        token: token,
      );

      final localWidget = await _zegoService.createLocalCanvasView();

      if (mounted) {
        setState(() {
          _localVideoWidget = localWidget;
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
    if (updateType == ZegoUpdateType.Add) {
      for (final stream in streamList) {
        final remoteWidget = await _zegoService.createRemoteCanvasView(
          streamId: stream.streamID,
        );
        if (remoteWidget != null && mounted) {
          setState(() {
            _remoteVideoWidgets[stream.streamID] = remoteWidget;
          });
        }
      }
    } else if (updateType == ZegoUpdateType.Delete) {
      for (final stream in streamList) {
        await _zegoService.stopPlayingStream(stream.streamID);
        if (mounted) {
          setState(() {
            _remoteVideoWidgets.remove(stream.streamID);
          });
        }
      }
    }
  }

  Future<void> _toggleMic() async {
    final newMuteState = !_isMicMuted;
    await _zegoService.muteMicrophone(newMuteState);
    if (mounted) {
      setState(() {
        _isMicMuted = newMuteState;
      });
    }
  }

  Future<void> _toggleCamera() async {
    final newCameraState = !_isCameraEnabled;
    await _zegoService.enableCamera(newCameraState);
    if (mounted) {
      setState(() {
        _isCameraEnabled = newCameraState;
      });
    }
  }

  Future<void> _switchCamera() async {
    final newFrontState = !_isFrontCamera;
    await _zegoService.useFrontCamera(newFrontState);
    if (mounted) {
      setState(() {
        _isFrontCamera = newFrontState;
      });
    }
  }

  Future<void> _endCall() async {
    await _zegoService.leaveRoomAndDestroyEngine();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
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
            _buildVideoCanvasGrid(),
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: _buildHeaderInfo(),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),
            if (_isLoading || _errorMessage != null) _buildOverlayState(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCanvasGrid() {
    final allRemoteWidgets = _remoteVideoWidgets.values.toList();

    if (allRemoteWidgets.isEmpty) {
      return Container(
        color: DesignTokens.bgDeepBlack,
        child: _isCameraEnabled && _localVideoWidget != null
            ? ClipRRect(
                child: _localVideoWidget!,
              )
            : _buildCameraOffPlaceholder(widget.userName),
      );
    }

    return Stack(
      children: [
        GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: allRemoteWidgets.length == 1 ? 1 : 2,
            childAspectRatio: allRemoteWidgets.length == 1 ? 9 / 16 : 1,
          ),
          itemCount: allRemoteWidgets.length,
          itemBuilder: (context, index) {
            return Container(
              color: DesignTokens.cardSurface,
              child: allRemoteWidgets[index],
            );
          },
        ),
        Positioned(
          top: 70,
          right: 16,
          width: 110,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              color: DesignTokens.cardSurface,
              borderRadius: DesignTokens.radiusCard,
              border: const Border(
                top: BorderSide(color: DesignTokens.bgDeepBlack, width: 2),
                bottom: BorderSide(color: DesignTokens.bgDeepBlack, width: 2),
                left: BorderSide(color: DesignTokens.bgDeepBlack, width: 2),
                right: BorderSide(color: DesignTokens.bgDeepBlack, width: 2),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isCameraEnabled && _localVideoWidget != null
                ? _localVideoWidget!
                : _buildCameraOffPlaceholder(widget.userName, isSmall: true),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraOffPlaceholder(String name, {bool isSmall = false}) {
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
                '$name (Camera Off)',
                style: DesignTokens.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
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
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Room: ${widget.roomId}',
            style: DesignTokens.caption.copyWith(color: DesignTokens.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            backgroundColor: DesignTokens.accentPeriwinkle,
            iconColor: DesignTokens.textDark,
            semanticLabel: 'Mute Microphone',
            semanticHint: _isMicMuted ? 'Unmute microphone audio' : 'Mute microphone audio',
            isToggled: _isMicMuted,
            onPressed: _toggleMic,
          ),
          _buildControlButton(
            icon: _isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            backgroundColor: DesignTokens.accentPeriwinkle,
            iconColor: DesignTokens.textDark,
            semanticLabel: 'Camera Toggle',
            semanticHint: _isCameraEnabled ? 'Turn camera off' : 'Turn camera on',
            isToggled: !_isCameraEnabled,
            onPressed: _toggleCamera,
          ),
          _buildControlButton(
            icon: Icons.flip_camera_ios_rounded,
            backgroundColor: DesignTokens.accentPeriwinkle,
            iconColor: DesignTokens.textDark,
            semanticLabel: 'Flip Camera',
            semanticHint: 'Switch between front and rear cameras',
            onPressed: _switchCamera,
          ),
          _buildControlButton(
            icon: Icons.call_end_rounded,
            backgroundColor: DesignTokens.accentNeonPink,
            iconColor: DesignTokens.textDark,
            semanticLabel: 'End Call',
            semanticHint: 'Disconnect from video room and leave session',
            isEndCall: true,
            onPressed: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required String semanticLabel,
    required String semanticHint,
    required VoidCallback onPressed,
    bool isEndCall = false,
    bool? isToggled,
  }) {
    final double size = isEndCall ? 64.0 : 52.0;
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      enabled: true,
      toggled: isToggled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: DesignTokens.radiusPill,
            splashColor: DesignTokens.textDark.withValues(alpha: 0.15),
            highlightColor: DesignTokens.textDark.withValues(alpha: 0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isEndCall ? 28 : 22,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayState() {
    return Container(
      color: DesignTokens.bgDeepBlack.withValues(alpha: 0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.accentPeriwinkle),
                ),
                const SizedBox(height: 20),
                Text(
                  'Connecting to video engine...',
                  style: DesignTokens.bodyMedium,
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(
                  Icons.error_outline_rounded,
                  color: DesignTokens.accentNeonPink,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connection Error',
                  style: DesignTokens.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: DesignTokens.caption.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _endCall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.accentNeonPink,
                    foregroundColor: DesignTokens.textDark,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    'Close Call',
                    style: DesignTokens.buttonTextDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
