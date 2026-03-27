import 'package:flutter/material.dart';
import '../core/page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../widgets/cards.dart';
import '../widgets/buttons.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../services/sync_manager.dart';
import '../services/cloud_backup_service.dart';
import 'settings/subscription_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEffectsEnabled = true;
  bool _darkMode = false;
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
        title: const Text(
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
                _buildActionTile(
                  Icons.cloud_upload,
                  'Manual Sync Now',
                  'Last synced: 10m ago',
                  () => _manualSync(),
                ),
                _buildActionTile(
                  Icons.backup,
                  'Backup Management',
                  'Create or restore database backups',
                  () => _showBackupOptions(),
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
                  'App Language',
                  'English (US)',
                  () => _showLanguageSelector(),
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
                _buildToggleTile(
                  Icons.volume_up,
                  'Sound Effects',
                  'Tactile feedback during lessons',
                  _soundEffectsEnabled,
                  (val) => setState(() => _soundEffectsEnabled = val),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Appearance
          _buildSectionHeader('Appearance'),
          GrowingCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildToggleTile(
                  Icons.dark_mode,
                  'Dark Mode',
                  'Save your eyes and battery',
                  _darkMode,
                  (val) => setState(() => _darkMode = val),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
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
          
          const Center(
            child: Column(
              children: [
                Text(
                  'Seedling v1.1.0 (Build 2024)',
                  style: SeedlingTypography.caption,
                ),
                SizedBox(height: 5),
                Text(
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
        gradient: LinearGradient(
          colors: [
            SeedlingColors.sunlight,
            Colors.orange.shade400,
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
          const Icon(Icons.star, color: Colors.white, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: SeedlingTypography.heading3.copyWith(color: Colors.white),
                ),
                Text(
                  'Unlock all languages, cloud backups, and remove ads.',
                  style: SeedlingTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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
  
  // Handlers
  
  Future<void> _manualSync() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      await SyncManager().syncToCloud();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync successful!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }
  
  void _showBackupOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: SeedlingColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Backup Management', style: SeedlingTypography.heading3),
            const SizedBox(height: 20),
            OrganicButton(
              text: 'CREATE NEW BACKUP',
              onPressed: () {
                Navigator.pop(context);
                _createBackup();
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _showRestoreList();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('RESTORE FROM CLOUD'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _createBackup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      await CloudBackupService().createBackup();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }
  
  void _showRestoreList() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final backups = await CloudBackupService().listBackups();
    
    if (mounted) {
      Navigator.pop(context);
      
      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backups found')),
        );
        return;
      }
      
      showModalBottomSheet(
        context: context,
        builder: (context) => ListView.builder(
          itemCount: backups.length,
          itemBuilder: (context, index) {
            final backup = backups[index];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text('Backup from ${backup.createdAt.toString().split('.')[0]}'),
              subtitle: Text('${(backup.size / 1024).toStringAsFixed(1)} KB'),
              onTap: () {
                Navigator.pop(context);
                _restoreBackup(backup.id);
              },
            );
          },
        ),
      );
    }
  }
  
  Future<void> _restoreBackup(String backupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text('This will overwrite your local progress. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('RESTORE')),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      try {
        await CloudBackupService().restoreFromBackup(backupId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Progress restored! Restarting app...')),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore failed: $e')),
          );
        }
      }
    }
  }
  
  void _showLanguageSelector() {
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
  
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This action cannot be undone. All your progress will be permanently lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
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
