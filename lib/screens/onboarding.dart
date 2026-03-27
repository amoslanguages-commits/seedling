import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../widgets/mascot.dart';
import '../widgets/buttons.dart';
import '../widgets/auth_gate.dart';
import '../models/course.dart';
import '../providers/course_provider.dart';
import '../services/vocabulary_service.dart';
import 'package:twemoji/twemoji.dart';

// ============================================================================
// ONBOARDING FLOW
// Language selection, goal setting, and feature introduction for new users
// ============================================================================

final onboardingControllerProvider = ChangeNotifierProvider<OnboardingController>((ref) => OnboardingController());

// ================ ONBOARDING CONTROLLER ================

class OnboardingController extends ChangeNotifier {
  int _currentPage = 0;
  final PageController pageController = PageController();
  
  // User preferences collected during onboarding
  String _nativeLanguage = 'en-US';
  String _targetLanguage = 'es-ES';
  int _dailyGoal = 10;
  bool _enableNotifications = true;
  bool _enableSounds = true;
  TimeOfDay? _reminderTime;
  bool _isCompleting = false;
  
  int get currentPage => _currentPage;
  String get nativeLanguage => _nativeLanguage;
  String get targetLanguage => _targetLanguage;
  int get dailyGoal => _dailyGoal;
  bool get enableNotifications => _enableNotifications;
  bool get enableSounds => _enableSounds;
  TimeOfDay? get reminderTime => _reminderTime;
  bool get isCompleting => _isCompleting;
  
  final List<OnboardingStep> steps = [
    OnboardingStep.welcome,
    OnboardingStep.nativeLanguage,
    OnboardingStep.targetLanguage,
    OnboardingStep.dailyGoal,
    OnboardingStep.reminders,
    OnboardingStep.features,
    OnboardingStep.getStarted,
  ];
  
  void nextPage() {
    if (_currentPage < steps.length - 1) {
      _currentPage++;
      pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      notifyListeners();
    }
  }
  
  void previousPage() {
    if (_currentPage > 0) {
      _currentPage--;
      pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      notifyListeners();
    }
  }
  
  void setNativeLanguage(String code) {
    _nativeLanguage = code;
    notifyListeners();
  }
  
  void setTargetLanguage(String code) {
    _targetLanguage = code;
    notifyListeners();
  }
  
  void setDailyGoal(int goal) {
    _dailyGoal = goal;
    notifyListeners();
  }
  
  void setNotifications(bool enabled) {
    _enableNotifications = enabled;
    notifyListeners();
  }
  
  void setSounds(bool enabled) {
    _enableSounds = enabled;
    notifyListeners();
  }
  
  void setReminderTime(TimeOfDay time) {
    _reminderTime = time;
    notifyListeners();
  }
  
  Future<void> completeOnboarding(BuildContext context, WidgetRef ref) async {
    if (_isCompleting) return;
    
    _isCompleting = true;
    notifyListeners();
    
    try {
      // Save preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('native_language', _nativeLanguage);
      await prefs.setString('learning_language', _targetLanguage);
      await prefs.setInt('daily_goal', _dailyGoal);
      await prefs.setBool('notifications_enabled', _enableNotifications);
      await prefs.setBool('sounds_enabled', _enableSounds);
      await prefs.setBool('onboarding_completed', true);
      
      if (_reminderTime != null) {
        await prefs.setInt('reminder_hour', _reminderTime!.hour);
        await prefs.setInt('reminder_minute', _reminderTime!.minute);
      }
      
      // Auto-create course from onboarding languages
      final nativeLang = Language.all.firstWhere(
        (l) => l.code == _nativeLanguage,
        orElse: () => Language.all.first,
      );
      final targetLang = Language.all.firstWhere(
        (l) => l.code == _targetLanguage,
        orElse: () => Language.all.last,
      );

      final newCourse = Course(
        id: '${nativeLang.code}_${targetLang.code}_${DateTime.now().millisecondsSinceEpoch}',
        nativeLanguage: nativeLang,
        targetLanguage: targetLang,
      );

      // Add course and set as active
      await ref.read(courseProvider.notifier).addCourse(newCourse);
      await ref.read(courseProvider.notifier).setActive(newCourse.id);

      // Populate database with vocabulary mapping for this course
      debugPrint('Seedling: Populating vocabulary for ${nativeLang.code} -> ${targetLang.code}...');
      await VocabularyService.populateCourse(nativeLang.code, targetLang.code);
      debugPrint('Seedling: Vocabulary population complete.');

      // Navigate to auth gate (which handles login or home)
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    } catch (e, stack) {
      debugPrint('Seedling Onboarding Error: $e');
      debugPrint(stack.toString());
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up your course: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isCompleting = false;
      notifyListeners();
    }
  }
  
