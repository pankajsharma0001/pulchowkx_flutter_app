import 'package:flutter/material.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Help Center'), centerTitle: true),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.heroGradientDark
              : AppColors.heroGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            _buildHeroHeader(context),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('Support Actions'),
            _buildActionGrid(context),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('Frequently Asked Questions'),
            _buildFAQSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.colored(AppColors.primary),
          ),
          child: const Icon(
            Icons.help_outline_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'How can we help you?',
          style: AppTextStyles.h4,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Find answers or get in touch with our team',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.4,
      children: [
        _buildActionCard(
          context,
          icon: Icons.feedback_rounded,
          title: 'Feedback',
          subtitle: 'Share your ideas',
          color: AppColors.primary,
          onTap: () => _launchMail('support@pulchowkx.com', 'App Feedback'),
        ),
        _buildActionCard(
          context,
          icon: Icons.bug_report_rounded,
          title: 'Report Bug',
          subtitle: 'Found an issue?',
          color: AppColors.warning,
          onTap: () => _launchMail('bugs@pulchowkx.com', 'Bug Report'),
        ),
        _buildActionCard(
          context,
          icon: Icons.email_rounded,
          title: 'Contact',
          subtitle: 'Direct support',
          color: AppColors.info,
          onTap: () => _launchMail('support@pulchowkx.com', 'Support Request'),
        ),
        _buildActionCard(
          context,
          icon: Icons.share_rounded,
          title: 'Share App',
          subtitle: 'Spread the word',
          color: AppColors.success,
          onTap: () {
            // Placeholder for share functionality
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: isDark
            ? AppDecorations.glassDark(borderRadius: AppRadius.md)
            : AppDecorations.glass(borderRadius: AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTextStyles.labelLarge),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection(BuildContext context) {
    return Column(
      children: [
        _buildFAQItem(
          context,
          'How do I register for events?',
          'Go to the Events tab, find an event you\'re interested in, and tap "Register". Make sure you\'re signed in with your campus account.',
        ),
        _buildFAQItem(
          context,
          'How do I list a book for sale?',
          'Navigate to the Marketplace tab, tap the "+" button, and fill in the book details including price and condition.',
        ),
        _buildFAQItem(
          context,
          'Why can\'t I see some features?',
          'Some features require you to be signed in. Please ensure you have signed in with your legitimate Google account.',
        ),
        _buildFAQItem(
          context,
          'How do I report inappropriate content?',
          'Use the "My Reports" option in settings to view status, or use the menu on any item to report it directly to moderators.',
        ),
      ],
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: isDark
          ? AppDecorations.glassDark(borderRadius: AppRadius.md)
          : AppDecorations.glass(borderRadius: AppRadius.md),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMail(String email, String subject) async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=$subject',
    );
    if (await canLaunchUrl(params)) {
      await launchUrl(params);
    }
  }
}
