import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../services/zego_service.dart';

/// Active Video Call Screen adhering to FACEO Phase 2 Design System tokens.
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
  // FACEO Design System Color Tokens
  static const Color _bgDeepBlack = Color(0xFF1F1F1F);
  static const Color _cardSurface = Color(0xFF313131);
  static const Color _accentPeriwinkle = Color(0xFFB7BEFE);
  static const Color _accentNeonPink = Color(0xFFFF95DD);
  static const Color _textDark = Color(0xFF1F1F1F);
  static const Color _textLight = Color(0xFFFFFFFF);

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
      // 1. Initialize ZegoCloud Engine Profile
      await _zegoService.createEngineWithProfile(appId: widget.appId);

      // 2. Set listener for room stream updates
      _zegoService.setStreamUpdateListener((roomId, updateType, streamList) {
        _handleStreamUpdate(updateType, streamList);
      });

      // 3. Retrieve authentication token securely via Firebase Cloud Function
      final token = await _zegoService.fetchZegoToken(
        roomId: widget.roomId,
        userId: widget.userId,
      );

      // 4. Log in to room and publish local stream
      await _zegoService.loginRoom(
        roomId: widget.roomId,
        userId: widget.userId,
        userName: widget.userName,
        token: token,
      );

      // 5. Build local video view
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
    // Hardware Cleanup: Logout room and destroy engine on screen pop/disposal
    _zegoService.leaveRoomAndDestroyEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeepBlack,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Tile Canvas Area
            _buildVideoCanvasGrid(),

            // Top Room Header Info
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: _buildHeaderInfo(),
            ),

            // Bottom Control Toolbar
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),

            // Loading / Error Overlay
            if (_isLoading || _errorMessage != null) _buildOverlayState(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCanvasGrid() {
    final allRemoteWidgets = _remoteVideoWidgets.values.toList();

    if (allRemoteWidgets.isEmpty) {
      // Single full-screen local stream preview
      return Container(
        color: _bgDeepBlack,
        child: _isCameraEnabled && _localVideoWidget != null
            ? ClipRRect(
                child: _localVideoWidget!,
              )
            : _buildCameraOffPlaceholder(widget.userName),
      );
    }

    // Grid layout for Multi-party call (Remote feeds + Local PIP preview)
    return Stack(
      children: [
        // Main Remote Video Grid (Borderless)
        GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: allRemoteWidgets.length == 1 ? 1 : 2,
            childAspectRatio: allRemoteWidgets.length == 1 ? 9 / 16 : 1,
          ),
          itemCount: allRemoteWidgets.length,
          itemBuilder: (context, index) {
            return Container(
              color: _cardSurface,
              child: allRemoteWidgets[index],
            );
          },
        ),

        // Floating Local PIP View
        Positioned(
          top: 70,
          right: 16,
          width: 110,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              color: _cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _bgDeepBlack, width: 2),
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
      color: _cardSurface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: isSmall ? 20 : 36,
              backgroundColor: _accentPeriwinkle,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: GoogleFonts.poppins(
                  fontSize: isSmall ? 16 : 24,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ),
            if (!isSmall) ...[
              const SizedBox(height: 12),
              Text(
                '$name (Camera Off)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textLight,
                ),
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
        color: _cardSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
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
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _textLight,
            ),
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
          // Toggle Microphone
          _buildControlButton(
            icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            backgroundColor: _accentPeriwinkle,
            iconColor: _textDark,
            onPressed: _toggleMic,
          ),

          // Toggle Camera
          _buildControlButton(
            icon: _isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            backgroundColor: _accentPeriwinkle,
            iconColor: _textDark,
            onPressed: _toggleCamera,
          ),

          // Switch Front/Rear Camera
          _buildControlButton(
            icon: Icons.flip_camera_ios_rounded,
            backgroundColor: _accentPeriwinkle,
            iconColor: _textDark,
            onPressed: _switchCamera,
          ),

          // End Call Button (Neon Pink)
          _buildControlButton(
            icon: Icons.call_end_rounded,
            backgroundColor: _accentNeonPink,
            iconColor: _textDark,
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
    required VoidCallback onPressed,
    bool isEndCall = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isEndCall ? 64 : 52,
          height: isEndCall ? 64 : 52,
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
    );
  }

  Widget _buildOverlayState() {
    return Container(
      color: _bgDeepBlack.withValues(alpha: 0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_accentPeriwinkle),
                ),
                const SizedBox(height: 20),
                Text(
                  'Connecting to video engine...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(
                  Icons.error_outline_rounded,
                  color: _accentNeonPink,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connection Error',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: _textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _endCall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentNeonPink,
                    foregroundColor: _textDark,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    'Close Call',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
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
