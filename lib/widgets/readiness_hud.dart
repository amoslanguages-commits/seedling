import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/typography.dart';

// ═══════════════════════════════════════════════════════════════════════════
// READINESS HUD & NEW WORD UNLOCK BANNER
//
// Garden Pulse HUD: a live mini-dashboard shown during quiz sessions.
// Displays: readiness bar, streak, accuracy ring, words mastered today.
//
// NewWordUnlockBanner: a brief animated banner shown when CLS ≥ 70 and a
// new word is about to be introduced. Auto-dismisses after 1.4 seconds.
// ═══════════════════════════════════════════════════════════════════════════

class ReadinessHUD extends StatelessWidget {
  /// The current Cognitive Load Score (0–100). Controls readiness bar fill.
  final double clsScore;

  /// Current consecutive correct-answer streak.
  final int streak;

  /// Session accuracy (0–1).
  final double accuracy;

  /// Number of words mastered (reached Step 3) in this session.
  final int wordsMastered;

  const ReadinessHUD({
    super.key,
    required this.clsScore,
    required this.streak,
    required this.accuracy,
    required this.wordsMastered,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = (clsScore / 100).clamp(0.0, 1.0);
    final isReady = clsScore >= 70;
    final isFire = streak >= 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReady
              ? SeedlingColors.seedlingGreen.withValues(alpha: 0.45)
              : SeedlingColors.morningDew.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isReady ? SeedlingColors.seedlingGreen : Colors.black)
                .withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Readiness bar + label
          _ReadinessBar(readiness: readiness, isReady: isReady),
          const SizedBox(width: 12),

          // Streak pill (hidden when streak = 0)
          if (streak > 0) ...[
            _StreakPill(streak: streak, isFire: isFire),
            const SizedBox(width: 12),
          ],

          // Accuracy ring
          _AccuracyRing(accuracy: accuracy),

          // Mastered leaves
          if (wordsMastered > 0) ...[
            const SizedBox(width: 10),
            _MasteredLeaves(count: wordsMastered),
          ],
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _ReadinessBar extends StatelessWidget {
  final double readiness;
  final bool isReady;

  const _ReadinessBar({required this.readiness, required this.isReady});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isReady ? '🌱 Ready!' : '🌱 Growing',
          style: SeedlingTypography.caption.copyWith(
            fontSize: 10,
            color: isReady
                ? SeedlingColors.seedlingGreen
                : SeedlingColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 58,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: readiness),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: SeedlingColors.morningDew.withValues(
                  alpha: 0.2,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isReady
                      ? SeedlingColors.seedlingGreen
                      : SeedlingColors.sunlight,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;
  final bool isFire;

  const _StreakPill({required this.streak, required this.isFire});

  @override
  Widget build(BuildContext context) {
    final textColor = isFire
        ? SeedlingColors.hibiscusRed
        : SeedlingColors.sunlight;
    final bgColor = textColor.withValues(alpha: 0.12);
    final borderColor = textColor.withValues(alpha: 0.35);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isFire ? '🔥' : '✨', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: SeedlingTypography.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccuracyRing extends StatelessWidget {
  final double accuracy;

  const _AccuracyRing({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final pct = (accuracy * 100).round();
    final color = accuracy >= 0.80
        ? SeedlingColors.success
        : accuracy >= 0.60
        ? SeedlingColors.sunlight
        : SeedlingColors.error;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: accuracy),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.5),
          color: color.withValues(alpha: 0.10),
        ),
        alignment: Alignment.center,
        child: Text(
          '$pct%',
          style: SeedlingTypography.caption.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _MasteredLeaves extends StatelessWidget {
  final int count;

  const _MasteredLeaves({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count.clamp(0, 5),
        (i) => AnimatedOpacity(
          opacity: 1.0,
          duration: Duration(milliseconds: 300 + i * 80),
          child: const Padding(
            padding: EdgeInsets.only(right: 2),
            child: Text('🍃', style: TextStyle(fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

// ─── New Word Unlock Banner ───────────────────────────────────────────────────
// A brief celebratory banner shown just before a new word is introduced.
// slides in from top, holds for ~1s, then slides out automatically.

class NewWordUnlockBanner extends StatefulWidget {
  final VoidCallback? onDismissed;

  const NewWordUnlockBanner({super.key, this.onDismissed});

  @override
  State<NewWordUnlockBanner> createState() => _NewWordUnlockBannerState();
}

class _NewWordUnlockBannerState extends State<NewWordUnlockBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(
      begin: -24,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    // Auto-dismiss after 1.4 s
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        _ctrl.reverse().then((_) {
          if (mounted) widget.onDismissed?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _slide.value), child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SeedlingColors.seedlingGreen, SeedlingColors.morningDew],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌱', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'New Word Unlocked!',
                style: SeedlingTypography.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Streak Milestone Overlay ─────────────────────────────────────────────────
// A brief celebration shown at streak milestones (3, 5, 10).

class StreakMilestoneOverlay extends StatefulWidget {
  final int streak;
  final VoidCallback? onDismissed;

  const StreakMilestoneOverlay({
    super.key,
    required this.streak,
    this.onDismissed,
  });

  @override
  State<StreakMilestoneOverlay> createState() => _StreakMilestoneOverlayState();
}

class _StreakMilestoneOverlayState extends State<StreakMilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  String get _message {
    if (widget.streak >= 10) return '⚡ Unstoppable!';
    if (widget.streak >= 5) return '🔥 On Fire!';
    return '🌿 Growing...';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _ctrl.reverse().then((_) {
          if (mounted) widget.onDismissed?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: SeedlingColors.seedlingGreen.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
                blurRadius: 24,
              ),
            ],
          ),
          child: Text(
            '${widget.streak} Streak  $_message',
            style: SeedlingTypography.heading3.copyWith(
              color: SeedlingColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
