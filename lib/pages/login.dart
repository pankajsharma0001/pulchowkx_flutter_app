import 'package:flutter/material.dart';
import 'package:pulchowkx_app/auth/service/google_auth.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart'
    show CustomAppBar, AppPage;
import 'package:flutter_svg/flutter_svg.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final FirebaseServices _firebaseServices = FirebaseServices();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Start animation after a slight delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bool success = await _firebaseServices.signInWithGoogle();

      if (!mounted) return;

      if (success) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainLayout(initialIndex: 4),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sign in was cancelled or failed. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing in: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(currentPage: AppPage.login),
      body: Stack(
        children: [
          // 1. Immersive Dynamic Background
          _buildBackground(isDark),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLoginCard(context, isDark),
                        const SizedBox(height: AppSpacing.xl),
                        _buildInformativeSection(context, isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.heroGradientDark : AppColors.heroGradient,
      ),
      child: Stack(
        children: [
          // Decorative Blurred Blobs
          Positioned(
            top: -100,
            right: -50,
            child: _buildBlob(
              size: 300,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _buildBlob(
              size: 250,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          if (!isDark)
            Positioned(
              top: 200,
              left: -100,
              child: _buildBlob(
                size: 200,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildLoginCard(BuildContext context, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: isDark
          ? AppDecorations.glassDark(borderRadius: AppRadius.xxl)
          : AppDecorations.glass(borderRadius: AppRadius.xxl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App Title & Tagline
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.colored(AppColors.primary),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Smart Pulchowk",
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Your Campus, Reimagined",
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Action Section
          _buildGoogleButton(context, isDark),

          const SizedBox(height: AppSpacing.xl),

          // Legal Footer
          Text(
            'By signing in, you agree to our Terms of Service and Privacy Policy',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context, bool isDark) {
    // Theme-aware colors
    final backgroundColor = isDark ? const Color(0xFF131314) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFE3E3E3)
        : const Color(0xFF1F1F1F);
    final borderColor = isDark
        ? const Color(0xFF8E918F)
        : const Color(0xFF747775);

    return Container(
      width: double.infinity,
      height: 54, // Standard Google button height usually around 40-54
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          AppRadius.full,
        ), // Pill shape is more modern
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          onTap: _isLoading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: textColor, // Adapt spinner to text color
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/google_logo.svg',
                        height: 24,
                        width: 24,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Continue with Google',
                        style: AppTextStyles.button.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing:
                              0.2, // Google font spec usually adds slight tracking
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInformativeSection(BuildContext context, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          _buildBenefitItem(
            context,
            Icons.verified_user_rounded,
            "Secure Campus Access",
            "Sign in with your campus account for full verified access.",
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBenefitItem(
            context,
            Icons.dashboard_customize_rounded,
            "Personalized Dashboard",
            "Get instant updates on your classes, assignments, and routines.",
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
