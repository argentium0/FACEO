import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';

/// Participant model container for isolated tile state representation.
class ParticipantTileData {
  final String userId;
  final String userName;
  final Widget? videoWidget;
  final bool isLocal;
  final bool isCameraEnabled;

  const ParticipantTileData({
    required this.userId,
    required this.userName,
    this.videoWidget,
    this.isLocal = false,
    this.isCameraEnabled = true,
  });
}

/// Dynamic N-Participant Video Grid featuring isolated per-tile rebuilds.
/// State updates on a single tile (e.g., mute toggle, camera off, active speaker change)
/// DO NOT trigger full grid container rebuilds.
class ActiveSpeakerGrid extends StatelessWidget {
  final List<ParticipantTileData> participants;
  final String? activeSpeakerId;

  const ActiveSpeakerGrid({
    super.key,
    required this.participants,
    this.activeSpeakerId,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Container(
        color: DesignTokens.bgDeepBlack,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.accentPeriwinkle),
          ),
        ),
      );
    }

    final count = participants.length;
    final crossAxisCount = count <= 1 ? 1 : (count <= 4 ? 2 : 3);
    final aspectRatio = count == 1 ? 9 / 16 : (count == 2 ? 3 / 4 : 1.0);

    return GridView.builder(
      key: const PageStorageKey<String>('active_speaker_grid_view'),
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final isActiveSpeaker = activeSpeakerId != null && activeSpeakerId == participant.userId;

        // Keyed ParticipantTileWidget ensures isolated rebuild boundary per participant
        return ParticipantTileWidget(
          key: ValueKey('participant_tile_${participant.userId}'),
          participant: participant,
          isActiveSpeaker: isActiveSpeaker,
        );
      },
    );
  }
}

/// Isolated Participant Tile Widget maintaining encapsulated per-tile render boundaries.
class ParticipantTileWidget extends StatefulWidget {
  final ParticipantTileData participant;
  final bool isActiveSpeaker;

  const ParticipantTileWidget({
    super.key,
    required this.participant,
    this.isActiveSpeaker = false,
  });

  @override
  State<ParticipantTileWidget> createState() => _ParticipantTileWidgetState();
}

class _ParticipantTileWidgetState extends State<ParticipantTileWidget> {
  @override
  Widget build(BuildContext context) {
    final isSpeaker = widget.isActiveSpeaker;
    final p = widget.participant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: DesignTokens.cardSurface,
        borderRadius: DesignTokens.radiusCard,
        border: Border.all(
          color: isSpeaker ? DesignTokens.accentPeriwinkle : Colors.transparent,
          width: isSpeaker ? 2.5 : 0.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Video Feed or Camera Off Avatar Surface
          Positioned.fill(
            child: p.isCameraEnabled && p.videoWidget != null
                ? p.videoWidget!
                : _buildAvatarPlaceholder(p.userName, p.isLocal),
          ),

          // Top Active Speaker Tag
          if (isSpeaker)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DesignTokens.accentPeriwinkle,
                  borderRadius: DesignTokens.radiusPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_up_rounded, size: 12, color: DesignTokens.textDark),
                    const SizedBox(width: 4),
                    Text(
                      'Speaking',
                      style: DesignTokens.caption.copyWith(
                        color: DesignTokens.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Participant Label Overlay
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DesignTokens.bgDeepBlack.withValues(alpha: 0.75),
                borderRadius: DesignTokens.radiusPill,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.isLocal ? '${p.userName} (You)' : p.userName,
                      style: DesignTokens.caption.copyWith(color: DesignTokens.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!p.isCameraEnabled)
                    const Icon(Icons.videocam_off_rounded, size: 14, color: DesignTokens.accentNeonPink),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name, bool isLocal) {
    return Container(
      color: DesignTokens.cardSurface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isLocal ? DesignTokens.accentNeonPink : DesignTokens.accentPeriwinkle,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: DesignTokens.headlineMedium.copyWith(
                  color: DesignTokens.textDark,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: DesignTokens.caption,
            ),
          ],
        ),
      ),
    );
  }
}