  bool canProceed() {
    switch (steps[_currentPage]) {
      case OnboardingStep.nativeLanguage:
        return _nativeLanguage.isNotEmpty;
      case OnboardingStep.targetLanguage:
        return _targetLanguage.isNotEmpty && _targetLanguage != _nativeLanguage;
      case OnboardingStep.dailyGoal:
        return _dailyGoal > 0;
      default:
        return true;
    }
  }
}

enum OnboardingStep {
  welcome,
  nativeLanguage,
  targetLanguage,
  dailyGoal,
  reminders,
  features,
  getStarted,
}

// ================ ONBOARDING SCREEN ================

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onboardingControllerProvider);
    
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (except on last page)
            if (controller.currentPage < controller.steps.length - 1)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: controller.isCompleting 
                        ? null 
                        : () => controller.completeOnboarding(context, ref),
                    child: Text(
                      'Skip',
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (controller.currentPage + 1) / controller.steps.length,
                  backgroundColor: SeedlingColors.morningDew.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    SeedlingColors.seedlingGreen,
                  ),
                  minHeight: 8,
                ),
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView(
                controller: controller.pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const WelcomeStep(),
                  const NativeLanguageStep(),
                  const TargetLanguageStep(),
                  DailyGoalStep(),
                  const RemindersStep(),
                  FeaturesStep(),
                  const GetStartedStep(),
                ],
              ),
            ),
            
            // Navigation buttons
            _buildNavigationBar(context, ref, controller),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavigationBar(BuildContext context, WidgetRef ref, OnboardingController controller) {
    final isFirstPage = controller.currentPage == 0;
    final isLastPage = controller.currentPage == controller.steps.length - 1;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back button
            if (!isFirstPage)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: controller.previousPage,
                color: SeedlingColors.textPrimary,
              )
            else
              const SizedBox(width: 48),
            
            const Spacer(),
            
            // Next/Get Started button
            OrganicButton(
              text: isLastPage ? 'Get Started' : 'Next',
              loading: controller.isCompleting,
              onPressed: !controller.isCompleting && controller.canProceed()
                  ? () {
                      if (isLastPage) {
                        controller.completeOnboarding(context, ref);
                      } else {
                        controller.nextPage();
                      }
                    }
                  : null,
              width: 150,
              height: 56,
            ),
          ],
        ),
      ),
    );
  }
}

// ================ STEP 1: WELCOME ================

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated mascot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.5 + (value * 0.5),
                child: const SeedlingMascot(
                  size: 150,
                  state: MascotState.celebrating,
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          Text(
            'Welcome to Seedling',
            style: SeedlingTypography.heading1.copyWith(fontSize: 32),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          const Text(
            'Grow your vocabulary naturally, one word at a time. Let\'s set up your learning journey.',
            style: SeedlingTypography.bodyLarge,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          // Feature highlights
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHighlightItem('🌱', 'Learn'),
              const SizedBox(width: 30),
              _buildHighlightItem('🔥', 'Streak'),
              const SizedBox(width: 30),
              _buildHighlightItem('🏆', 'Achieve'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildHighlightItem(String emoji, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          label,
          style: SeedlingTypography.caption,
        ),
      ],
    );
  }
}

// ================ STEP 2: NATIVE LANGUAGE ================

class NativeLanguageStep extends ConsumerWidget {
  const NativeLanguageStep({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onboardingControllerProvider);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What\'s your native language?',
            style: SeedlingTypography.heading2,
          ),
          const SizedBox(height: 10),
          const Text(
            'We\'ll use this to show you translations and explanations.',
            style: SeedlingTypography.body,
          ),
          const SizedBox(height: 30),
          
