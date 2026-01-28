import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulchowkx_app/pages/book_marketplace.dart';
import 'package:pulchowkx_app/pages/classroom.dart';
import 'package:pulchowkx_app/pages/dashboard.dart';
import 'package:pulchowkx_app/pages/home_page.dart';
import 'package:pulchowkx_app/pages/map.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/pages/clubs.dart';
import 'package:pulchowkx_app/pages/events.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pulchowkx_app/pages/login.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  const MainLayout({super.key, this.initialIndex = 0});

  static MainLayoutState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainLayoutState>();

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;

  // Keys for nested navigation in each tab
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // 0: Home
    GlobalKey<NavigatorState>(), // 1: Map
    GlobalKey<NavigatorState>(), // 2: Classroom
    GlobalKey<NavigatorState>(), // 3: Marketplace
    GlobalKey<NavigatorState>(), // 4: Dashboard
    GlobalKey<NavigatorState>(), // 5: Clubs
    GlobalKey<NavigatorState>(), // 6: Events
    GlobalKey<NavigatorState>(), // 7: Login
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void setSelectedIndex(int index) {
    // Check if authentication is required for the target tab
    final bool isProtectedRoute =
        index == 2 || index == 3 || index == 4 || index == 5 || index == 6;
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    if (isProtectedRoute && !isLoggedIn) {
      // If auth is needed and user is not logged in, switch to login tab (index 7)
      setState(() {
        _selectedIndex = 7;
      });
      return;
    }

    if (_selectedIndex == index) {
      // If tapping the same tab, pop to root of that tab
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final NavigatorState? currentNavigator =
            _navigatorKeys[_selectedIndex].currentState;

        if (currentNavigator != null && currentNavigator.canPop()) {
          // If the nested navigator can pop, do it
          currentNavigator.pop();
        } else if (_selectedIndex != 0) {
          // If not on Home tab, switch to Home
          setState(() {
            _selectedIndex = 0;
          });
        } else {
          // Fallback: Use the root navigator (usually exits the app)
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _TabNavigator(
              navigatorKey: _navigatorKeys[0],
              rootPage: const HomePage(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[1],
              rootPage: const MapPage(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[2],
              rootPage: const ClassroomPage(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[3],
              rootPage: const BookMarketplacePage(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[4],
              rootPage: const DashboardPage(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[5],
              rootPage: const ClubsPage(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[6],
              rootPage: const EventsPage(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[7],
              rootPage: const LoginPage(),
            ),
          ],
        ),
        bottomNavigationBar: _BottomNavBar(
          selectedIndex: _selectedIndex,
          onItemSelected: setSelectedIndex,
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;

  const _TabNavigator({required this.navigatorKey, required this.rootPage});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => rootPage,
        );
      },
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 65 + MediaQuery.of(context).padding.bottom,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavIcon(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isActive: selectedIndex == 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onItemSelected(0);
                  },
                ),
                _NavIcon(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  isActive: selectedIndex == 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onItemSelected(1);
                  },
                ),
                _NavIcon(
                  icon: Icons.school_rounded,
                  label: 'Class',
                  isActive: selectedIndex == 2,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onItemSelected(2);
                  },
                ),
                _NavIcon(
                  icon: Icons.menu_book_rounded,
                  label: 'Books',
                  isActive: selectedIndex == 3,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onItemSelected(3);
                  },
                ),
                _NavIcon(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isActive: selectedIndex == 4,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onItemSelected(4);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 65,
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: isActive ? 40 : 0,
                  height: isActive ? 40 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                Icon(
                  icon,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textMuted,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
