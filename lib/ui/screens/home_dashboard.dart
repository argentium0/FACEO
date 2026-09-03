import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../services/room_sweeper_service.dart';
import 'active_call_screen.dart';
import 'call_screen_1v1.dart';

/// Minimalist Home Dashboard adhering strictly to FACEO Design Tokens.
/// Features search/join room field, quick action feature tiles, and call history.
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

  // Mock call history items
  final List<Map<String, String>> _callHistory = [
    {
      'title': 'Engineering Team Sync',
      'roomId': 'room-eng-902',
      'time': 'Today, 2:30 PM',
      'type': 'Group Call',
    },
    {
      'title': 'Sarah Jenkins',
      'roomId': 'room-1v1-742',
      'time': 'Yesterday, 6:15 PM',
      'type': '1-on-1 Call',
    },
    {
      'title': 'Product Design Review',
      'roomId': 'room-dsgn-109',
      'time': 'Aug 30, 11:00 AM',
      'type': 'Group Call',
    },
  ];

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _roomService = widget.roomService ?? RoomService();
    // Run quiet background sweep to purge expired rooms
    RoomSweeperService().sweepExpiredRooms();
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  Future<void> _createAndJoinRoom({bool isGroup = true}) async {
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

  void _joinExistingRoom(String roomId, {bool is1v1 = false}) {
    if (roomId.trim().isEmpty) return;

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid ?? 'user-guest-${DateTime.now().millisecondsSinceEpoch % 1000}';
    final userName = currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'Guest User';

    if (is1v1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen1v1(
            roomId: roomId.trim(),
            userId: userId,
            userName: userName,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            roomId: roomId.trim(),
            userId: userId,
            userName: userName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: DesignTokens.bgDeepBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top User Bar
              _buildTopUserBar(displayName),

              const SizedBox(height: 24),

              // Search / Room Code Join Card
              _buildJoinRoomCard(),

              const SizedBox(height: 28),

              // Quick Action Feature Tiles
              Text(
                'Quick Actions',
                style: DesignTokens.headlineMedium,
              ),
              const SizedBox(height: 14),
              _buildFeatureTiles(),

              const SizedBox(height: 32),

              // Call History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Calls',
                    style: DesignTokens.headlineMedium,
                  ),
                  Text(
                    '${_callHistory.length} Sessions',
                    style: DesignTokens.caption,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildCallHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopUserBar(String displayName) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: DesignTokens.accentPeriwinkle,
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
            style: DesignTokens.headlineMedium.copyWith(
              color: DesignTokens.textDark,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: DesignTokens.caption,
              ),
              Text(
                displayName,
                style: DesignTokens.headlineMedium.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: DesignTokens.textSecondary),
          tooltip: 'Sign Out',
          onPressed: () async {
            await _authService.signOut();
          },
        ),
      ],
    );
  }

  Widget _buildJoinRoomCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignTokens.cardSurface,
        borderRadius: DesignTokens.radiusCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join Meeting Room',
            style: DesignTokens.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Enter a room code to join an ongoing video session.',
            style: DesignTokens.caption,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomIdController,
                  style: DesignTokens.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: 'e.g. room-101',
                    prefixIcon: Icon(Icons.meeting_room_outlined, color: DesignTokens.textSecondary, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _joinExistingRoom(_roomIdController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.accentPeriwinkle,
                  foregroundColor: DesignTokens.textDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                child: const Text('Join'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTiles() {
    return Row(
      children: [
        // Instant Group Call Tile
        Expanded(
          child: _buildActionTile(
            title: 'New Group Call',
            subtitle: 'Instant multi-party',
            icon: Icons.groups_rounded,
            accentColor: DesignTokens.accentPeriwinkle,
            onTap: _isCreatingRoom ? null : () => _createAndJoinRoom(isGroup: true),
          ),
        ),
        const SizedBox(width: 14),

        // Direct 1-on-1 Call Tile
        Expanded(
          child: _buildActionTile(
            title: '1-on-1 Call',
            subtitle: 'Direct peer video',
            icon: Icons.person_rounded,
            accentColor: DesignTokens.accentNeonPink,
            onTap: _isCreatingRoom ? null : () => _createAndJoinRoom(isGroup: false),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: DesignTokens.cardSurface,
      borderRadius: DesignTokens.radiusCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignTokens.radiusCard,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: DesignTokens.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: DesignTokens.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallHistoryList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _callHistory.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _callHistory[index];
        final is1v1 = item['type'] == '1-on-1 Call';

        return Container(
          decoration: BoxDecoration(
            color: DesignTokens.cardSurface,
            borderRadius: DesignTokens.radiusCard,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: is1v1
                  ? DesignTokens.accentNeonPink.withValues(alpha: 0.2)
                  : DesignTokens.accentPeriwinkle.withValues(alpha: 0.2),
              child: Icon(
                is1v1 ? Icons.videocam_rounded : Icons.groups_rounded,
                color: is1v1 ? DesignTokens.accentNeonPink : DesignTokens.accentPeriwinkle,
                size: 20,
              ),
            ),
            title: Text(
              item['title']!,
              style: DesignTokens.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${item['type']} • ${item['time']}',
              style: DesignTokens.caption,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.call_rounded, color: DesignTokens.accentPeriwinkle, size: 20),
              onPressed: () => _joinExistingRoom(item['roomId']!, is1v1: is1v1),
            ),
          ),
        );
      },
    );
  }
}
