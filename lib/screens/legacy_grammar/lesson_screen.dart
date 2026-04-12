import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/learning_path_model.dart';
import '../../services/haptic_service.dart';
import '../../services/voice_synthesis_service.dart';
import '../../services/grammar_progress_service.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  final Color themeColor;
  final String? conceptExplanation;
  final String nodeId;
  final String langCode;

  const LessonScreen({
    super.key,
    required this.lesson,
    required this.themeColor,
    required this.nodeId,
    required this.langCode,
    this.conceptExplanation,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _currentIndex = 0;
  bool _isChecking = false;
  bool _isSuccess = false;
  bool _showIntro = false;
  
  // State for Construct challenge
  List<String> _selectedWords = [];
  
  // State for ListenSelect challenge
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _showIntro = widget.conceptExplanation != null;
    if (!_showIntro) {
      _playCurrentChallengeAudio();
    }
  }

  void _playCurrentChallengeAudio() {
    final challenge = widget.lesson.challenges[_currentIndex];
    VoiceSynthesisService.instance.speak(challenge.targetText);
  }

  void _checkAnswer() {
    final challenge = widget.lesson.challenges[_currentIndex];
    bool correct = false;

    if (challenge.type == ChallengeType.construct) {
      if (_selectedWords.length == challenge.correctTokens.length) {
        correct = true;
        for (int i = 0; i < _selectedWords.length; i++) {
          if (_selectedWords[i] != challenge.correctTokens[i]) {
            correct = false;
            break;
          }
        }
      }
    } else if (challenge.type == ChallengeType.listenSelect) {
      correct = _selectedOption == challenge.correctOption;
    }

    setState(() {
      _isChecking = true;
      _isSuccess = correct;
    });

    if (correct) {
      HapticService.success();
    } else {
      HapticService.error();
    }
  }

  Future<void> _nextChallenge() async {
    if (_currentIndex < widget.lesson.challenges.length - 1) {
      setState(() {
        _currentIndex++;
        _isChecking = false;
        _isSuccess = false;
        _selectedWords = [];
        _selectedOption = null;
      });
      _playCurrentChallengeAudio();
    } else {
      // Save Progress
      await GrammarProgressService.instance.completeNode(widget.langCode, widget.nodeId);
      
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Node Mastered!', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: SeedlingColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return _buildIntroView();
    }

    final challenge = widget.lesson.challenges[_currentIndex];
    final progress = (_currentIndex) / widget.lesson.challenges.length;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
            minHeight: 8,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.type == ChallengeType.construct ? 'Translate this sentence' : 'What did you hear?',
                      style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    
                    // Native Instruction / Prompt Area
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: SeedlingColors.cardBackground,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (challenge.type == ChallengeType.construct) ...[
                            Text(
                              challenge.phoneticText,
                              style: SeedlingTypography.body.copyWith(
                                color: widget.themeColor.withValues(alpha: 0.8),
                                fontSize: 13,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              challenge.nativeText,
                              style: SeedlingTypography.heading2.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                              ),
                            ),
                            if (challenge.literalGloss != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Literal: ${challenge.literalGloss}",
                                  style: SeedlingTypography.body.copyWith(
                                    color: SeedlingColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          if (challenge.type == ChallengeType.listenSelect || 
                              challenge.type == ChallengeType.phoneticMatch ||
                              challenge.type == ChallengeType.scriptRead)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: widget.themeColor.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      challenge.type == ChallengeType.scriptRead ? Icons.auto_stories_rounded : Icons.volume_up_rounded, 
                                      color: widget.themeColor, size: 36
                                    ),
                                    onPressed: () {
                                      HapticService.lightImpact();
                                      VoiceSynthesisService.instance.speak(challenge.targetText);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        challenge.type == ChallengeType.phoneticMatch ? "Match the Sound" : 
                                        challenge.type == ChallengeType.scriptRead ? "Read the Character" : "Listen & Select",
                                        style: SeedlingTypography.heading2.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 56),

                    // Interaction Area
                    if (challenge.type == ChallengeType.construct || challenge.type == ChallengeType.syllableBuild) ...[
                      // Drop Zone
                      Container(
                        constraints: const BoxConstraints(minHeight: 80),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: SeedlingColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _selectedWords.isEmpty ? Colors.white.withValues(alpha: 0.1) : widget.themeColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _selectedWords.map((word) {
                            return GestureDetector(
                              onTap: () {
                                HapticService.lightImpact();
                                setState(() {
                                  _selectedWords.remove(word);
                                });
                              },
                              child: Chip(
                                label: Text(word, style: SeedlingTypography.bodyLarge.copyWith(fontWeight: FontWeight.w800)),
                                backgroundColor: SeedlingColors.cardBackground,
                                side: BorderSide(color: widget.themeColor.withValues(alpha: 0.2)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Word Bank
                      Wrap(
                        spacing: 16,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: challenge.wordBank.map((word) {
                          final isSelected = _selectedWords.contains(word);
                          return GestureDetector(
                            onTap: isSelected ? null : () {
                              HapticService.selectionClick();
                              setState(() {
                                _selectedWords.add(word);
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.transparent : SeedlingColors.cardBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
                                ),
                                boxShadow: isSelected ? [] : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    offset: const Offset(0, 6),
                                    blurRadius: 8,
                                  )
                                ],
                              ),
                              child: Text(
                                word,
                                style: SeedlingTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.transparent : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ] else if (challenge.type == ChallengeType.listenSelect) ...[
                      // Multiple Choice Options
                      ...challenge.options.map((option) {
                        final isSelected = _selectedOption == option;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: InkWell(
                            onTap: () {
                              HapticService.selectionClick();
                              setState(() => _selectedOption = option);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isSelected ? widget.themeColor.withValues(alpha: 0.15) : SeedlingColors.cardBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? widget.themeColor : Colors.white.withValues(alpha: 0.1),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                option,
                                style: SeedlingTypography.heading3.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? widget.themeColor : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ]
                  ],
                ),
              ),
            ),
            
            // Magic Tooltip Area (if checking and wrong)
            if (_isChecking && !_isSuccess && challenge.magicHint != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: SeedlingColors.sunlight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SeedlingColors.sunlight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: SeedlingColors.sunlight, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        challenge.magicHint!,
                        style: SeedlingTypography.body.copyWith(
                          color: SeedlingColors.sunlight,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: BoxDecoration(
                color: _isChecking 
                  ? (_isSuccess ? SeedlingColors.success.withValues(alpha: 0.1) : SeedlingColors.error.withValues(alpha: 0.1)) 
                  : SeedlingColors.background,
                border: Border(
                  top: BorderSide(
                    color: _isChecking ? (_isSuccess ? SeedlingColors.success : SeedlingColors.error) : Colors.white.withValues(alpha: 0.05),
                    width: 3,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isChecking 
                          ? (_isSuccess ? SeedlingColors.success : SeedlingColors.error)
                          : ((challenge.type == ChallengeType.construct ? _selectedWords.isNotEmpty : _selectedOption != null)
                              ? widget.themeColor
                              : SeedlingColors.cardBackground),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: _isChecking ? 0 : 8,
                    ),
                    onPressed: () {
                      if (_isChecking) {
                        if (_isSuccess) {
                          _nextChallenge();
                        } else {
                          // Try again
                          setState(() {
                            _isChecking = false;
                            _selectedWords.clear();
                          });
                        }
                      } else {
                        final canCheck = (challenge.type == ChallengeType.construct || challenge.type == ChallengeType.syllableBuild) 
                            ? _selectedWords.isNotEmpty 
                            : _selectedOption != null;

                        if (canCheck) {
                          _checkAnswer();
                        }
                      }
                    },
                    child: Text(
                      _isChecking ? (_isSuccess ? 'Continue' : 'Try Again') : 'Check',
                      style: SeedlingTypography.heading3.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroView() {
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: widget.themeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_alt_rounded, color: widget.themeColor, size: 64),
              ),
              const SizedBox(height: 32),
              Text(
                "Concept Strategy",
                style: SeedlingTypography.heading1.copyWith(
                  color: widget.themeColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.conceptExplanation ?? "",
                style: SeedlingTypography.bodyLarge.copyWith(
                  height: 1.6,
                  color: SeedlingColors.textPrimary.withValues(alpha: 0.9),
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  ),
                  onPressed: () {
                    HapticService.mediumImpact();
                    setState(() => _showIntro = false);
                    _playCurrentChallengeAudio();
                  },
                  child: Text(
                    "Got it!",
                    style: SeedlingTypography.heading3.copyWith(fontWeight: FontWeight.w900),
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
