import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/cards/logo.dart';
import 'package:pulchowkx_app/pages/book_marketplace.dart';
import 'package:pulchowkx_app/pages/classroom.dart';
import 'package:pulchowkx_app/pages/home_page.dart';
import 'package:pulchowkx_app/pages/clubs.dart';
import 'package:pulchowkx_app/pages/dashboard.dart';
import 'package:pulchowkx_app/pages/events.dart';
import 'package:pulchowkx_app/pages/login.dart';
import 'package:pulchowkx_app/pages/map.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

enum AppPage {
  home,
  clubs,
  events,
  map,
  dashboard,
  bookMarketplace,
  classroom,
  login,
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isHomePage;
  final AppPage? currentPage;

  const CustomAppBar({super.key, this.isHomePage = false, this.currentPage});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final bool isLoggedIn = snapshot.data != null;
        final user = snapshot.data;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? AppSpacing.sm : AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  // Logo and Brand
                  _BrandLogo(isHomePage: isHomePage),

                  const Spacer(),

                  // Navigation Items - show based on screen size
                  if (isSmallScreen)
                    // Mobile: Show menu button
                    _MobileMenu(
                      isLoggedIn: isLoggedIn,
                      user: user,
                      currentPage: currentPage,
                    )
                  else
                    // Desktop: Show full nav
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavBarItem(
                          title: 'Clubs',
                          icon: Icons.groups_rounded,
                          isActive: currentPage == AppPage.clubs,
                          onTap: () => _navigateToClubs(
                            context,
                            isLoggedIn,
                            currentPage,
                          ),
                        ),
                        _NavBarItem(
                          title: 'Events',
                          icon: Icons.event_rounded,
                          isActive: currentPage == AppPage.events,
                          onTap: () => _navigateToEvents(
                            context,
                            isLoggedIn,
                            currentPage,
                          ),
                        ),
                        _NavBarItem(
                          title: 'Map',
                          icon: Icons.map_rounded,
                          isActive: currentPage == AppPage.map,
                          onTap: () => _navigateToMap(context, currentPage),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        if (isLoggedIn)
                          _UserAvatar(
                            photoUrl: user?.photoURL,
                            isActive: currentPage == AppPage.dashboard,
                            onTap: () =>
                                _navigateToDashboard(context, currentPage),
                          )
                        else
                          _SignInButton(
                            isActive: currentPage == AppPage.login,
                            onTap: () => _navigateToLogin(context, currentPage),
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

  static void _navigateToClubs(
    BuildContext context,
    bool isLoggedIn,
    AppPage? currentPage,
  ) {
    if (currentPage == AppPage.clubs) return;
    if (!isLoggedIn && currentPage == AppPage.login) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            isLoggedIn ? const ClubsPage() : const LoginPage(),
      ),
    );
  }

  static void _navigateToEvents(
    BuildContext context,
    bool isLoggedIn,
    AppPage? currentPage,
  ) {
    if (currentPage == AppPage.events) return;
    if (!isLoggedIn && currentPage == AppPage.login) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            isLoggedIn ? const EventsPage() : const LoginPage(),
      ),
    );
  }

  static void _navigateToMap(BuildContext context, AppPage? currentPage) {
    if (currentPage == AppPage.map) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapPage()),
    );
  }

  static void _navigateToDashboard(BuildContext context, AppPage? currentPage) {
    if (currentPage == AppPage.dashboard) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
    );
  }

  static void _navigateToLogin(BuildContext context, AppPage? currentPage) {
    if (currentPage == AppPage.login) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final bool isHomePage;

  const _BrandLogo({required this.isHomePage});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isHomePage) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoCard(width: 40, height: 40),
              SizedBox(width: 4),
              Text(
                'PulchowkX',
                style: AppTextStyles.h4.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileMenu extends StatelessWidget {
  final bool isLoggedIn;
  final User? user;
  final AppPage? currentPage;

  const _MobileMenu({required this.isLoggedIn, this.user, this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoggedIn)
          _UserAvatar(
            photoUrl: user?.photoURL,
            isActive: currentPage == AppPage.dashboard,
            onTap: () =>
                CustomAppBar._navigateToDashboard(context, currentPage),
          )
        else
          _CompactSignInButton(
            onTap: () => CustomAppBar._navigateToLogin(context, currentPage),
          ),
        const SizedBox(width: 8),
        Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              elevation: 4,
              color: AppColors.surface,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            padding: EdgeInsets.zero,
            offset: const Offset(0, 50),
            onSelected: (value) {
              switch (value) {
                case 'clubs':
                  CustomAppBar._navigateToClubs(
                    context,
                    isLoggedIn,
                    currentPage,
                  );
                  break;
                case 'events':
                  CustomAppBar._navigateToEvents(
                    context,
                    isLoggedIn,
                    currentPage,
                  );
                  break;
                case 'map':
                  CustomAppBar._navigateToMap(context, currentPage);
                  break;
                case 'dashboard':
                  CustomAppBar._navigateToDashboard(context, currentPage);
                  break;
                case 'marketplace':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookMarketplacePage(),
                    ),
                  );
                  break;
                case 'classroom':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ClassroomPage(),
                    ),
                  );
                  break;
                case 'login':
                  CustomAppBar._navigateToLogin(context, currentPage);
                  break;
              }
            },
            itemBuilder: (context) => [
              _buildMenuItem(
                'clubs',
                Icons.groups_rounded,
                'Clubs',
                currentPage == AppPage.clubs,
              ),
              _buildMenuItem(
                'events',
                Icons.event_rounded,
                'Events',
                currentPage == AppPage.events,
              ),
              _buildMenuItem(
                'map',
                Icons.map_rounded,
                'Map',
                currentPage == AppPage.map,
              ),
              const PopupMenuDivider(height: 24),
              if (isLoggedIn) ...[
                _buildMenuItem(
                  'dashboard',
                  Icons.dashboard_rounded,
                  'Dashboard',
                  currentPage == AppPage.dashboard,
                ),
                _buildMenuItem(
                  'marketplace',
                  Icons.menu_book_rounded,
                  'Marketplace',
                  false,
                ),
                _buildMenuItem(
                  'classroom',
                  Icons.school_rounded,
                  'Classroom',
                  false,
                ),
              ] else
                _buildMenuItem(
                  'login',
                  Icons.login_rounded,
                  'Sign In',
                  currentPage == AppPage.login,
                ),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String label,
    bool isActive,
  ) {
    return PopupMenuItem<String>(
      value: value,
      enabled: !isActive, // Disable interaction if already on the page
      height: 48,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _NavBarItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _isHovered || widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isActive ? null : widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.primary.withValues(
                      alpha: widget.isActive ? 0.12 : 0.08,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: isHighlighted
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isHighlighted
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final VoidCallback onTap;
  final bool isActive;

  const _UserAvatar({
    this.photoUrl,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.accent : AppColors.primary,
              width: isActive ? 3 : 2,
            ),
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: photoUrl != null
                ? CachedNetworkImageProvider(photoUrl!)
                : null,
            child: photoUrl == null
                ? const Icon(Icons.person, size: 16, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _SignInButton({required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isActive ? null : AppColors.primaryGradient,
        color: isActive ? AppColors.primary.withValues(alpha: 0.15) : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isActive
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.login_rounded,
                  size: 14,
                  color: isActive ? AppColors.primary : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'Sign In',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isActive ? AppColors.primary : Colors.white,
                    fontWeight: isActive ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSignInButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CompactSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.login_rounded, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
