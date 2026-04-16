import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/course.dart';
import '../../providers/course_provider.dart';
import '../../services/vocabulary_service.dart';
import '../../services/tts_service.dart';
import 'package:twemoji/twemoji.dart';
import '../../widgets/notifications.dart';

/// Full-page form to create a new course.
/// Lets the user pick native language and target language,
/// then saves and pops back to the home screen.
class AddCourseScreen extends ConsumerStatefulWidget {
  const AddCourseScreen({super.key});

  @override
  ConsumerState<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends ConsumerState<AddCourseScreen> {
  Language? _native;
  Language? _target;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default native to English
    _native = Language.byCode('en');
  }

  Future<void> _save() async {
    if (_native == null || _target == null) return;
    if (_native!.code == _target!.code) {
      SeedlingNotifications.showSnackBar(
        context,
        message: 'Native and target language must be different.',
      );
      return;
    }
    setState(() => _saving = true);
    final course = Course(
      id: const Uuid().v4(),
      nativeLanguage: _native!,
      targetLanguage: _target!,
    );

    // Populate the database with vocabulary for this new course pair
    await VocabularyService.populateCourse(_native!.code, _target!.code);

    // Pre-fetch the offline TTS model if necessary, showing progress on this screen
    try {
      await TtsService.instance.ensureModelReady(_target!.code);
    } catch (_) {
      // Ignored: If it fails, standard fallback logic applies during gameplay
    }

    await ref.read(courseProvider.notifier).addCourse(course);
    await ref.read(courseProvider.notifier).setActive(course.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: SeedlingColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Course', style: SeedlingTypography.heading3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview banner
              if (_target != null) ...[
                _CoursePreviewCard(native: _native, target: _target!),
                const SizedBox(height: 28),
              ],

              Text('I speak', style: SeedlingTypography.caption),
              const SizedBox(height: 8),
              _LanguagePicker(
                selected: _native,
                onChanged: (l) => setState(() => _native = l),
                exclude: _target?.code,
                hint: 'Select native language',
              ),

              const SizedBox(height: 20),

              Text('I want to learn', style: SeedlingTypography.caption),
              const SizedBox(height: 8),
              _LanguagePicker(
                selected: _target,
                onChanged: (l) => setState(() => _target = l),
                exclude: _native?.code,
                hint: 'Select target language',
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_target != null && !_saving) ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SeedlingColors.seedlingGreen,
                    foregroundColor: SeedlingColors.textPrimary,
                    disabledBackgroundColor: SeedlingColors.cardBackground,
                    disabledForegroundColor: SeedlingColors.textSecondary
                        .withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? ValueListenableBuilder<double?>(
                          valueListenable: TtsService.instance.downloadProgress,
                          builder: (context, progress, child) {
                            if (progress != null) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: SeedlingColors.cardBackground.withValues(alpha: 0.3),
                                      valueColor: AlwaysStoppedAnimation<Color>(SeedlingColors.textPrimary),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Downloading Audio... ${(progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: SeedlingColors.textPrimary,
                              ),
                            );
                          },
                        )
                      : const Text(
                          'Start Learning',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Preview Card ─────────────────────────────────────────────────────────────

class _CoursePreviewCard extends StatelessWidget {
  final Language? native;
  final Language target;

  const _CoursePreviewCard({required this.native, required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
            SeedlingColors.seedlingGreen.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: SeedlingColors.seedlingGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Twemoji(emoji: target.flag, height: 36, width: 36),
              if (native != null)
                Positioned(
                  bottom: -4,
                  right: -12,
                  child: Twemoji(emoji: native!.flag, height: 22, width: 22),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                target.name,
                style: SeedlingTypography.heading2.copyWith(
                  fontSize: 20,
                  color: SeedlingColors.seedlingGreen,
                ),
              ),
              if (native != null)
                Text('from ${native!.name}', style: SeedlingTypography.caption),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Language Picker ──────────────────────────────────────────────────────────

class _LanguagePicker extends StatelessWidget {
  final Language? selected;
  final ValueChanged<Language> onChanged;
  final String? exclude;
  final String hint;

  const _LanguagePicker({
    required this.selected,
    required this.onChanged,
    this.exclude,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final available = Language.all.where((l) => l.code != exclude).toList();

    return GestureDetector(
      onTap: () => _showPicker(context, available),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            if (selected != null) ...[
              Twemoji(emoji: selected!.flag, height: 24, width: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected!.name,
                  style: SeedlingTypography.heading3.copyWith(fontSize: 16),
                ),
              ),
            ] else
              Expanded(
                child: Text(
                  hint,
                  style: SeedlingTypography.body.copyWith(
                    color: SeedlingColors.textSecondary,
                  ),
                ),
              ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: SeedlingColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, List<Language> available) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguagePickerSheet(
        languages: available,
        selected: selected,
        onSelected: (l) {
          onChanged(l);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  final List<Language> languages;
  final Language? selected;
  final ValueChanged<Language> onSelected;

  const _LanguagePickerSheet({
    required this.languages,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.languages
        .where((l) => l.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: SeedlingColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SeedlingColors.cardBackground,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search language…',
                hintStyle: const TextStyle(color: SeedlingColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: SeedlingColors.textSecondary,
                ),
                filled: true,
                fillColor: SeedlingColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final lang = filtered[i];
                final isSelected = lang.code == widget.selected?.code;
                return ListTile(
                  leading: Twemoji(emoji: lang.flag, height: 26, width: 26),
                  title: Text(
                    lang.name,
                    style: SeedlingTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: SeedlingColors.seedlingGreen,
                        )
                      : null,
                  onTap: () => widget.onSelected(lang),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
