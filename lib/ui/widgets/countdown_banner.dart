import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';

/// Minimalist warning banner displaying remaining self-destruct countdown for empty rooms.
/// Adheres strictly to FACEO design tokens using Secondary Accent (Neon Yellow #F6FF7F)
/// with zero heavy shadows and flat surface architecture.
class CountdownBanner extends StatefulWidget {
  /// Epoch timestamp in milliseconds when the room became empty.
  final int emptyAtMs;

  /// Expiry window duration in minutes (default: 5).
  final int expiryWindowMinutes;

  /// Optional callback invoked when countdown reaches zero.
  final VoidCallback? onExpired;

  const CountdownBanner({
    super.key,
    required this.emptyAtMs,
    this.expiryWindowMinutes = 5,
    this.onExpired,
  });

  @override
  State<CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<CountdownBanner> {
  late Timer _timer;
  int _remainingSeconds = 300;

  @override
  void initState() {
    super.initState();
    _calculateRemainingSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateRemainingSeconds();
    });
  }

  void _calculateRemainingSeconds() {
    final expiryTimeMs = widget.emptyAtMs + (widget.expiryWindowMinutes * 60 * 1000);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffSeconds = ((expiryTimeMs - nowMs) / 1000).ceil();

    if (diffSeconds <= 0) {
      if (mounted) {
        setState(() => _remainingSeconds = 0);
      }
      _timer.cancel();
      widget.onExpired?.call();
    } else {
      if (mounted) {
        setState(() => _remainingSeconds = diffSeconds);
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: DesignTokens.accentNeonYellow,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Room Empty — Destruction in ${_formatTime(_remainingSeconds)}',
              style: DesignTokens.caption.copyWith(
                color: DesignTokens.accentNeonYellow,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
