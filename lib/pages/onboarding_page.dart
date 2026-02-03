import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: Icons.explore_rounded,
      title: 'Welcome to PulchowkX',
      description:
          'Your ultimate digital companion for navigating IOE Pulchowk Campus with ease.',
      gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    OnboardingSlide(
      icon: Icons.map_rounded,
      title: 'Interactive Campus Map',
      description:
          'Find classrooms, departments, and amenities with our detailed interactive map and AI-powered search.',
      gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    OnboardingSlide(
      icon: Icons.groups_rounded,
      title: 'Discover Clubs & Events',
      description:
          'Stay connected with campus clubs, discover upcoming events, and never miss out on opportunities.',
      gradient: const [Color(0xFFF2994A), Color(0xFFF2C94C)],
    ),
    OnboardingSlide(
      icon: Icons.assistant_rounded,
      title: 'AI Campus Assistant',
      description:
          'Ask our intelligent chatbot anything about the campus, and get instant, accurate answers.',
      gradient: const [Color(0xFF1877F2), Color(0xFF6366F1)],
    ),
  ];

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainLayout(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _slides[_currentPage].gradient,
              ),
            ),
          ),

          // Animated Background Shapes
          ...List.generate(3, (index) {
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOutSine,
              top: _currentPage.isEven
                  ? (index * 100).toDouble()
                  : (index * 150).toDouble(),
              left: _currentPage.isEven
                  ? (index * 50).toDouble()
                  : (index * 80).toDouble(),
              child: Opacity(
                opacity: 0.1,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      haptics.selectionClick();
                      setState(() => _currentPage = index);
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 1.0;
                          if (_pageController.position.hasContentDimensions) {
                            value = _pageController.page! - index;
                            value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                          }
                          return Center(
                            child: Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: value,
                                child: _buildSlide(_slides[index]),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Page indicators and next button
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page indicators
                      Row(
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      // Next/Get Started button
                      GestureDetector(
                        onTap: () {
                          haptics.lightImpact();
                          _nextPage();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == _slides.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: AppTextStyles.button.copyWith(
                                  color: _slides[_currentPage].gradient[0],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage == _slides.length - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                color: _slides[_currentPage].gradient[0],
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container with shadow and glow
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(slide.icon, size: 70, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 60),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 18,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
