import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulchowkx_app/pages/book_marketplace.dart';
import 'package:pulchowkx_app/pages/classroom.dart';
import 'package:pulchowkx_app/pages/dashboard.dart';
import 'package:pulchowkx_app/pages/home_page.dart';
import 'package:pulchowkx_app/pages/map.dart';
import 'package:pulchowkx_app/pages/notices.dart';
import 'package:pulchowkx_app/pages/lost_found/lost_found_page.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/pages/clubs.dart';
import 'package:pulchowkx_app/pages/events.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pulchowkx_app/pages/login.dart';
import 'package:pulchowkx_app/pages/admin/admin_dashboard.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/main.dart' show themeProvider;

class MainLayout extends StatefulWidget {
  final int initialIndex;
  const MainLayout({super.key, this.initialIndex = 0});

  static MainLayoutState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainLayoutState>();

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  late int _selectedIndex;
  String _userRole = 'student';
  final ApiService _apiService = ApiService();

  /// ValueNotifier to notify children when tab changes
  final ValueNotifier<int> tabIndexNotifier = ValueNotifier<int>(0);

  /// Expose the current selected tab index
  int get currentIndex => _selectedIndex;

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
    GlobalKey<NavigatorState>(), // 8: Notices
    GlobalKey<NavigatorState>(), // 9: Lost & Found
  ];

  final GlobalKey<NavigatorState> _adminNavigatorKey =
      GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState> _getNavigatorKey(int index) {
    if (index == 2 && _userRole == 'teacher') {
      // Return normal navigator for teacher, but we handle content in build
      // Actually, we use the same key index but switch the page content
      return _navigatorKeys[2];
    } else if (index == 2 && _userRole == 'admin') {
      return _adminNavigatorKey;
    }
    return _navigatorKeys[index];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex;
    tabIndexNotifier.value = _selectedIndex;
    tabIndexNotifier.value = _selectedIndex;
    _checkUserRole();
    // Also perform a background refresh on launch
    _apiService.refreshUserRole().then((_) => _checkUserRole());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh role when app returns to foreground
      _apiService.refreshUserRole().then((_) {
        _checkUserRole();
      });
    }
  }

  Future<void> _checkUserRole() async {
    final role = await _apiService.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabIndexNotifier.dispose();
    super.dispose();
  }

  void setSelectedIndex(int index) {
    // Check if authentication is required for the target tab
    final bool isProtectedRoute =
        index == 2 ||
        index == 3 ||
        index == 4 ||
        index == 5 ||
        index == 6 ||
        index == 8 ||
        index == 9;

    bool isLoggedIn = false;
    try {
      // Safely check if user is logged in
      isLoggedIn = FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      // Firebase might not be initialized if offline/error
      isLoggedIn = false;
    }

    if (isProtectedRoute && !isLoggedIn) {
      // If auth is needed and user is not logged in, switch to login tab (index 7)
      setState(() {
        _selectedIndex = 7;
        tabIndexNotifier.value = 7;
      });
      return;
    }

    if (index == 2 && _userRole == 'guest') {
      // Guest cannot access Class/Admin tab
      return;
    }

    if (_selectedIndex == index) {
      // If tapping the same tab, pop to root of that tab
      _getNavigatorKey(index).currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
        tabIndexNotifier.value = index;
      });
    }
  }

  /// Global notifier for map focus requests (e.g. from search results)
  final ValueNotifier<MapFocusRequest?> mapFocusNotifier =
      ValueNotifier<MapFocusRequest?>(null);

  /// Helper to navigate to map and focus on a specific location
  void navigateToMapLocation(double lat, double lng, String title) {
    // 1. Switch to map tab
    setSelectedIndex(1);

    // 2. Clear any nested navigation in the map tab to ensure MapPage is visible
    _navigatorKeys[1].currentState?.popUntil((route) => route.isFirst);

    // 3. Trigger focus request
    mapFocusNotifier.value = MapFocusRequest(
      coords: ui.Offset(lng, lat), // Using Offset as a simple lat/lng container
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final NavigatorState? currentNavigator = _getNavigatorKey(
          _selectedIndex,
        ).currentState;

        if (currentNavigator != null && currentNavigator.canPop()) {
          // If the nested navigator can pop, do it
          currentNavigator.pop();
        } else if (_selectedIndex != 0) {
          // If not on Home tab, switch to Home
          setState(() {
            _selectedIndex = 0;
          });
        } else {
          // Properly exit the app if we are on the home screen and can't pop anymore
          SystemNavigator.pop();
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
              key: ValueKey(_userRole),
              navigatorKey: _userRole == 'admin'
                  ? _adminNavigatorKey
                  : _navigatorKeys[2],
              rootPage: _userRole == 'admin'
                  ? const AdminDashboardPage()
                  : const ClassroomPage(),
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
            _TabNavigator(
              navigatorKey: _navigatorKeys[8],
              rootPage: const NoticesPage(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[9],
              rootPage: const LostFoundPage(),
            ),
          ],
        ),
        bottomNavigationBar: _BottomNavBar(
          selectedIndex: _selectedIndex,
          userRole: _userRole,
          onItemSelected: setSelectedIndex,
        ),
      ),
    );
  }
}

/// Simple model for focusing the map on a specific location
class MapFocusRequest {
  final ui.Offset coords; // lng, lat
  final String title;
  final DateTime timestamp;

  MapFocusRequest({required this.coords, required this.title})
    : timestamp = DateTime.now();
}

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;

  const _TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.rootPage,
  });

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
  final String userRole;
  final Function(int) onItemSelected;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.userRole,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final totalWidth = MediaQuery.of(context).size.width;
    final itemWidth = totalWidth / 5;

    return Container(
      height: 65 + bottomPadding,
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.only(bottom: bottomPadding),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.7),
              border: Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Stack(
              children: [
                // Sliding Indicator Pill
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  left: selectedIndex * itemWidth + (itemWidth - 48) / 2,
                  top: 8,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // Icons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavIcon(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isActive: selectedIndex == 0,
                      onTap: () => onItemSelected(0),
                    ),
                    _NavIcon(
                      icon: Icons.map_rounded,
                      label: 'Map',
                      isActive: selectedIndex == 1,
                      onTap: () => onItemSelected(1),
                    ),
                    if (userRole != 'guest')
                      _NavIcon(
                        icon: userRole == 'admin'
                            ? Icons.admin_panel_settings_rounded
                            : Icons.school_rounded,
                        label: _getRoleLabel(userRole),
                        isActive: selectedIndex == 2,
                        onTap: () => onItemSelected(2),
                      ),
                    _NavIcon(
                      icon: Icons.menu_book_rounded,
                      label: 'Books',
                      isActive: selectedIndex == 3,
                      onTap: () => onItemSelected(3),
                    ),
                    _NavIcon(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      isActive: selectedIndex == 4,
                      onTap: () => onItemSelected(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    if (role == 'admin') return 'Admin';
    if (role == 'teacher') return 'Teacher';
    return 'Class';
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
      onTap: () {
        themeProvider.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              scale: isActive ? 1.2 : 1.0,
              child: Icon(
                icon,
                color: isActive
                    ? AppColors.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
