import 'package:flutter/material.dart';
import '../core/page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../widgets/cards.dart';
import '../widgets/buttons.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import 'settings/subscription_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEffectsEnabled = true;
  bool _hapticsEnabled = true; // Added Haptics
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0); // Default 8:00 PM
  final String _dailyGoal = '10'; // words/day
  
  @override
  Widget build(BuildContext context) {
    final isPremium = SubscriptionService().isPremium;
    final isAuthenticated = AuthService().isAuthenticated;
    
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
        title: Text(
          'Settings',
          style: SeedlingTypography.heading2,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Premium Banner
          if (!isPremium) _buildPremiumBanner(),
          
          const SizedBox(height: 25),
          
          // Account Section
          _buildSectionHeader('Account'),
          GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildToggleTile(
                  Icons.sync,
                  'Automatic Cloud Sync',
                  'Keep data safe across devices',
                  true,
                  (val) {},
                ),
                _buildToggleTile(
                  Icons.sync,
                  'Automatic Cloud Sync',
                  'Keep data safe across devices',
                  true,
                  (val) {},
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Learning Preferences
          _buildSectionHeader('Learning Preferences'),
          GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildActionTile(
                  Icons.language,
                  'Target Language',
                  'Spanish (ES)',
                  () => _showLanguageSelector(isTarget: true),
                ),
                _buildActionTile(
                  Icons.person_pin,
                  'Native Language',
                  'English (US)',
                  () => _showLanguageSelector(isTarget: false),
                ),
                _buildActionTile(
                  Icons.flag,
                  'Daily Word Goal',
                  '$_dailyGoal words per day',
                  () => _showDailyGoalSelector(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Notifications & Sound
          _buildSectionHeader('Notifications & Sound'),
          GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildToggleTile(
                  Icons.notifications_active,
                  'Lesson Reminders',
                  'Daily nudge to keep growing',
                  _notificationsEnabled,
                  (val) => setState(() => _notificationsEnabled = val),
                 ),
                 if (_notificationsEnabled)
                   _buildActionTile(
                     Icons.access_time,
                     'Reminder Time',
                     _reminderTime.format(context),
                     () => _selectReminderTime(context),
                   ),
                _buildToggleTile(
                  Icons.volume_up,
                  'Sound Effects',
                  'Tactile feedback during lessons',
                  _soundEffectsEnabled,
                  (val) => setState(() => _soundEffectsEnabled = val),
                ),
                _buildToggleTile(
                  Icons.vibration,
                  'Haptic Feedback',
                  'Physical vibration for positive actions',
                  _hapticsEnabled,
                  (val) => setState(() => _hapticsEnabled = val),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Appearance removed - we conform entirely to the Dark Botanical Theme

          const SizedBox(height: 10),
          
          // Support & Legal
          _buildSectionHeader('Support & Legal'),
          GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildActionTile(Icons.help_outline, 'Help Center', 'Guides and FAQ', () {}),
                _buildActionTile(Icons.mail_outline, 'Contact Support', 'Get human help', () {}),
                _buildActionTile(Icons.description_outlined, 'Privacy Policy', 'Data protection', () {}),
                _buildActionTile(Icons.gavel_outlined, 'Terms of Service', 'App rules', () {}),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Danger Zone
          _buildSectionHeader('Danger Zone', isDestructive: true),
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
                  () => _showResetProgressDialog(),
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
  
  Widget _buildPremiumBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            SeedlingColors.sunlight,
            SeedlingColors.seedlingGreen,
          ],
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
                  style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.background),
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
          color: isDestructive ? SeedlingColors.error : SeedlingColors.textSecondary,
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
      title: Text(title, style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.w600)),
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
          color: isDestructive ? SeedlingColors.error : SeedlingColors.seedlingGreen,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: SeedlingTypography.body.copyWith(
          fontWeight: FontWeight.w600,
          color: isDestructive ? SeedlingColors.error : SeedlingColors.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: SeedlingTypography.caption),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
  
  Future<void> _selectReminderTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
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
    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
      // Here you would save the actual preference to your DB or SharedPreferences
      // and call NotificationService's schedule method with the new time!
    }
  }

  void _showLanguageSelector({required bool isTarget}) {
    // Logic for language selector
  }
  
  void _showDailyGoalSelector() {
    // Logic for daily goal selector
  }
  
  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              AuthService().signOut();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('SIGN OUT', style: TextStyle(color: SeedlingColors.error)),
          ),
        ],
      ),
    );
  }
  
  void _showResetProgressDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SeedlingColors.cardBackground,
        title: const Text('Reset Course?', style: TextStyle(color: SeedlingColors.textPrimary)),
        content: const Text(
          'This will permanently wipe all Spaced Repetition mastery data for your current target language. This cannot be undone.',
          style: TextStyle(color: SeedlingColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: SeedlingColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SeedlingColors.error),
            onPressed: () {
              // DB Reset Logic Here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Course progress reset.')),
              );
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
        title: const Text('Delete Account', style: TextStyle(color: SeedlingColors.textPrimary)),
        content: const Text(
          'This action cannot be undone. All your progress will be permanently lost.',
          style: TextStyle(color: SeedlingColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('CANCEL', style: TextStyle(color: SeedlingColors.textSecondary))
          ),
          TextButton(
            onPressed: () {
              // Delete logic
            },
            child: const Text('DELETE', style: TextStyle(color: SeedlingColors.error)),
          ),
        ],
      ),
    );
  }
}
