import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/design_tokens.dart';

/// Reusable programmatic FACEO Logo Widget.
/// Features a heavily rounded square with a high-contrast Neon Pink border
/// and a bold, stylized Neon Yellow "F" using expressive Poppins typography.
class FaceoLogo extends StatelessWidget {
  final double size;

  const FaceoLogo({
    super.key,
    this.size = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    final double borderWidth = size * 0.04;
    final double borderRadius = size * 0.28;
    final double fontSize = size * 0.52;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: DesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: DesignTokens.accentNeonPink,
          width: borderWidth > 1.5 ? borderWidth : 1.5,
        ),
      ),
      child: Center(
        child: Text(
          'F',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: DesignTokens.accentNeonYellow,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
