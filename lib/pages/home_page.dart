import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(isHomePage: true, currentPage: AppPage.home),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background (Matching other pages)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.heroGradientDark
                  : AppColors.heroGradient,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.xl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildHeroSection(context),
                            const SizedBox(height: 48),
                            _buildPrimaryNavigation(context),
                            const SizedBox(height: 32),
                            _buildSectionDivider(context),
                            const SizedBox(height: 32),
                            _buildFeaturePills(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Column(
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(),
              const SizedBox(width: 8),
              Text(
                'Smart Pulchowk v2.0',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Main Title
        Text(
          'Your Campus.',
          textAlign: TextAlign.center,
          style: AppTextStyles.h1.copyWith(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -1.2,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF2AABEE), // Telegram Blue
              Color(0xFF229ED9), // Telegram Blue Dark
            ],
          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          child: Text(
            'Unified.',
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'Everything you need for Pulchowk Campus, organized in one beautiful interface.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryNavigation(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.hasData;

        return InkWell(
          onTap: () {
            haptics.mediumImpact();
            if (isLoggedIn) {
              MainLayout.of(context)?.setSelectedIndex(4); // Dashboard
            } else {
              MainLayout.of(context)?.setSelectedIndex(7); // Login/Register
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: isLoggedIn
                  ? Theme.of(context).cardTheme.color
                  : AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              border: isLoggedIn ? Border.all(color: AppColors.border) : null,
              boxShadow: [
                BoxShadow(
                  color: isLoggedIn
                      ? Colors.black.withValues(alpha: 0.05)
                      : AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoggedIn) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981), // Emerald-500
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  isLoggedIn ? 'Open Dashboard' : 'Get Started',
                  style: TextStyle(
                    color: isLoggedIn
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (!isLoggedIn) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturePills(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildPill(
          context,
          label: 'Map',
          icon: Icons.location_on_rounded,
          onTap: () => MainLayout.of(context)?.setSelectedIndex(1),
        ),
        _buildPill(
          context,
          label: 'Books',
          icon: Icons.menu_book_rounded,
          onTap: () => MainLayout.of(context)?.setSelectedIndex(3),
        ),
        _buildPill(
          context,
          label: 'Events',
          icon: Icons.event_rounded,
          onTap: () => MainLayout.of(context)?.setSelectedIndex(6),
        ),
        _buildPill(
          context,
          label: 'Clubs',
          icon: Icons.groups_rounded,
          onTap: () => MainLayout.of(context)?.setSelectedIndex(5),
        ),
      ],
    );
  }

  Widget _buildPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        haptics.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 2.2).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: FadeTransition(
            opacity: Tween(begin: 0.5, end: 0.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF2AABEE), // Telegram Blue
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF2AABEE), // Telegram Blue
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
