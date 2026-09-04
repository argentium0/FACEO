import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../services/room_sweeper_service.dart';
import 'active_call_screen.dart';
import 'call_screen_1v1.dart';

/// Minimalist, High-Contrast Home Dashboard adhering strictly to FACEO Design Tokens.
/// Features a hyper-clean layout with centered room entry bar and top profile header.
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

  final TextEditingController _roomIdController = TextEditingController();
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
    _roomIdController.dispose();
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
    if (trimmedId.isEmpty) {
      _createAndJoinRoom(isGroup: false);
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: DesignTokens.bgDeepBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Top User Header
              _buildUserHeader(displayName),

              // Vertically Centered Search/Input Bar Section
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPillSearchInput(),
                      if (_isCreatingRoom) ...[
                        const SizedBox(height: 20),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.accentNeonPink),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(String displayName) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: DesignTokens.accentPeriwinkle,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: DesignTokens.headlineLarge.copyWith(
                color: DesignTokens.textDark,
                fontSize: 20,
              ),
            ),
          ),
        ),
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
                style: DesignTokens.headlineLarge.copyWith(fontSize: 20),
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

  Widget _buildPillSearchInput() {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.cardSurface,
        borderRadius: DesignTokens.radiusPill,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(
            Icons.search_rounded,
            color: DesignTokens.accentPeriwinkle,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _roomIdController,
              style: DesignTokens.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Enter room code or search session...',
                hintStyle: DesignTokens.bodySecondary,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (value) => _joinExistingRoom(value),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Join Room',
            button: true,
            enabled: !_isCreatingRoom,
            child: ElevatedButton(
              onPressed: _isCreatingRoom ? null : () => _joinExistingRoom(_roomIdController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.accentNeonPink,
                foregroundColor: DesignTokens.textDark,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: Text(
                'Join',
                style: DesignTokens.buttonTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
