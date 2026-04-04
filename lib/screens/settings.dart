import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../core/page_route.dart';
import '../widgets/cards.dart';
import '../widgets/buttons.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../providers/app_providers.dart';
import '../providers/course_provider.dart';
import '../database/database_helper.dart';
import 'settings/subscription_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _staggeredSlide(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Interval((index * 0.1).clamp(0.0, 1.0), 1.0, curve: Curves.easeOutCubic),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPremium = ref.watch(isPremiumProvider).value ?? false;
    final user = AuthService().currentUser;
    final isAuthenticated = AuthService().isAuthenticated;
    final activeCourse = ref.watch(courseProvider).activeCourse;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: SeedlingColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings', style: SeedlingTypography.heading2),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _staggeredSlide(0, _buildUserProfileCard(user, isPremium)),
          const SizedBox(height: 20),
          
          _staggeredSlide(1, isPremium ? _buildPremiumActiveStatus() : _buildPremiumBanner()),
          const SizedBox(height: 30),

          // Account Section
          _staggeredSlide(2, _buildSectionHeader('Account')),
          _staggeredSlide(2, GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildToggleTile(
                  Icons.sync,
                  'Automatic Cloud Sync',
                  'Keep data safe across devices',
                  settings.cloudSyncEnabled,
                  (val) => ref.read(settingsProvider.notifier).setCloudSyncEnabled(val),
                ),
              ],
            ),
          )),
          const SizedBox(height: 30),

          // Learning Preferences
          _staggeredSlide(3, _buildSectionHeader('Learning Preferences')),
          _staggeredSlide(3, GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildActionTile(
                  Icons.language, 
                  'Target Language', 
                  activeCourse?.targetLanguage.name ?? 'None selected', 
                  () => _showLanguageSelector(isTarget: true)
                ),
                _buildActionTile(
                  Icons.person_pin, 
                  'Native Language', 
                  activeCourse?.nativeLanguage.name ?? 'English', 
                  () => _showLanguageSelector(isTarget: false)
                ),
                _buildActionTile(
                  Icons.flag, 
                  'Daily Word Goal', 
                  '${settings.dailyWordGoal} words per day', 
                  () => _showDailyGoalSelector()
                ),
              ],
            ),
          )),
          const SizedBox(height: 30),

          // Notifications & Sound
          _staggeredSlide(4, _buildSectionHeader('Notifications & Sound')),
          _staggeredSlide(4, GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildToggleTile(
                  Icons.notifications_active, 
                  'Lesson Reminders', 
                  'Daily nudge to keep growing', 
                  settings.notificationsEnabled, 
                  (val) => ref.read(settingsProvider.notifier).toggleNotifications(val)
                ),
                if (settings.notificationsEnabled)
                  _buildActionTile(
                    Icons.access_time, 
                    'Reminder Time', 
                    settings.reminderTime.format(context), 
                    () => _selectReminderTime(context, settings.reminderTime)
                  ),
                _buildToggleTile(
                  Icons.volume_up, 
                  'Sound Effects', 
                  'Tactile feedback during lessons', 
                  settings.soundEffectsEnabled, 
                  (val) => ref.read(settingsProvider.notifier).toggleSoundEffects(val)
                ),
                _buildToggleTile(
                  Icons.vibration, 
                  'Haptic Feedback', 
                  'Physical vibration for positive actions', 
                  settings.hapticsEnabled, 
                  (val) => ref.read(settingsProvider.notifier).toggleHaptics(val)
                ),
              ],
            ),
          )),
          const SizedBox(height: 30),

          // Support & Legal
          _staggeredSlide(5, _buildSectionHeader('Support & Legal')),
          _staggeredSlide(5, GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildActionTile(Icons.help_outline, 'Help Center', 'Guides and FAQ', () => _launchUrl('https://seedling.app/help')),
                _buildActionTile(Icons.mail_outline, 'Contact Support', 'Get human help', () => _launchUrl('mailto:support@seedling.app')),
                _buildActionTile(Icons.description_outlined, 'Privacy Policy', 'Data protection', () => _launchUrl('https://seedling.app/privacy')),
                _buildActionTile(Icons.gavel_outlined, 'Terms of Service', 'App rules', () => _launchUrl('https://seedling.app/terms')),
              ],
            ),
          )),
          const SizedBox(height: 30),

          // Danger Zone
          _staggeredSlide(6, _buildSectionHeader('Danger Zone', isDestructive: true)),
          _staggeredSlide(6, GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (isAuthenticated)
                  _buildActionTile(Icons.logout, 'Sign Out', 'Log out of your account', () => _showSignOutDialog(), isDestructive: true),
                _buildActionTile(Icons.restart_alt, 'Reset Course Progress', 'Wipe SRS data for current language', () => _showResetProgressDialog(activeCourse), isDestructive: true),
                _buildActionTile(Icons.delete_forever, 'Delete Account', 'Permanently remove all data', () => _showDeleteAccountDialog(), isDestructive: true),
              ],
            ),
          )),

          const SizedBox(height: 40),

          Center(
            child: Column(
              children: [
                Text(
                  'Seedling v1.1.0 (Build 2024)',
                  style: SeedlingTypography.caption,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Made with 💚 by Seedling Team',
                  style: TextStyle(
                    fontSize: 10,
                    color: SeedlingColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(dynamic user, bool isPremium) {
    final displayName = user?.userMetadata?['display_name'] ?? 'Guest Learner';
    final initials = displayName.substring(0, (displayName.length > 2 ? 2 : displayName.length)).toUpperCase();

    return GrowingCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: SeedlingColors.waterBlue.withValues(alpha: 0.2),
            child: Text(initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SeedlingColors.waterBlue)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: SeedlingTypography.heading2),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isPremium ? Icons.verified : Icons.account_circle,
                      size: 14,
                      color: isPremium ? SeedlingColors.autumnGold : SeedlingColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPremium ? 'Pro Member' : 'Free Learner',
                      style: SeedlingTypography.caption.copyWith(
                        color: isPremium ? SeedlingColors.autumnGold : SeedlingColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.edit, color: SeedlingColors.textSecondary.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildPremiumActiveStatus() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = math.sin(_pulseController.value * math.pi);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SeedlingColors.cardBackground, SeedlingColors.background],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SeedlingColors.autumnGold.withValues(alpha: 0.3 + 0.2 * pulse), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.autumnGold.withValues(alpha: 0.15 + 0.1 * pulse),
                blurRadius: 20 + 10 * pulse,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SeedlingColors.autumnGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: SeedlingColors.autumnGold, size: 36),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (_, __) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: const [SeedlingColors.autumnGold, Colors.white, SeedlingColors.autumnGold],
                          stops: [
                            (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                            _shimmerController.value.clamp(0.0, 1.0),
                            (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Seedling Pro Active',
                          style: SeedlingTypography.heading3.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have access to all premium features.',
                      style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SeedlingColors.sunlight, SeedlingColors.seedlingGreen],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.sunlight.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: SeedlingColors.background, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: SeedlingTypography.heading3.copyWith(
                    color: SeedlingColors.background,
                  ),
                ),
                Text(
                  'Unlock all languages, cloud backups, and remove ads.',
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.background.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OrganicButton(
            text: 'UPGRADE',
            onPressed: () {
              Navigator.push(
                context,
                SeedlingPageRoute(page: const SubscriptionScreen()),
              );
            },
            height: 40,
            width: 90,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: SeedlingTypography.caption.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: isDestructive
              ? SeedlingColors.error
              : SeedlingColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: SeedlingColors.morningDew.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: SeedlingColors.seedlingGreen, size: 22),
      ),
      title: Text(
        title,
        style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: SeedlingTypography.caption),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: SeedlingColors.seedlingGreen,
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? SeedlingColors.error.withValues(alpha: 0.1)
              : SeedlingColors.morningDew.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? SeedlingColors.error
              : SeedlingColors.seedlingGreen,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: SeedlingTypography.body.copyWith(
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? SeedlingColors.error
              : SeedlingColors.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: SeedlingTypography.caption),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }

  Future<void> _selectReminderTime(BuildContext context, TimeOfDay initialTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: SeedlingColors.seedlingGreen,
              onPrimary: SeedlingColors.background,
              surface: SeedlingColors.cardBackground,
              onSurface: SeedlingColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != initialTime) {
      await ref.read(settingsProvider.notifier).setReminderTime(picked);
      // schedule with new time
      await NotificationService.instance.scheduleDailyReminder();
    }
  }

  void _showLanguageSelector({required bool isTarget}) {
    if (isTarget) {
      // For now, target language changes are handled by the Course Management system.
      // In a full implementation, this might navigate to AddCourseScreen.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use the Course Switcher on Home to change target language.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Select Native Language', style: SeedlingTypography.heading3),
          ),
          ListTile(title: const Text('English (US)'), onTap: () => Navigator.pop(context)),
          ListTile(title: const Text('Spanish'), onTap: () => Navigator.pop(context)),
          ListTile(title: const Text('French'), onTap: () => Navigator.pop(context)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showDailyGoalSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Words per day', style: SeedlingTypography.heading3),
          ),
          _goalTile(5, 'Casual'),
          _goalTile(10, 'Regular'),
          _goalTile(20, 'Serious'),
          _goalTile(50, 'Intense'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _goalTile(int goal, String label) {
    return ListTile(
      title: Text('$goal words ($label)'),
      onTap: () {
        ref.read(settingsProvider.notifier).setDailyWordGoal(goal);
        Navigator.pop(context);
      },
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? Your local data will be synced to the cloud first.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'SIGN OUT',
              style: TextStyle(color: SeedlingColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetProgressDialog(dynamic activeCourse) {
    if (activeCourse == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SeedlingColors.cardBackground,
        title: const Text(
          'Reset Course?',
          style: TextStyle(color: SeedlingColors.textPrimary),
        ),
        content: Text(
          'This will permanently wipe all Spaced Repetition mastery data for ${activeCourse.targetLanguage.name}. This cannot be undone.',
          style: const TextStyle(color: SeedlingColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: SeedlingColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SeedlingColors.error,
            ),
            onPressed: () async {
              await DatabaseHelper().resetCourseProgress(
                activeCourse.nativeLanguage.code, 
                activeCourse.targetLanguage.code
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Course progress reset.')),
                );
              }
            },
            child: const Text('RESET', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SeedlingColors.cardBackground,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: SeedlingColors.textPrimary),
        ),
        content: const Text(
          'This action will clear all your local data and sign you out. To permanently delete your remote Supabase account, please contact support.',
          style: TextStyle(color: SeedlingColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: SeedlingColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().clearUserData();
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'CLEAR & LOGOUT',
              style: TextStyle(color: SeedlingColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
