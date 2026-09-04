import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';
import '../../main.dart';
import '../widgets/faceo_logo.dart';

/// Model representing a single page in the Onboarding flow.
class OnboardingPageData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

/// 3-Step Feature Onboarding Flow highlighting FACEO performance, ephemeral room architecture,
/// and low-bandwidth audio-first hysteresis fallback.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Raw Performance',
      subtitle: 'Hardware-accelerated RTC feeds with zero UI lag, zero bloat, and pure peer connection speeds.',
      icon: Icons.bolt_rounded,
      accentColor: DesignTokens.accentNeonPink,
    ),
    OnboardingPageData(
      title: 'Burn-After-Meeting',
      subtitle: 'Zero server footprint. Ephemeral rooms self-destruct 5 minutes after the last participant departs.',
      icon: Icons.local_fire_department_rounded,
      accentColor: DesignTokens.accentNeonYellow,
    ),
    OnboardingPageData(
      title: 'Unbreakable Connection',
      subtitle: 'Intelligent hysteresis engine drops to audio-only fallback with live captions under poor network QoS.',
      icon: Icons.graphic_eq_rounded,
      accentColor: DesignTokens.accentPeriwinkle,
    ),
  ];

  void _navigateToAuthGate() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToAuthGate();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: DesignTokens.bgDeepBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Top Bar: Logo & Skip Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const FaceoLogo(size: 38),
                  if (!isLastPage)
                    Semantics(
                      label: 'Skip Onboarding',
                      button: true,
                      child: TextButton(
                        onPressed: _navigateToAuthGate,
                        child: Text(
                          'Skip',
                          style: DesignTokens.buttonTextLight.copyWith(
                            color: DesignTokens.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),

              // Page View Section
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Central Feature Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: item.accentColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: item.accentColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            item.icon,
                            size: 56,
                            color: item.accentColor,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Title
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: DesignTokens.headlineLarge.copyWith(
                            fontSize: 26,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            item.subtitle,
                            textAlign: TextAlign.center,
                            style: DesignTokens.bodyLarge.copyWith(
                              color: DesignTokens.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Bottom Section: Page Indicators & Primary Action Button
              Column(
                children: [
                  // Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _pages[_currentPage].accentColor
                              : DesignTokens.cardSurface,
                          borderRadius: DesignTokens.radiusPill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Semantics(
                      label: isLastPage ? 'Get Started' : 'Next Step',
                      button: true,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLastPage
                              ? DesignTokens.accentNeonPink
                              : DesignTokens.accentPeriwinkle,
                          foregroundColor: DesignTokens.textDark,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: DesignTokens.buttonTextDark.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
