import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';

/// Audio-First Fallback Overlay UI Widget.
///
/// Displayed when network connection quality degrades to critical levels.
/// Renders a dark, minimalist audio-only canvas with a pulsating indicator
/// and real-time live captions formatted in Neon Yellow (#F6FF7F).
class AudioFirstOverlay extends StatefulWidget {
  final String recognizedText;
  final String? userName;
  final bool isListening;
  final String? errorMessage;

  const AudioFirstOverlay({
    super.key,
    required this.recognizedText,
    this.userName,
    this.isListening = true,
    this.errorMessage,
  });

  @override
  State<AudioFirstOverlay> createState() => _AudioFirstOverlayState();
}

class _AudioFirstOverlayState extends State<AudioFirstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveAnimationController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(
        parent: _waveAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.userName ?? 'Participant';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: DesignTokens.bgDeepBlack.withValues(alpha: 0.95),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 60),

          // Minimalist Banner: Connection Degraded - Audio Only
          _buildDegradedBanner(),

          const Spacer(),

          // Central Participant Avatar & Pulsating Audio Wave Indicator
          _buildAudioWaveAvatar(displayName),

          const SizedBox(height: 32),

          // Real-Time Transcript Container (Neon Yellow Text)
          _buildTranscriptCard(),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDegradedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.cardSurface,
        borderRadius: DesignTokens.radiusPill,
        border: Border.all(
          color: DesignTokens.accentNeonYellow.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: DesignTokens.accentNeonYellow,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            'Connection Degraded • Audio-Only Mode',
            style: DesignTokens.caption.copyWith(
              color: DesignTokens.accentNeonYellow,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioWaveAvatar(String name) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              padding: EdgeInsets.all(12 * _pulseAnimation.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignTokens.accentPeriwinkle.withValues(alpha: 0.12),
                border: Border.all(
                  color: DesignTokens.accentPeriwinkle.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: child,
            );
          },
          child: CircleAvatar(
            radius: 44,
            backgroundColor: DesignTokens.accentPeriwinkle,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: DesignTokens.headlineLarge.copyWith(
                color: DesignTokens.textDark,
                fontSize: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: DesignTokens.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Live Audio Stream Active',
          style: DesignTokens.bodySecondary,
        ),
      ],
    );
  }

  Widget _buildTranscriptCard() {
    final hasText = widget.recognizedText.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 110, maxHeight: 180),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.cardSurface,
        borderRadius: DesignTokens.radiusCard,
        border: Border.all(
          color: DesignTokens.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.subtitles_rounded,
                size: 16,
                color: DesignTokens.accentNeonYellow,
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE CAPTIONS',
                style: DesignTokens.caption.copyWith(
                  color: DesignTokens.accentNeonYellow,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (widget.isListening)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DesignTokens.bgDeepBlack,
                    borderRadius: DesignTokens.radiusPill,
                  ),
                  child: Text(
                    'Listening...',
                    style: DesignTokens.caption.copyWith(
                      color: DesignTokens.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              child: widget.errorMessage != null
                  ? Text(
                      widget.errorMessage!,
                      style: DesignTokens.bodyMedium.copyWith(
                        color: DesignTokens.accentNeonPink,
                      ),
                    )
                  : Text(
                      hasText
                          ? widget.recognizedText
                          : (widget.isListening
                              ? 'Waiting for speech...'
                              : 'Captions ready.'),
                      style: DesignTokens.bodyLarge.copyWith(
                        color: hasText
                            ? DesignTokens.accentNeonYellow
                            : DesignTokens.textSecondary,
                        fontWeight: hasText ? FontWeight.w600 : FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
