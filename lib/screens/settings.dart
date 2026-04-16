import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../core/page_route.dart';
import '../widgets/cards.dart';
import '../widgets/buttons.dart';
import '../widgets/notifications.dart';
import '../widgets/mascot.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../providers/app_providers.dart';
import '../providers/course_provider.dart';
import '../database/database_helper.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../services/subscription_service.dart';
import 'settings/subscription_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SubscriptionService().refreshSubscription();
      if (mounted) ref.invalidate(isPremiumProvider);
    });
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
      curve: Interval(
        (index * 0.1).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
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
      // Use platformDefault to prefer in-app browser for web links (more professional)
      // mailto handles itself via external app
      await launchUrl(
        uri,
        mode: uri.scheme == 'mailto'
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    }
  }

  void _contactSupport(String? userName) {
    final String subject = 'Seedling Support Request - ${userName ?? 'Guest'}';
    final String body = '\n\n---\nApp Version: 1.0.0\nPlatform: Windows';
    final String url =
        'mailto:seedlingapp.team@gmail.com?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
    _launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPremium = ref.watch(isPremiumProvider).value ?? false;
    final user = AuthService().currentUser;
    final isAuthenticated = AuthService().isAuthenticated;
    final activeCourse = ref.watch(courseProvider).activeCourse;
    final profileAsync = ref.watch(userProfileProvider);

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
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _staggeredSlide(
            0,
            profileAsync.when(
              data: (profile) => _buildUserProfileCard(profile, isPremium),
              loading: () => _buildUserProfileSkeleton(),
              error: (_, __) => _buildUserProfileCard({
                'display_name':
                    user?.userMetadata?['display_name'] ?? 'Guest Learner',
              }, isPremium),
            ),
          ),
          const SizedBox(height: 20),

          _staggeredSlide(
            1,
            isPremium ? _buildPremiumActiveStatus() : _buildPremiumBanner(),
          ),
          const SizedBox(height: 30),

          // Account Section
          _staggeredSlide(2, _buildSectionHeader('Account')),
          _staggeredSlide(
            2,
            GrowingCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildToggleTile(
                    Icons.sync,
                    'Automatic Cloud Sync',
                    'Keep data safe across devices',
                    settings.cloudSyncEnabled,
                    (val) async {
                      HapticService.lightTap();
                      await ref
                          .read(settingsProvider.notifier)
                          .setCloudSyncEnabled(val);
                      if (!context.mounted) return;
                      SeedlingNotifications.showSnackBar(
                        context,
                        message: val ? 'Cloud sync enabled' : 'Cloud sync disabled',
                        isError: false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Learning Preferences
          _staggeredSlide(3, _buildSectionHeader('Learning Preferences')),
          _staggeredSlide(
            3,
            GrowingCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildActionTile(
                    Icons.language,
                    'Target Language',
                    activeCourse?.targetLanguage.name ?? 'None selected',
                    () => _showLanguageSelector(
                      isTarget: true,
                      currentCode: activeCourse?.targetLanguage.code ?? 'es',
                    ),
                  ),
                  _buildActionTile(
                    Icons.person_pin,
                    'Native Language',
                    _getLanguageName(settings.nativeLanguageCode),
                    () => _showLanguageSelector(
                      isTarget: false,
                      currentCode: settings.nativeLanguageCode,
                    ),
                  ),
                  _buildActionTile(
                    Icons.flag,
                    'Daily Word Goal',
                    '${settings.dailyWordGoal} words per day',
                    () => _showDailyGoalSelector(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Study Environment
          _staggeredSlide(4, _buildSectionHeader('Study Environment')),
          _staggeredSlide(
            4,
            _buildStudyEnvironmentCard(settings),
          ),
          const SizedBox(height: 30),

          // Notifications & Sound
          _staggeredSlide(5, _buildSectionHeader('Notifications & Sound')),
          _staggeredSlide(
            5,
            GrowingCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildToggleTile(
                    Icons.notifications_active,
                    'Lesson Reminders',
                    'Daily nudge to keep growing',
                    settings.notificationsEnabled,
                    (val) async {
                      HapticService.lightTap();
                      await ref
                          .read(settingsProvider.notifier)
                          .toggleNotifications(val);
                      if (!context.mounted) return;
                      SeedlingNotifications.showSnackBar(
                        context,
                        message: val ? 'Reminders enabled' : 'Reminders disabled',
                        isError: false,
                      );
                    },
                  ),
                  if (settings.notificationsEnabled)
                    _buildActionTile(
                      Icons.access_time,
                      'Reminder Time',
                      settings.reminderTime.format(context),
                      () => _selectReminderTime(context, settings.reminderTime),
                    ),
                  _buildToggleTile(
                    Icons.volume_up,
                    'Sound Effects',
                    'Tactile feedback during lessons',
                    settings.soundEffectsEnabled,
                    (val) => ref
                        .read(settingsProvider.notifier)
                        .toggleSoundEffects(val),
                  ),
                  _buildToggleTile(
                    Icons.surround_sound_outlined,
                    'Ambient Soundscapes',
                    'Background audio during study sessions',
                    AudioService.instance.ambientEnabled,
                    (val) {
                      HapticService.lightTap();
                      AudioService.instance.setAmbientEnabled(val);
                      if (val) {
                        AudioService.instance.updateStudyEnvironment();
                      }
                      setState(() {}); // refresh toggle visual
                    },
                  ),
                  _buildToggleTile(
                    Icons.vibration,
                    'Haptic Feedback',
                    'Physical vibration for positive actions',
                    settings.hapticsEnabled,
                    (val) async {
                      HapticService.selectionClick();
                      await ref
                          .read(settingsProvider.notifier)
                          .toggleHaptics(val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Support & Legal
          _staggeredSlide(5, _buildSectionHeader('Support & Legal')),
          _staggeredSlide(
            5,
            GrowingCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildActionTile(
                    Icons.help_outline,
                    'Help Center',
                    'Guides and FAQ',
                    () => _launchUrl('https://www.seedlinglanguages.com/help'),
                  ),
                  _buildActionTile(
                    Icons.mail_outline,
                    'Contact Support',
                    'Get human help',
                    () => _contactSupport(user?.userMetadata?['display_name']),
                  ),
                  _buildActionTile(
                    Icons.description_outlined,
                    'Privacy Policy',
                    'Data protection',
                    () => _launchUrl('https://www.seedlinglanguages.com/privacy'),
                  ),
                  _buildActionTile(
                    Icons.gavel_outlined,
                    'Terms of Service',
                    'App rules',
                    () => _launchUrl('https://www.seedlinglanguages.com/terms'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),



          // Danger Zone
          _staggeredSlide(
            6,
            _buildSectionHeader('Danger Zone', isDestructive: true),
          ),
          _staggeredSlide(
            6,
            GrowingCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (isAuthenticated)
                    _buildActionTile(
                      Icons.logout,
                      'Sign Out',
                      'Log out of your account',
                      () => _showSignOutDialog(),
                      isDestructive: true,
                    ),
                  _buildActionTile(
                    Icons.restart_alt,
                    'Reset Course Progress',
                    'Wipe SRS data for current language',
                    () => _showResetProgressDialog(activeCourse),
                    isDestructive: true,
                  ),
                  _buildActionTile(
                    Icons.delete_forever,
                    'Delete Account',
                    'Permanently remove all data',
                    () => _showDeleteAccountDialog(),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          _buildFooter(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      default:
        return code.toUpperCase();
    }
  }

  Widget _buildUserProfileSkeleton() {
    return GrowingCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: SeedlingColors.morningDew.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: SeedlingColors.morningDew.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: SeedlingColors.morningDew.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(Map<String, dynamic> profile, bool isPremium) {
    final displayName = profile['display_name'] ?? 'Guest Learner';
    final email = profile['email'] ?? '';
    final initials = displayName
        .substring(0, (displayName.length > 2 ? 2 : displayName.length))
        .toUpperCase();

    return GrowingCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: SeedlingColors.waterBlue.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: SeedlingColors.waterBlue,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: SeedlingTypography.heading2),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isPremium ? Icons.verified : Icons.account_circle,
                      size: 14,
                      color: isPremium
                          ? SeedlingColors.autumnGold
                          : SeedlingColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPremium ? 'Pro Member' : 'Free Learner',
                      style: SeedlingTypography.caption.copyWith(
                        color: isPremium
                            ? SeedlingColors.autumnGold
                            : SeedlingColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: SeedlingColors.textSecondary.withValues(alpha: 0.3),
          ),
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
              colors: [
                SeedlingColors.cardBackground,
                SeedlingColors.background,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SeedlingColors.autumnGold.withValues(
                alpha: 0.3 + 0.2 * pulse,
              ),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.autumnGold.withValues(
                  alpha: 0.15 + 0.1 * pulse,
                ),
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
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: SeedlingColors.autumnGold,
                  size: 36,
                ),
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
                          colors: const [
                            SeedlingColors.autumnGold,
                            Colors.white,
                            SeedlingColors.autumnGold,
                          ],
                          stops: [
                            (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                            _shimmerController.value.clamp(0.0, 1.0),
                            (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Seedling Pro Active',
                          style: SeedlingTypography.heading3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have access to all premium features.',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
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
          colors: [Color(0xFF0D3320), Color(0xFF1B5C35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.deepRoot.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: SeedlingColors.autumnGold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SeedlingColors.autumnGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: SeedlingColors.autumnGold, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: SeedlingTypography.heading3.copyWith(
                    color: SeedlingColors.autumnGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Unlock all languages, cloud backups, and remove ads.',
                  style: SeedlingTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OrganicButton(
            text: 'UPGRADE',
            onPressed: () async {
              await Navigator.push(
                context,
                SeedlingPageRoute(page: const SubscriptionScreen()),
              );
              if (!mounted) return;
              await SubscriptionService().refreshSubscription();
              ref.invalidate(isPremiumProvider);
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
        style: SeedlingTypography.body.copyWith(
          fontWeight: FontWeight.w600,
          color: value ? SeedlingColors.textPrimary : SeedlingColors.textSecondary,
        ),
      ),
      subtitle: Text(subtitle, style: SeedlingTypography.caption),
      trailing: Switch(
        value: value,
        onChanged: (val) {
          HapticService.selectionClick();
          onChanged(val);
        },
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
      onTap: () {
        HapticService.lightImpact();
        onTap();
      },
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

  Future<void> _selectReminderTime(
    BuildContext context,
    TimeOfDay initialTime,
  ) async {
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
      HapticService.selectionClick();
      await ref.read(settingsProvider.notifier).setReminderTime(picked);
      if (!mounted) return;
      // schedule with new time
      await NotificationService.instance.scheduleDailyReminder();
    }
  }

  Widget _buildStudyEnvironmentCard(SettingsState settings) {
    return GrowingCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ambient Background',
            style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAmbientOption('garden', '🌿', 'Garden', settings.selectedAmbientTrack),
                _buildAmbientOption('rain', '🌧️', 'Rain', settings.selectedAmbientTrack),
                _buildAmbientOption('forest', '🌲', 'Forest', settings.selectedAmbientTrack),
                _buildAmbientOption('ocean', '🌊', 'Ocean', settings.selectedAmbientTrack),
              ],
            ),
          ),
          const Divider(height: 32, color: SeedlingColors.cardBackground),
          Text(
            'Binaural Brainwaves',
            style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Layer subtle frequencies to tune your focus.',
            style: SeedlingTypography.caption,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: SeedlingColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildBrainwaveOption('none', 'None', settings.selectedBrainwaveType),
                _buildBrainwaveOption('alpha', 'Alpha (Focus)', settings.selectedBrainwaveType),
                _buildBrainwaveOption('beta', 'Beta (Alert)', settings.selectedBrainwaveType),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientOption(String id, String emoji, String label, String selectedId) {
    final isSelected = id == selectedId;
    return GestureDetector(
      onTap: () {
        HapticService.lightTap();
        ref.read(settingsProvider.notifier).setAmbientTrack(id);
        AudioService.instance.updateStudyEnvironment();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? SeedlingColors.seedlingGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? SeedlingColors.seedlingGreen : SeedlingColors.cardBackground,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: SeedlingTypography.caption.copyWith(
                color: isSelected ? SeedlingColors.seedlingGreen : SeedlingColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrainwaveOption(String id, String label, String selectedId) {
    final isSelected = id == selectedId;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService.selectionClick();
          ref.read(settingsProvider.notifier).setBrainwaveType(id);
          AudioService.instance.updateStudyEnvironment();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? SeedlingColors.seedlingGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: SeedlingTypography.caption.copyWith(
              color: isSelected ? SeedlingColors.background : SeedlingColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector({
    required bool isTarget,
    required String currentCode,
  }) {
    if (isTarget) {
      SeedlingNotifications.showDialog(
        context,
        title: 'Switching Courses',
        message: 'To switch your learning language, use the Course Switcher on the Home screen.\n\nTap the active course banner at the top of the Grow tab to change or add a language.',
        isError: false,
        mascotState: MascotState.thinking,
        buttonText: 'GO TO HOME',
        onConfirm: () {
          Navigator.pop(context); // close settings → back to Home
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: SeedlingColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Select Native Language',
              style: SeedlingTypography.heading3,
            ),
          ),
          _langTile('en', 'English (US)', currentCode),
          _langTile('es', 'Spanish', currentCode),
          _langTile('fr', 'French', currentCode),
          _langTile('de', 'German', currentCode),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _langTile(String code, String name, String currentCode) {
    final isSelected = code == currentCode;
    return ListTile(
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? SeedlingColors.seedlingGreen
              : SeedlingColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: SeedlingColors.seedlingGreen)
          : null,
      onTap: () {
        HapticService.selectionClick();
        ref.read(settingsProvider.notifier).setNativeLanguageCode(code);
        if (!context.mounted) return;
        Navigator.pop(context);
        SeedlingNotifications.showSnackBar(
          context,
          message: 'Native language set to $name',
          isError: false,
        );
      },
    );
  }

  void _showDailyGoalSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SeedlingColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Words per day', style: SeedlingTypography.heading3),
          ),
          _goalTile(5, 'Casual', ref.read(settingsProvider).dailyWordGoal),
          _goalTile(10, 'Regular', ref.read(settingsProvider).dailyWordGoal),
          _goalTile(20, 'Serious', ref.read(settingsProvider).dailyWordGoal),
          _goalTile(50, 'Intense', ref.read(settingsProvider).dailyWordGoal),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _goalTile(int goal, String label, int currentGoal) {
    final isSelected = goal == currentGoal;
    return ListTile(
      title: Text(
        '$goal words ($label)',
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? SeedlingColors.seedlingGreen
              : SeedlingColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: SeedlingColors.seedlingGreen)
          : null,
      onTap: () {
        HapticService.selectionClick();
        ref.read(settingsProvider.notifier).setDailyWordGoal(goal);
        ref.invalidate(userStatsProvider); // Refresh home progress
        Navigator.pop(context);
        SeedlingNotifications.showSnackBar(
          context,
          message: 'Daily goal set to $goal words',
          isError: false,
        );
      },
    );
  }

  void _showSignOutDialog() {
    SeedlingNotifications.showDialog(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out? Your local data will be synced to the cloud first.',
      isError: true, // Use error (sad/worried mascot) to indicate friction
      buttonText: 'SIGN OUT',
      onConfirm: () async {
        await AuthService().signOut();
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  void _showResetProgressDialog(dynamic activeCourse) {
    if (activeCourse == null) return;

    SeedlingNotifications.showDialog(
      context,
      title: 'Reset Course?',
      message: 'This will permanently wipe all Spaced Repetition mastery data for ${activeCourse.targetLanguage.name}. This cannot be undone.',
      isError: true,
      buttonText: 'RESET PROGRESS',
      onConfirm: () async {
        await DatabaseHelper().resetCourseProgress(
          activeCourse.nativeLanguage.code,
          activeCourse.targetLanguage.code,
        );
        if (context.mounted) {
          SeedlingNotifications.showSnackBar(
            context,
            message: 'Course progress reset.',
            isError: false,
          );
        }
      },
    );
  }

  void _showDeleteAccountDialog() {
    SeedlingNotifications.showDialog(
      context,
      title: 'Delete Account Permanently?',
      message: 'This will permanently delete your account and all progress from our servers. This action is irreversible and you will lose all mastered words and statistics.',
      isError: true,
      buttonText: 'DELETE PERMANENTLY',
      onConfirm: () async {
        try {
          // 1. Delete remote account (this will cascade to profiles, user_stats, etc)
          await AuthService().deleteAccount();
          
          // 2. Clear local data
          await DatabaseHelper().clearUserData();
          
          if (context.mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            SeedlingNotifications.showSnackBar(
              context,
              message: 'Account successfully deleted.',
              isError: false,
            );
          }
        } catch (e) {
          if (context.mounted) {
            SeedlingNotifications.showSnackBar(
              context,
              message: 'Error deleting account: $e',
              isError: true,
            );
          }
        }
      },
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Seedling Version 1.0.0',
          style: SeedlingTypography.caption.copyWith(
            color: SeedlingColors.textSecondary.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2026 Amos languages',
          style: SeedlingTypography.caption.copyWith(
            color: SeedlingColors.textSecondary.withOpacity(0.3),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          width: 40,
          color: SeedlingColors.seedlingGreen.withOpacity(0.1),
        ),
      ],
    );
  }
}

