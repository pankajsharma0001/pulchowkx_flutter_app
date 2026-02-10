import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/cards/logo.dart';
import 'package:pulchowkx_app/pages/home_page.dart';
import 'package:pulchowkx_app/pages/search_page.dart';
import 'package:pulchowkx_app/pages/in_app_notifications_page.dart';
import 'package:pulchowkx_app/services/in_app_notification_service.dart';
import 'package:pulchowkx_app/pages/clubs.dart';
import 'package:pulchowkx_app/pages/dashboard.dart';
import 'package:pulchowkx_app/pages/events.dart';
import 'package:pulchowkx_app/pages/login.dart';
import 'package:pulchowkx_app/pages/map.dart';
import 'package:pulchowkx_app/pages/notices.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/pages/lost_found/lost_found_page.dart';

enum AppPage {
  home,
  clubs,
  events,
  map,
  dashboard,
  bookMarketplace,
  classroom,
  notices,
  login,
  notifications,
  lostAndFound,
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
    final isMoreActive =
        currentPage == AppPage.clubs ||
        currentPage == AppPage.events ||
        currentPage == AppPage.notices ||
        currentPage == AppPage.lostAndFound;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data != null;
        final user = snapshot.data;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).appBarTheme.backgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerTheme.color ?? AppColors.border,
                width: 0.5,
              ),
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
                    // Mobile: Show simplified actions (profile or login)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchPage(),
                              ),
                            );
                          },
                        ),
                        _NotificationBell(
                          isActive: currentPage == AppPage.notifications,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (isLoggedIn)
                          _UserAvatar(
                            photoUrl: user?.photoURL,
                            isActive: currentPage == AppPage.dashboard,
                            onTap: () =>
                                _navigateToDashboard(context, currentPage),
                          )
                        else
                          _CompactSignInButton(
                            onTap: () => _navigateToLogin(context, currentPage),
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        _MobileMoreMenu(
                          isLoggedIn: isLoggedIn,
                          currentPage: currentPage,
                          isActive: isMoreActive,
                        ),
                      ],
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
                          icon: Icons.map_outlined,
                          isActive: currentPage == AppPage.map,
                          onTap: () => _navigateToMap(context, currentPage),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          icon: const Icon(Icons.search_rounded),
                          tooltip: 'Search',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchPage(),
                              ),
                            );
                          },
                        ),
                        _NotificationBell(
                          isActive: currentPage == AppPage.notifications,
                        ),
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

    final mainLayout = MainLayout.of(context);
    if (mainLayout != null) {
      mainLayout.setSelectedIndex(5);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              isLoggedIn ? const ClubsPage() : const LoginPage(),
        ),
      );
    }
  }

  static void _navigateToEvents(
    BuildContext context,
    bool isLoggedIn,
    AppPage? currentPage,
  ) {
    if (currentPage == AppPage.events) return;

    final mainLayout = MainLayout.of(context);
    if (mainLayout != null) {
      mainLayout.setSelectedIndex(6);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              isLoggedIn ? const EventsPage() : const LoginPage(),
        ),
      );
    }
  }

  static void _navigateToMap(BuildContext context, AppPage? currentPage) {
    if (currentPage == AppPage.map) return;
    final mainLayout = MainLayout.of(context);
    if (mainLayout != null) {
      mainLayout.setSelectedIndex(1);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MapPage()),
      );
    }
  }

  static void _navigateToDashboard(BuildContext context, AppPage? currentPage) {
    if (currentPage == AppPage.dashboard) return;
    final mainLayout = MainLayout.of(context);
    if (mainLayout != null) {
      mainLayout.setSelectedIndex(4);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  static void _navigateToLogin(BuildContext context, AppPage? currentPage) {
    if (currentPage == AppPage.login) return;
    final mainLayout = MainLayout.of(context);
    if (mainLayout != null) {
      mainLayout.setSelectedIndex(7);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  static void _navigateToNotifications(
    BuildContext context,
    AppPage? currentPage,
  ) {
    if (currentPage == AppPage.notifications) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InAppNotificationsPage()),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final bool isActive;

  const _NotificationBell({this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: inAppNotifications.unreadCount,
      builder: (context, count, _) {
        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isActive
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                color: isActive ? AppColors.primary : null,
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            Theme.of(context).appBarTheme.backgroundColor ??
                            Colors.white,
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Positioned(
                  right: -4,
                  top: -4,
                  child: Text(
                    'zzz',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Notifications',
          onPressed: () {
            haptics.selectionClick();
            CustomAppBar._navigateToNotifications(context, null);
          },
        );
      },
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
          haptics.lightImpact();
          if (isHomePage) return;
          final mainLayout = MainLayout.of(context);
          if (mainLayout != null) {
            mainLayout.setSelectedIndex(0);
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
            );
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoCard(width: 32, height: 32),
              SizedBox(width: 4),
              Text(
                'Smart Pulchowk',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 16,
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
          onTap: widget.isActive
              ? null
              : () {
                  haptics.selectionClick();
                  widget.onTap();
                },
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
        onTap: isActive
            ? null
            : () {
                haptics.selectionClick();
                onTap();
              },
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
          onTap: isActive
              ? null
              : () {
                  haptics.lightImpact();
                  onTap();
                },
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
          onTap: () {
            haptics.lightImpact();
            onTap();
          },
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

class _MobileMoreMenu extends StatelessWidget {
  final bool isLoggedIn;
  final AppPage? currentPage;
  final bool isActive;

  const _MobileMoreMenu({
    required this.isLoggedIn,
    this.currentPage,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      icon: Stack(
        children: [
          Icon(
            Icons.more_vert_rounded,
            color: isActive
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          if (isActive)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      onSelected: (value) {
        haptics.selectionClick();
        if (value == 'clubs') {
          CustomAppBar._navigateToClubs(context, isLoggedIn, currentPage);
        } else if (value == 'events') {
          CustomAppBar._navigateToEvents(context, isLoggedIn, currentPage);
        } else if (value == 'notices') {
          // Navigate to notices tab
          final mainLayout = MainLayout.of(context);
          if (mainLayout != null) {
            mainLayout.setSelectedIndex(8);
          } else {
            if (!isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NoticesPage()),
            );
          }
        } else if (value == 'lost-found') {
          final mainLayout = MainLayout.of(context);
          if (mainLayout != null) {
            mainLayout.setSelectedIndex(9);
          } else {
            if (!isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LostFoundPage()),
            );
          }
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'clubs',
          child: Row(
            children: [
              Icon(
                Icons.groups_rounded,
                size: 20,
                color: currentPage == AppPage.clubs
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                'Campus Clubs',
                style: TextStyle(
                  color: currentPage == AppPage.clubs
                      ? AppColors.primary
                      : null,
                  fontWeight: currentPage == AppPage.clubs
                      ? FontWeight.bold
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'events',
          child: Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 20,
                color: currentPage == AppPage.events
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                'Events',
                style: TextStyle(
                  color: currentPage == AppPage.events
                      ? AppColors.primary
                      : null,
                  fontWeight: currentPage == AppPage.events
                      ? FontWeight.bold
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'notices',
          child: Row(
            children: [
              Icon(
                Icons.campaign_rounded,
                size: 20,
                color: currentPage == AppPage.notices
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                'IOE Notices',
                style: TextStyle(
                  color: currentPage == AppPage.notices
                      ? AppColors.primary
                      : null,
                  fontWeight: currentPage == AppPage.notices
                      ? FontWeight.bold
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'lost-found',
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: currentPage == AppPage.lostAndFound
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                'Lost & Found',
                style: TextStyle(
                  color: currentPage == AppPage.lostAndFound
                      ? AppColors.primary
                      : null,
                  fontWeight: currentPage == AppPage.lostAndFound
                      ? FontWeight.bold
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
