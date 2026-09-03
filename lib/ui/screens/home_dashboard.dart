import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../services/room_sweeper_service.dart';
import 'active_call_screen.dart';
import 'call_screen_1v1.dart';

/// Minimalist, High-Contrast Home Dashboard adhering strictly to FACEO Design Tokens.
/// Features a dark theme (#1F1F1F / #313131), expressive Poppins typography, 
/// pill-shaped inputs/buttons, category tiles with neon accents (#FF95DD, #F6FF7F, #B7BEFE), 
/// and zero 3D visual noise.
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
  final TextEditingController _searchController = TextEditingController();
  bool _isCreatingRoom = false;

  // Category Cards Data as referenced in Design Spec
  final List<Map<String, dynamic>> _categories = [
    {
      'title': 'Financial Advisor',
      'subtitle': '1-on-1 expert consultation',
      'icon': Icons.account_balance_wallet_rounded,
      'accent': DesignTokens.accentNeonPink,
      'tag': 'Popular',
      'isGroup': false,
    },
    {
      'title': 'Budget Optimizer',
      'subtitle': 'Group strategy & review',
      'icon': Icons.pie_chart_rounded,
      'accent': DesignTokens.accentNeonYellow,
      'tag': 'Featured',
      'isGroup': true,
    },
    {
      'title': 'Instant Group Call',
      'subtitle': 'Multi-party video room',
      'icon': Icons.groups_rounded,
      'accent': DesignTokens.accentPeriwinkle,
      'tag': 'Quick',
      'isGroup': true,
    },
    {
      'title': '1-on-1 Consultation',
      'subtitle': 'Private peer meeting',
      'icon': Icons.videocam_rounded,
      'accent': DesignTokens.accentNeonPink,
      'tag': 'Private',
      'isGroup': false,
    },
  ];

  // Mock recent call history sessions
  final List<Map<String, String>> _callHistory = [
    {
      'title': 'Financial Advisory Session',
      'roomId': 'room-fin-902',
      'time': 'Today, 2:30 PM',
      'type': '1-on-1 Consultation',
    },
    {
      'title': 'Quarterly Budget Planning',
      'roomId': 'room-bdg-742',
      'time': 'Yesterday, 6:15 PM',
      'type': 'Budget Optimizer',
    },
    {
      'title': 'Engineering Team Sync',
      'roomId': 'room-eng-109',
      'time': 'Aug 30, 11:00 AM',
      'type': 'Instant Group Call',
    },
  ];

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createAndJoinRoom({bool isGroup = true, String? customTitle}) async {
    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid ?? 'user-guest-${DateTime.now().millisecondsSinceEpoch % 1000}';
    final userName = currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'Guest User';

    setState(() => _isCreatingRoom = true);

    try {
      final roomId = await _roomService.createRoom(
        hostUserId: userId,
        title: customTitle ?? (isGroup ? 'Group Video Session' : '1-on-1 Call'),
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
              // Top User Header
              _buildUserHeader(displayName),

              const SizedBox(height: 24),

              // Pill Search / Room Code Input Bar
              _buildPillSearchInput(),

              const SizedBox(height: 28),

              // Category Cards Section Title
              Text(
                'Explore Categories',
                style: DesignTokens.headlineLarge,
              ),
              const SizedBox(height: 14),

              // Category Cards Grid
              _buildCategoryCardsGrid(),

              const SizedBox(height: 32),

              // Recent Calls / Sessions Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Sessions',
                    style: DesignTokens.headlineMedium,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignTokens.cardSurface,
                      borderRadius: DesignTokens.radiusPill,
                    ),
                    child: Text(
                      '${_callHistory.length} Total',
                      style: DesignTokens.caption.copyWith(color: DesignTokens.accentPeriwinkle),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Call History List
              _buildCallHistoryList(),
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
          decoration: BoxDecoration(
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
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: DesignTokens.textSecondary, size: 22),
          tooltip: 'Sign Out',
          onPressed: () async {
            await _authService.signOut();
          },
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
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _joinExistingRoom(_roomIdController.text),
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
        ],
      ),
    );
  }

  Widget _buildCategoryCardsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final Color accentColor = cat['accent'] as Color;

        return Material(
          color: DesignTokens.cardSurface,
          borderRadius: DesignTokens.radiusCard,
          elevation: 0,
          child: InkWell(
            onTap: _isCreatingRoom
                ? null
                : () => _createAndJoinRoom(
                      isGroup: cat['isGroup'] as bool,
                      customTitle: cat['title'] as String,
                    ),
            borderRadius: DesignTokens.radiusCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          cat['icon'] as IconData,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: DesignTokens.radiusPill,
                        ),
                        child: Text(
                          cat['tag'] as String,
                          style: DesignTokens.caption.copyWith(
                            color: DesignTokens.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat['title'] as String,
                        style: DesignTokens.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat['subtitle'] as String,
                        style: DesignTokens.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
        final is1v1 = item['type']!.contains('1-on-1') || item['type']!.contains('Consultation');

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
              style: DesignTokens.titleMedium.copyWith(fontSize: 15),
            ),
            subtitle: Text(
              '${item['type']} • ${item['time']}',
              style: DesignTokens.caption,
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: DesignTokens.bgDeepBlack,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.call_rounded, color: DesignTokens.accentNeonYellow, size: 18),
                onPressed: () => _joinExistingRoom(item['roomId']!, is1v1: is1v1),
              ),
            ),
          ),
        );
      },
    );
  }
}
