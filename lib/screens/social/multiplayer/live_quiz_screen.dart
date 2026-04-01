import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../models/multiplayer.dart';
import '../../../models/word.dart';
import '../../../providers/multiplayer_provider.dart';
import '../../../core/page_route.dart';
import 'live_reaction_bar.dart';
import 'live_chat_overlay.dart';
import 'floating_reaction_overlay.dart';
import 'live_exit_dialog.dart';
import 'quiz_results_screen.dart';
import '../../../services/auth_service.dart';
import '../../../services/vocabulary_service.dart';
import '../../../providers/app_providers.dart';
import '../../../core/supabase_config.dart';

class LiveQuizScreen extends ConsumerStatefulWidget {
  final LiveGameSession session;

  const LiveQuizScreen({super.key, required this.session});

  @override
  ConsumerState<LiveQuizScreen> createState() => _LiveQuizScreenState();
}

class _LiveQuizScreenState extends ConsumerState<LiveQuizScreen> {
  final GlobalKey<FloatingReactionOverlayState> _reactionKey = GlobalKey();
  
  Word? _currentWord;
  bool _isLoadingContent = false;
  Timer? _syncTimer;
  int _secondsRemaining = 15;
  bool _revealed = false;
  int _selectedOption = -1;

  final Map<String, AnswerStatus> _playerStatuses = {};

