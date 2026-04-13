import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../widgets/mascot.dart';
import '../widgets/auth_gate.dart';
import '../models/course.dart';
import '../providers/course_provider.dart';
import '../services/vocabulary_service.dart';
import 'package:twemoji/twemoji.dart';
import 'package:confetti/confetti.dart';
import '../widgets/animations.dart';
import '../services/haptic_service.dart';

// ============================================================================
// ONBOARDING FLOW
// Language selection, goal setting, and feature introduction for new users
// ============================================================================

final onboardingControllerProvider =
    ChangeNotifierProvider<OnboardingController>(
      (ref) => OnboardingController(),
    );

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

  void toggleNotifications() {
    _enableNotifications = !_enableNotifications;
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
      debugPrint(
        'Seedling: Populating vocabulary for ${nativeLang.code} -> ${targetLang.code}...',
      );
      await VocabularyService.populateCourse(nativeLang.code, targetLang.code);
      debugPrint('Seedling: Vocabulary population complete.');

      // Navigate to auth gate (which handles login or home)
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
      }
    } catch (e, stack) {
      debugPrint('Seedling Onboarding Error: $e');
      debugPrint(stack.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up your course: $e'),
            backgroundColor: SeedlingColors.error,
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

// ─────────────────────────────────────────────────────────────────────────────
//  Onboarding Screen — Premium Guided Experience
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  MascotState _getMascotState() {
    switch (_currentPage) {
      case 0:
        return MascotState.happy;
      case 1:
        return MascotState.thinking; // Native language
      case 2:
        return MascotState.excited; // Target language
      case 3:
        return MascotState.thinking; // Daily goal
      case 4:
        return MascotState.happy; // Reminders
      case 5:
        return MascotState.idle; // Features
      case 6:
        return MascotState.celebrating; // Get started
      default:
        return MascotState.idle;
    }
  }

  void _nextPage(OnboardingController controller) {
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      HapticService.selection();
    } else {
      HapticService.medium();
      controller.completeOnboarding(context, ref);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      HapticService.selection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(onboardingControllerProvider);

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: Stack(
        children: [
          // Background accents
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header: Progress & Mascot
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      // Linear progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 8,
                          width: double.infinity,
                          child: LinearProgressIndicator(
                            value: (_currentPage + 1) / 7,
                            backgroundColor: SeedlingColors.water.withValues(
                              alpha: 0.1,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              SeedlingColors.seedlingGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Animated Mascot
                      SizedBox(
                        height: 120,
                        child: SeedlingMascot(
                          state: _getMascotState(),
                          size: 100,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                      if (page == 6) {
                        _confettiController.play();
                      }
                    },
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

                // Footer Actions
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        TextButton(
                          onPressed: _previousPage,
                          child: Text(
                            'Back',
                            style: SeedlingTypography.body.copyWith(
                              color: SeedlingColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 60),

                      // Indicators
                      Row(
                        children: List.generate(
                          7,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? SeedlingColors.seedlingGreen
                                  : SeedlingColors.water.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      ElevatedButton(
                        onPressed: controller.canProceed()
                            ? () => _nextPage(controller)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SeedlingColors.seedlingGreen,
                          foregroundColor: SeedlingColors.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentPage == 6 ? 'Start' : 'Next',
                          style: SeedlingTypography.body.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                SeedlingColors.seedlingGreen,
                SeedlingColors.freshSprout,
                SeedlingColors.water,
                SeedlingColors.sunlight,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================ STEP 1: WELCOME ================

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return FadeInStaggered(
      index: 0,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                'Welcome to Seedling',
                style: SeedlingTypography.heading1.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              Text(
                'Grow your vocabulary naturally, one word at a time. Let\'s set up your learning journey.',
                style: SeedlingTypography.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Feature highlights
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingAnimation(
                    duration: const Duration(milliseconds: 2200),
                    child: _buildHighlightItem('🌱', 'Learn'),
                  ),
                  const SizedBox(width: 30),
                  FloatingAnimation(
                    duration: const Duration(milliseconds: 2500),
                    distance: 10,
                    child: _buildHighlightItem('🔥', 'Streak'),
                  ),
                  const SizedBox(width: 30),
                  FloatingAnimation(
                    duration: const Duration(milliseconds: 1800),
                    child: _buildHighlightItem('🏆', 'Achieve'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightItem(String emoji, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.deepRoot.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: SeedlingTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ================ STEP 2: NATIVE LANGUAGE ================

class NativeLanguageStep extends ConsumerStatefulWidget {
  const NativeLanguageStep({super.key});

  @override
  ConsumerState<NativeLanguageStep> createState() => _NativeLanguageStepState();
}

class _NativeLanguageStepState extends ConsumerState<NativeLanguageStep> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(onboardingControllerProvider);

    final filteredLanguages = Language.all.where((lang) {
      final query = _searchQuery.toLowerCase();
      return lang.name.toLowerCase().contains(query);
    }).toList();

    return FadeInStaggered(
      index: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What\'s your native language?',
              style: SeedlingTypography.heading2,
            ),
            const SizedBox(height: 10),
            Text(
              'We\'ll use this to show you translations and explanations.',
              style: SeedlingTypography.body,
            ),
            const SizedBox(height: 20),

            // Search bar
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search languages...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: SeedlingColors.textSecondary,
                ),
                filled: true,
                fillColor: SeedlingColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: SeedlingColors.seedlingGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Language list
            Expanded(
              child: filteredLanguages.isEmpty
                  ? const NoResultsView(
                      title: 'Language Not Found',
                      message:
                          'We haven\'t added this one yet! We\'re growing our garden daily.',
                    )
                  : ListView.builder(
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = filteredLanguages[index];
                        final isSelected = controller.nativeLanguage == lang.code;

                        return GestureDetector(
                          onTap: () {
                            HapticService.light();
                            controller.setNativeLanguage(lang.code);
                            FocusScope.of(context).unfocus();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? SeedlingColors.seedlingGreen.withValues(
                                      alpha: 0.1,
                                    )
                                  : SeedlingColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? SeedlingColors.seedlingGreen
                                    : SeedlingColors.morningDew.withValues(
                                        alpha: 0.3,
                                      ),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: SeedlingColors.seedlingGreen
                                            .withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Twemoji(emoji: lang.flag, height: 24, width: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    lang.name,
                                    style: SeedlingTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

// ================ STEP 3: TARGET LANGUAGE ================

class TargetLanguageStep extends ConsumerStatefulWidget {
  const TargetLanguageStep({super.key});

  @override
  ConsumerState<TargetLanguageStep> createState() => _TargetLanguageStepState();
}

class _TargetLanguageStepState extends ConsumerState<TargetLanguageStep> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(onboardingControllerProvider);

    final filteredLanguages = Language.all.where((lang) {
      final query = _searchQuery.toLowerCase();
      return lang.name.toLowerCase().contains(query);
    }).toList();

    return FadeInStaggered(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What do you want to learn?',
              style: SeedlingTypography.heading2,
            ),
            const SizedBox(height: 10),
            Text(
              'Choose the language you want to grow your vocabulary in.',
              style: SeedlingTypography.body,
            ),
            const SizedBox(height: 20),

            // Search bar
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search languages...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: SeedlingColors.textSecondary,
                ),
                filled: true,
                fillColor: SeedlingColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: SeedlingColors.seedlingGreen,
                    width: 2,
                  ),
                ),
              ),
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
                  borderRadius: BorderRadius.circular(16),
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

            // Language list
            Expanded(
              child: filteredLanguages.isEmpty
                  ? const NoResultsView(
                      title: 'Language Not Found',
                      message:
                          'We haven\'t added this one yet! We\'re growing our garden daily.',
                    )
                  : ListView.builder(
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = filteredLanguages[index];
                        final isSelected = controller.targetLanguage == lang.code;

                        return GestureDetector(
                          onTap: () {
                            HapticService.light();
                            controller.setTargetLanguage(lang.code);
                            FocusScope.of(context).unfocus();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? SeedlingColors.seedlingGreen.withValues(
                                      alpha: 0.1,
                                    )
                                  : SeedlingColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? SeedlingColors.seedlingGreen
                                    : SeedlingColors.morningDew.withValues(
                                        alpha: 0.3,
                                      ),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: SeedlingColors.seedlingGreen
                                            .withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Twemoji(emoji: lang.flag, height: 32, width: 32),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    lang.name,
                                    style: SeedlingTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
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

    return FadeInStaggered(
      index: 3,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set your daily goal',
                          style: SeedlingTypography.heading2,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'How many words do you want to learn each day?',
                          style: SeedlingTypography.body,
                        ),
                      ],
                    ),
                  ),
                  GoalGrowthIndicator(goal: controller.dailyGoal),
                ],
              ),
              const SizedBox(height: 20),

              // Goal options
              ...goalOptions.map((goal) {
                final isSelected = controller.dailyGoal == goal;

                return GestureDetector(
                  onTap: () {
                    HapticService.light();
                    controller.setDailyGoal(goal);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SeedlingColors.seedlingGreen.withValues(alpha: 0.1)
                          : SeedlingColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? SeedlingColors.seedlingGreen
                            : SeedlingColors.morningDew.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: SeedlingColors.seedlingGreen.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SeedlingColors.seedlingGreen
                                : SeedlingColors.morningDew.withValues(
                                    alpha: 0.2,
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$goal',
                              style: SeedlingTypography.heading2.copyWith(
                                color: isSelected
                                    ? SeedlingColors.textPrimary
                                    : SeedlingColors.textSecondary,
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
                                  fontWeight: FontWeight.bold,
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

              const SizedBox(height: 40),

              // Info tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SeedlingColors.water.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: SeedlingColors.water),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'Tip: Consistency matters more than quantity. Start small and build up!',
                        style: SeedlingTypography.caption.copyWith(
                          color: SeedlingColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
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

    return FadeInStaggered(
      index: 4,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Learning reminders', style: SeedlingTypography.heading2),
              const SizedBox(height: 10),
              Text(
                'Get notified to maintain your streak and reach your daily goal.',
                style: SeedlingTypography.body,
              ),
              const SizedBox(height: 40),

              // Notification toggle
              GestureDetector(
                onTap: controller.toggleNotifications,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: SeedlingColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: controller.enableNotifications
                          ? SeedlingColors.seedlingGreen
                          : SeedlingColors.morningDew.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SeedlingColors.deepRoot.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SeedlingColors.morningDew.withValues(
                            alpha: 0.3,
                          ),
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
                      const Icon(
                        Icons.chevron_right,
                        color: SeedlingColors.textSecondary,
                      ),
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
                            ? SeedlingColors.seedlingGreen.withValues(
                                alpha: 0.2,
                              )
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
                          Text(
                            'Play sounds during learning',
                            style: SeedlingTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: controller.enableSounds,
                      onChanged: (value) => ref
                          .read(onboardingControllerProvider.notifier)
                          .setSounds(value),
                      activeThumbColor: SeedlingColors.seedlingGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
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
      title: '${Language.all.length} Languages',
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
          Text('What you can do', style: SeedlingTypography.heading2),
          const SizedBox(height: 10),
          Text(
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
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
                    color: SeedlingColors.textPrimary,
                    size: 60,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'You\'re all set!',
                    style: SeedlingTypography.heading2.copyWith(
                      color: SeedlingColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSummaryRow(
                    'Native',
                    _getLanguageName(controller.nativeLanguage),
                  ),
                  const Divider(
                    color: SeedlingColors.morningDew,
                    thickness: 0.2,
                  ),
                  _buildSummaryRow(
                    'Learning',
                    _getLanguageName(controller.targetLanguage),
                  ),
                  const Divider(
                    color: SeedlingColors.morningDew,
                    thickness: 0.2,
                  ),
                  _buildSummaryRow(
                    'Daily Goal',
                    '${controller.dailyGoal} words',
                  ),
                  const Divider(
                    color: SeedlingColors.morningDew,
                    thickness: 0.2,
                  ),
                  _buildSummaryRow(
                    'Reminders',
                    controller.enableNotifications ? 'Enabled' : 'Disabled',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Ready to start your learning journey?',
              style: SeedlingTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            Text(
              'You can change these settings anytime in the app.',
              style: SeedlingTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SeedlingTypography.caption),
          Text(
            value,
            style: SeedlingTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: SeedlingColors.textPrimary,
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

// ─────────────────────────────────────────────────────────────────────────────
//  NoResultsView — Mascot feedback for empty states
// ─────────────────────────────────────────────────────────────────────────────

class NoResultsView extends StatelessWidget {
  final String title;
  final String message;

  const NoResultsView({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SeedlingMascot(state: MascotState.thinking, size: 120),
            const SizedBox(height: 20),
            Text(title, style: SeedlingTypography.heading3),
            const SizedBox(height: 8),
            Text(
              message,
              style: SeedlingTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GoalGrowthIndicator — Visual feedback for goal intensity
// ─────────────────────────────────────────────────────────────────────────────

class GoalGrowthIndicator extends StatelessWidget {
  final int goal;

  const GoalGrowthIndicator({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    double scale = 0.5 + (goal / 30 * 1.0);
    int leaves = (goal / 5).floor().clamp(1, 5);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          transform: Matrix4.identity()..scale(scale),
          transformAlignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  leaves,
                  (i) => const Text('🍃', style: TextStyle(fontSize: 14)),
                ),
              ),
              const Text('🌱', style: TextStyle(fontSize: 32)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          goal >= 20 ? 'Intense!' : 'Cool',
          style: SeedlingTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: SeedlingColors.seedlingGreen,
          ),
        ),
      ],
    );
  }
}