          // Selected language display
          if (controller.nativeLanguage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SeedlingColors.seedlingGreen),
              ),
              child: Row(
                children: [
                  Twemoji(
                    emoji: Language.all
                        .firstWhere(
                          (l) => l.code == controller.nativeLanguage,
                          orElse: () => Language.all.first,
                        )
                        .flag,
                    height: 32,
                    width: 32,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected',
                          style: SeedlingTypography.caption,
                        ),
                        Text(
                          Language.all
                              .firstWhere(
                                (l) => l.code == controller.nativeLanguage,
                                orElse: () => Language.all.first,
                              )
                              .name,
                          style: SeedlingTypography.heading3,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: SeedlingColors.seedlingGreen),
                ],
              ),
            ),
          
          // Language grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: Language.all.length,
              itemBuilder: (context, index) {
                final lang = Language.all[index];
                final isSelected = controller.nativeLanguage == lang.code;
                
                return GestureDetector(
                  onTap: () => controller.setNativeLanguage(lang.code),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SeedlingColors.seedlingGreen.withValues(alpha: 0.1)
                          : SeedlingColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? SeedlingColors.seedlingGreen
                            : SeedlingColors.morningDew.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Twemoji(
                          emoji: lang.flag,
                          height: 24,
                          width: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                lang.name,
                                style: SeedlingTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: SeedlingColors.seedlingGreen,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================ STEP 3: TARGET LANGUAGE ================

class TargetLanguageStep extends ConsumerWidget {
  const TargetLanguageStep({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onboardingControllerProvider);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What do you want to learn?',
            style: SeedlingTypography.heading2,
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose the language you want to grow your vocabulary in.',
            style: SeedlingTypography.body,
          ),
          const SizedBox(height: 20),
          
          // Warning if same as native
          if (controller.targetLanguage == controller.nativeLanguage &&
              controller.targetLanguage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SeedlingColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: SeedlingColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Target language should be different from your native language',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Popular label
          Text(
            'Popular',
            style: SeedlingTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          
          // Language list
          Expanded(
            child: ListView.builder(
              itemCount: Language.all.length,
              itemBuilder: (context, index) {
                final lang = Language.all[index];
                final isSelected = controller.targetLanguage == lang.code;
                
                return GestureDetector(
                  onTap: () => controller.setTargetLanguage(lang.code),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SeedlingColors.seedlingGreen.withValues(alpha: 0.1)
                          : SeedlingColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? SeedlingColors.seedlingGreen
                            : SeedlingColors.morningDew.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Twemoji(
                          emoji: lang.flag,
                          height: 32,
                          width: 32,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    lang.name,
                                    style: SeedlingTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: SeedlingColors.seedlingGreen,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================ STEP 4: DAILY GOAL ================

class DailyGoalStep extends ConsumerWidget {
  DailyGoalStep({super.key});

  final List<int> goalOptions = [5, 10, 15, 20, 30];
  final Map<int, String> goalDescriptions = {
    5: 'Casual - 5 words/day',
    10: 'Regular - 10 words/day',
    15: 'Serious - 15 words/day',
    20: 'Intense - 20 words/day',
    30: 'Master - 30 words/day',
  };
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onboardingControllerProvider);
    
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set your daily goal',
            style: SeedlingTypography.heading2,
          ),
          const SizedBox(height: 10),
          const Text(
            'How many words do you want to learn each day? You can change this anytime.',
            style: SeedlingTypography.body,
          ),
          const SizedBox(height: 40),
          
          // Goal options
          ...goalOptions.map((goal) {
            final isSelected = controller.dailyGoal == goal;
            
            return GestureDetector(
              onTap: () => controller.setDailyGoal(goal),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SeedlingColors.seedlingGreen.withValues(alpha: 0.1)
                      : SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? SeedlingColors.seedlingGreen
                        : SeedlingColors.morningDew.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? SeedlingColors.seedlingGreen
                            : SeedlingColors.morningDew.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$goal',
                          style: SeedlingTypography.heading2.copyWith(
                            color: isSelected ? Colors.white : SeedlingColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goalDescriptions[goal]!.split(' - ')[1],
                            style: SeedlingTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(goal * 7)} words/week • ${(goal * 30)} words/month',
                            style: SeedlingTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: SeedlingColors.seedlingGreen,
                        size: 28,
                      ),
                  ],
                ),
              ),
            );
          }),
          
          const Spacer(),
          
          // Info tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SeedlingColors.water.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb, color: SeedlingColors.water),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Consistency matters more than quantity. Start small and build up!',
                    style: SeedlingTypography.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================ STEP 5: REMINDERS ================

class RemindersStep extends ConsumerWidget {
  const RemindersStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onboardingControllerProvider);
    
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learning reminders',
            style: SeedlingTypography.heading2,
          ),
          const SizedBox(height: 10),
          const Text(
            'Get notified to maintain your streak and reach your daily goal.',
            style: SeedlingTypography.body,
          ),
          const SizedBox(height: 40),
          
          // Notification toggle
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SeedlingColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: controller.enableNotifications
                        ? SeedlingColors.seedlingGreen.withValues(alpha: 0.2)
                        : SeedlingColors.morningDew.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: controller.enableNotifications
                        ? SeedlingColors.seedlingGreen
                        : SeedlingColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notifications',
                        style: SeedlingTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Daily reminders and streak alerts',
                        style: SeedlingTypography.caption,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: controller.enableNotifications,
                  onChanged: (value) => ref.read(onboardingControllerProvider.notifier).setNotifications(value),
                  activeThumbColor: SeedlingColors.seedlingGreen,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Reminder time picker (if notifications enabled)
          if (controller.enableNotifications)
            GestureDetector(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: controller.reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
                );
                if (time != null) {
                  ref.read(onboardingControllerProvider.notifier).setReminderTime(time);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.access_time),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reminder Time',
                            style: SeedlingTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            controller.reminderTime != null
                                ? 'Daily at ${controller.reminderTime!.format(context)}'
                                : 'Tap to set time',
                            style: SeedlingTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: SeedlingColors.textSecondary),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 20),
          
          // Sound toggle
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SeedlingColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: controller.enableSounds
                        ? SeedlingColors.seedlingGreen.withValues(alpha: 0.2)
                        : SeedlingColors.morningDew.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.volume_up,
                    color: controller.enableSounds
                        ? SeedlingColors.seedlingGreen
                        : SeedlingColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sound Effects',
                        style: SeedlingTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Play sounds during learning',
                        style: SeedlingTypography.caption,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: controller.enableSounds,
                  onChanged: (value) => ref.read(onboardingControllerProvider.notifier).setSounds(value),
                  activeThumbColor: SeedlingColors.seedlingGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================ STEP 6: FEATURES ================

class FeaturesStep extends StatelessWidget {
  FeaturesStep({super.key});

  final List<FeatureItem> features = [
    FeatureItem(
      icon: '🌱',
      title: 'Grow Your Garden',
      description: 'Watch your knowledge grow as you master new words',
    ),
    FeatureItem(
      icon: '🔥',
      title: 'Build Streaks',
      description: 'Learn every day to maintain your streak and earn bonuses',
    ),
    FeatureItem(
      icon: '🏆',
      title: 'Earn Achievements',
      description: 'Unlock achievements as you reach milestones',
    ),
    FeatureItem(
      icon: '🎯',
      title: 'Daily Challenges',
      description: 'Complete daily quests for extra XP and rewards',
    ),
    FeatureItem(
      icon: '📊',
      title: 'Track Progress',
      description: 'Monitor your learning with detailed statistics',
    ),
    FeatureItem(
      icon: '🌍',
      title: '121 Languages',
      description: 'Learn any language from any language',
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What you can do',
            style: SeedlingTypography.heading2,
          ),
          const SizedBox(height: 10),
          const Text(
            'Discover all the ways Seedling helps you learn.',
            style: SeedlingTypography.body,
          ),
          const SizedBox(height: 30),
          
          Expanded(
            child: ListView.builder(
              itemCount: features.length,
              itemBuilder: (context, index) {
                final feature = features[index];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SeedlingColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(feature.icon, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feature.title,
                              style: SeedlingTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feature.description,
                              style: SeedlingTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================ STEP 7: GET STARTED ================

class GetStartedStep extends ConsumerWidget {
  const GetStartedStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onboardingControllerProvider);
    
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  SeedlingColors.seedlingGreen,
                  SeedlingColors.deepRoot,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 20),
                Text(
                  'You\'re all set!',
                  style: SeedlingTypography.heading2.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSummaryRow(
                  'Native',
                  _getLanguageName(controller.nativeLanguage),
                ),
                const Divider(color: Colors.white24),
                _buildSummaryRow(
                  'Learning',
                  _getLanguageName(controller.targetLanguage),
                ),
                const Divider(color: Colors.white24),
                _buildSummaryRow(
                  'Daily Goal',
                  '${controller.dailyGoal} words',
                ),
                const Divider(color: Colors.white24),
                _buildSummaryRow(
                  'Reminders',
                  controller.enableNotifications ? 'Enabled' : 'Disabled',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          const Text(
            'Ready to start your learning journey?',
            style: SeedlingTypography.bodyLarge,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          const Text(
            'You can change these settings anytime in the app.',
            style: SeedlingTypography.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: SeedlingTypography.body.copyWith(
              color: Colors.white.withAlpha(230),
            ),
          ),
          Text(
            value,
            style: SeedlingTypography.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getLanguageName(String code) {
    try {
      return Language.all.firstWhere((l) => l.code == code).name;
    } catch (_) {
      // Fallback to a few common ones or just the code
      final languages = {
        'en-US': 'English (US)',
        'es-ES': 'Spanish (Spain)',
        'en': 'English',
        'es': 'Spanish',
      };
      return languages[code] ?? code;
    }
  }
}

// ================ SUPPORTING CLASSES ================



class FeatureItem {
  final String icon;
  final String title;
  final String description;
  
  FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

// ================ ONBOARDING GATE ================
// Check if onboarding is completed

class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkOnboardingStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final onboardingCompleted = snapshot.data ?? false;
        
        if (onboardingCompleted) {
          return const AuthGate(); // Navigates to EnhancedHomeScreen if authenticated
        } else {
          return const OnboardingScreen();
        }
      },
    );
  }
  
  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }
}