  @override
  void initState() {
    super.initState();
    _startSyncTimer();
    _loadCurrentQuestion();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final session = ref.read(activeSessionProvider);
      if (session == null || session.currentQuestionStartAt == null) return;

      final now = DateTime.now().toUtc();
      final diff = now.difference(session.currentQuestionStartAt!).inSeconds;
      final remaining = (session.timePerQuestion - diff).clamp(0, session.timePerQuestion);

      if (remaining != _secondsRemaining) {
        setState(() => _secondsRemaining = remaining);
        if (remaining == 0) {
          _onTimeOut();
        }
      }
    });
  }

  Future<void> _loadCurrentQuestion() async {
    final session = ref.read(activeSessionProvider);
    if (session == null || session.questionIds.isEmpty) return;
    
    // Listen for reactions
    final notifier = ref.read(activeSessionProvider.notifier);
    notifier.onReactionReceived = (emoji) {
      _reactionKey.currentState?.spawnEmoji(emoji);
    };

    setState(() => _isLoadingContent = true);
    
    try {
      final qId = session.questionIds[session.currentQuestionIndex % session.questionIds.length];
      final targetLang = session.targetLanguageCode;
      final nativeLang = session.languageCode;
      
      final word = await VocabularyService.fetchOnlineWord(qId, targetLang, nativeLang);
      
      if (mounted) {
        setState(() {
          _currentWord = word;
          _isLoadingContent = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading question: $e');
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }

  void _onTimeOut() {
    // Reveal correct answer if not answered
  }

  void _onOptionSelected(int index) {
    if (_selectedOption != -1 || _revealed || _currentWord == null) return;
    
    final isCorrect = index == _currentWord!.correctIndex;

    setState(() {
      _selectedOption = index;
    });

    ref.read(activeSessionProvider.notifier).submitAnswer(
      widget.session.currentQuestionIndex,
      index,
      isCorrect,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider) ?? widget.session;
    
    final myPlayer = session.participants.where((p) => p.id == AuthService().userId).firstOrNull;
    _revealed = myPlayer?.lastAnswerStatus != AnswerStatus.idle;
    
    final amIPlaying = myPlayer?.role == PlayerRole.player || myPlayer?.role == PlayerRole.host;
    final isHost = myPlayer?.role == PlayerRole.host;

    final article = _currentWord?.article ?? '';
    final question = _currentWord?.question ?? 'Loading...';
    final pronunciation = _currentWord?.pronunciation ?? '';
    final gender = _currentWord?.gender;
    final pos = _currentWord?.pos ?? '';

    Color genderColor = SeedlingColors.deepRoot;
    if (gender == 'Masculine') genderColor = Colors.blue.shade300;
    if (gender == 'Feminine') genderColor = Colors.pink.shade300;
    if (gender == 'Neuter') genderColor = Colors.green.shade300;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await LiveExitDialog.show(context, ref, session, isHost);
        if (shouldExit && context.mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context, ref, session, isHost),
                  _buildLiveLeaderboard(session),
                  
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, 
                            color: _secondsRemaining < 5 ? Colors.red : SeedlingColors.deepRoot),
                        const SizedBox(width: 8),
                        Text('$_secondsRemaining', 
                            style: SeedlingTypography.heading3.copyWith(
                              color: _secondsRemaining < 5 ? Colors.red : SeedlingColors.deepRoot,
                            )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: gender != null ? Border.all(color: genderColor.withOpacity(0.5), width: 3) : null,
                      boxShadow: [
                        BoxShadow(
                          color: (gender != null ? genderColor : SeedlingColors.seedlingGreen).withOpacity(0.15), 
                          blurRadius: 30, 
                          offset: const Offset(0, 10)
                        )
                      ]
                    ),
                    child: Column(
                      children: [
                        if (pos.isNotEmpty || gender != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildBadge(pos, SeedlingColors.textSecondary),
                              if (gender != null) ...[
                                const SizedBox(width: 8),
                                _buildBadge(gender.toUpperCase(), genderColor),
                              ],
                            ],
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (article.isNotEmpty)
                              Text('$article ', style: SeedlingTypography.heading2.copyWith(color: SeedlingColors.textSecondary, fontSize: 24)),
                            Text(
                              question,
                              style: SeedlingTypography.heading1.copyWith(
                                fontSize: 38, 
                                color: SeedlingColors.deepRoot,
                              ),
                            ),
                          ],
                        ),
                        if (pronunciation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            pronunciation,
                            style: SeedlingTypography.body.copyWith(
                              color: SeedlingColors.textSecondary.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Expanded(
                    child: amIPlaying ? _buildParticipantOptions() : _buildSpectatorView(),
                  ),
                ],
              ),
            ),
            
            FloatingReactionOverlay(key: _reactionKey, sessionId: widget.session.id),
            
            const Positioned(bottom: 100, left: 20, child: LiveReactionBar()),
            const LiveChatOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: SeedlingTypography.caption.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref, LiveGameSession session, bool isHost) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 28),
            onPressed: () async {
              final shouldExit = await LiveExitDialog.show(context, ref, session, isHost);
              if (shouldExit && context.mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                SeedlingPageRoute(page: QuizResultsScreen(session: session)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SeedlingColors.sunlight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Skip (Mock)', style: SeedlingTypography.body.copyWith(color: SeedlingColors.deepRoot)),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantOptions() {
    if (_currentWord == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
        ),
        itemBuilder: (context, index) => _buildOptionCard(index, _currentWord!.options[index]),
      ),
    );
  }

  Widget _buildSpectatorView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
           Text(
             _revealed ? 'CORRECT ANSWER' : 'SPECTATING LIVE',
             style: SeedlingTypography.caption.copyWith(
               color: _revealed ? SeedlingColors.seedlingGreen : SeedlingColors.sunlight, 
               letterSpacing: 2,
               fontWeight: FontWeight.bold,
             ),
           ),
           const SizedBox(height: 15),
           if (_revealed && _currentWord != null) 
              Text(_currentWord!.options[_currentWord!.correctIndex], style: SeedlingTypography.heading2)
           else ...[
              const CircularProgressIndicator(color: SeedlingColors.sunlight),
              const SizedBox(height: 15),
              Text('Waiting for players to answer...', style: SeedlingTypography.body),
           ]
        ],
      ),
    );
  }

  Widget _buildLiveLeaderboard(LiveGameSession session) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: SeedlingColors.background,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: session.activePlayers.length,
        itemBuilder: (context, index) {
          final player = session.activePlayers[index];
          final status = player.lastAnswerStatus;
          
          Color ringColor = Colors.transparent;
          Widget icon = Text(player.avatarEmoji, style: const TextStyle(fontSize: 24));
          
          if (status == AnswerStatus.answered) {
            ringColor = SeedlingColors.sunlight;
            icon = const Icon(Icons.check, color: SeedlingColors.sunlight, size: 20);
          } else if (status == AnswerStatus.correct) {
            ringColor = SeedlingColors.seedlingGreen;
          } else if (status == AnswerStatus.incorrect) {
            ringColor = SeedlingColors.warning;
          }

          return Container(
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 3),
                    color: SeedlingColors.cardBackground,
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),
                const SizedBox(height: 4),
                Text(
                  player.score.toString(),
                  style: SeedlingTypography.caption.copyWith(fontWeight: FontWeight.bold, color: SeedlingColors.textPrimary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionCard(int index, String text) {
    final correctIndex = _currentWord?.correctIndex ?? -1;
    bool isSelected = _selectedOption == index;
    bool isCorrect = _revealed && index == correctIndex;
    bool isWrongSelection = _revealed && isSelected && index != correctIndex;

    Color bgColor = SeedlingColors.cardBackground;
    Color borderColor = Colors.transparent;
    Color textColor = SeedlingColors.textPrimary;

    if (_revealed) {
      if (isCorrect) {
        bgColor = SeedlingColors.seedlingGreen;
        textColor = Colors.white;
      } else if (isWrongSelection) {
        bgColor = SeedlingColors.warning;
        textColor = Colors.white;
      } else {
        bgColor = SeedlingColors.cardBackground.withOpacity(0.5); // Fade out wrong non-selected
        textColor = SeedlingColors.textSecondary.withOpacity(0.5);
      }
    } else if (isSelected) {
      bgColor = SeedlingColors.sunlight.withOpacity(0.2);
      borderColor = SeedlingColors.sunlight;
    }

    return GestureDetector(
      onTap: () => _onOptionSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: SeedlingTypography.heading3.copyWith(color: textColor),
        ),
      ),
    );
  }
}
