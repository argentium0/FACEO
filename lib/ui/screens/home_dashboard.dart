import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../services/room_sweeper_service.dart';
import '../widgets/faceo_logo.dart';
import 'active_call_screen.dart';
import 'call_screen_1v1.dart';

/// Re-balanced, Minimalist Home Dashboard adhering strictly to FACEO Design Tokens.
/// Features a structured Quick Actions layout, welcoming headline, programmatic logo integration,
/// and interactive modal bottom sheet for joining active rooms.
class HomeDashboard extends StatefulWidget {
  final AuthService? authService;
  final RoomService? roomService;

  const HomeDashboard({
    super.key,
    this.authService,
    this.roomService,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  late final AuthService _authService;
  late final RoomService _roomService;

  final TextEditingController _modalRoomIdController = TextEditingController();
  bool _isCreatingRoom = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _roomService = widget.roomService ?? RoomService();
    // Background sweep to clean up expired rooms quietly
    RoomSweeperService().sweepExpiredRooms();
  }

  @override
  void dispose() {
    _modalRoomIdController.dispose();
    super.dispose();
  }

  Future<void> _createAndJoinRoom({bool isGroup = false}) async {
    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid ?? 'user-guest-${DateTime.now().millisecondsSinceEpoch % 1000}';
    final userName = currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'Guest User';

    setState(() => _isCreatingRoom = true);

    try {
      final roomId = await _roomService.createRoom(
        hostUserId: userId,
        title: isGroup ? 'Group Video Session' : '1-on-1 Call',
        isGroupCall: isGroup,
      );

      if (!mounted) return;

      setState(() => _isCreatingRoom = false);

      if (isGroup) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ActiveCallScreen(
              roomId: roomId,
              userId: userId,
              userName: userName,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen1v1(
              roomId: roomId,
              userId: userId,
              userName: userName,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingRoom = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create room: ${e.toString()}'),
          backgroundColor: DesignTokens.accentNeonPink,
        ),
      );
    }
  }

  void _joinExistingRoom(String roomId) {
    final trimmedId = roomId.trim();
    if (trimmedId.isEmpty) return;

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid ?? 'user-guest-${DateTime.now().millisecondsSinceEpoch % 1000}';
    final userName = currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'Guest User';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen1v1(
          roomId: trimmedId,
          userId: userId,
          userName: userName,
        ),
      ),
    );
  }

  void _showJoinRoomModal() {
    _modalRoomIdController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignTokens.textSecondary.withValues(alpha: 0.4),
                    borderRadius: DesignTokens.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Join Active Room',
                style: DesignTokens.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the ephemeral room code shared by your peer.',
                style: DesignTokens.caption,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _modalRoomIdController,
                style: DesignTokens.bodyMedium,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter room code (e.g. room-892)...',
                  hintStyle: DesignTokens.bodySecondary,
                  filled: true,
                  fillColor: DesignTokens.bgDeepBlack,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: DesignTokens.accentPeriwinkle, width: 1.5),
                  ),
                ),
                onSubmitted: (val) {
                  Navigator.of(ctx).pop();
                  _joinExistingRoom(val);
                },
              ),
              const SizedBox(height: 24),
              Semantics(
                label: 'Submit Room Code',
                button: true,
                child: ElevatedButton(
                  onPressed: () {
                    final code = _modalRoomIdController.text;
                    Navigator.of(ctx).pop();
                    _joinExistingRoom(code);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.accentNeonPink,
                    foregroundColor: DesignTokens.textDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Join Room',
                    style: DesignTokens.buttonTextDark.copyWith(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: DesignTokens.bgDeepBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Integrated Top Header with Programmatic Logo & Profile Info
              _buildUserHeader(displayName),

              const Spacer(),

              // Welcoming Headline Section
              Center(
                child: Column(
                  children: [
                    Text(
                      'Ready for your next meeting?',
                      textAlign: TextAlign.center,
                      style: DesignTokens.headlineLarge.copyWith(
                        fontSize: 24,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create an ephemeral room or join an active session instantly.',
                      textAlign: TextAlign.center,
                      style: DesignTokens.bodySecondary.copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Re-balanced Quick Actions Layout (Stacked Prominent Action Pills)
              Column(
                children: [
                  // Action 1: Start New Room (Primary - Neon Pink)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Semantics(
                      label: 'Start New Ephemeral Room',
                      button: true,
                      enabled: !_isCreatingRoom,
                      child: ElevatedButton.icon(
                        onPressed: _isCreatingRoom ? null : () => _createAndJoinRoom(isGroup: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.accentNeonPink,
                          foregroundColor: DesignTokens.textDark,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        icon: _isCreatingRoom
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.textDark),
                                ),
                              )
                            : const Icon(Icons.add_call, size: 22),
                        label: Text(
                          _isCreatingRoom ? 'Creating Room...' : 'Start New Room',
                          style: DesignTokens.buttonTextDark.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action 2: Join Existing Room (Secondary - Periwinkle)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Semantics(
                      label: 'Join Existing Room',
                      button: true,
                      child: ElevatedButton.icon(
                        onPressed: _showJoinRoomModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.accentPeriwinkle,
                          foregroundColor: DesignTokens.textDark,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.meeting_room_rounded, size: 22),
                        label: Text(
                          'Join Existing Room',
                          style: DesignTokens.buttonTextDark.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(String displayName) {
    return Row(
      children: [
        const FaceoLogo(size: 42),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FACEO DASHBOARD',
                style: DesignTokens.caption.copyWith(
                  letterSpacing: 1.2,
                  color: DesignTokens.accentNeonYellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                displayName,
                style: DesignTokens.headlineLarge.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Semantics(
          label: 'Sign Out',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: DesignTokens.textSecondary, size: 22),
            tooltip: 'Sign Out',
            onPressed: () async {
              await _authService.signOut();
            },
          ),
        ),
      ],
    );
  }
}
