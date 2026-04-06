"""
fix_sile.py  –  Applies the remaining SILE (Smart Interleaved Learning Engine)
patches to lib/widgets/quizzes.dart
"""

import re

PATH = "lib/widgets/quizzes.dart"
content = open(PATH, encoding="utf-8").read()

# ── 1. Replace the old _maybeInjectNewWord entirely ──────────────────────────
OLD_INJECT = r"""  // ── Readiness check \(called after each answer\) ────────────────────

  void _maybeInjectNewWord\(\) \{
    if \(_newWordInjected \|\| _currentNewWordToPlant == null\) return;

    // ── UVLS: CLS-based gate with 3-turn minimum gap ──────────────────────
    final cls = _queue\.readinessScore\(_currentNewWordToPlant!\);
    const hasNewWordInProgress = false; // checked before this call
    final shouldIntroduce = SessionConductor\.instance\.shouldIntroduceNewWord\(
      cls: cls,
      turnsSinceLastNewWord: _queue\._turnsSinceNewWord,
      hasNewWordInProgress: hasNewWordInProgress,
    \);

    debugPrint\(
      '\[QuizManager\] CLS=\$cls turns=\$\{_queue\._turnsSinceNewWord\} introduce=\$shouldIntroduce',
    \);

    if \(shouldIntroduce\) \{
      _newWordInjected = true;
      _queue\.onNewWordInjected\(\); // reset turn counter

      // Show the unlock banner if not shown yet for this word
      if \(!_hasShownUnlockBanner\) \{
        setState\(() => _showUnlockBanner = true\);
        _hasShownUnlockBanner = true;
        
        // ── UVLS: Delay planting screen so banner can animate ──────────
        Future\.delayed\(const Duration\(milliseconds: 1500\), \(\) \{
          if \(mounted\) setState\(() => _showPlanting = true\);
        \}\);
      \} else \{
        // If already shown \(e\.g\. re-injection\), show planting directly
        setState\(() => _showPlanting = true\);
      \}
    \}
  \}"""

NEW_INJECT = """  // ── SILE: Readiness check ────────────────────────────────────────────────

  void _maybeInjectNewWord() {
    // Nothing to do if no pending words or one is already being drilled
    if (_queue.pendingNewWords.isEmpty || _queue.newWordInProgress) return;

    // ── CLS gate: 3-turn minimum + score >= 70 ───────────────────────────
    final candidateWord = _queue.pendingNewWords.first;
    final cls = _queue.readinessScore(candidateWord);
    final shouldIntroduce = SessionConductor.instance.shouldIntroduceNewWord(
      cls: cls,
      turnsSinceLastNewWord: _queue._turnsSinceNewWord,
      hasNewWordInProgress: _queue.newWordInProgress,
    );

    debugPrint(
      '[QuizManager] CLS=$cls turns=${_queue._turnsSinceNewWord} introduce=$shouldIntroduce',
    );

    if (shouldIntroduce) {
      final wordToPlant = _queue.popPendingNewWord();
      if (wordToPlant == null) return;

      _queue.onNewWordInjected();
      _plantingWord = wordToPlant;

      setState(() => _showUnlockBanner = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showUnlockBanner = false;
            _showPlanting = true;
          });
        }
      });
    }
  }"""

result, n = re.subn(OLD_INJECT, NEW_INJECT, content, flags=re.DOTALL)
print(f"_maybeInjectNewWord replacements: {n}")

# ── 2. Fix _showPlanting references in build/render that use _currentNewWordToPlant ─
# The planting screen uses _currentNewWordToPlant or _wiltedWordToReplant.
# Now we use _plantingWord for the candidate, _wiltedWordToReplant stays.

result = result.replace(
    "_currentNewWordToPlant ?? _wiltedWordToReplant",
    "_plantingWord ?? _wiltedWordToReplant",
)
result = result.replace(
    "_currentNewWordToPlant!",
    "_plantingWord!",
)
result = result.replace(
    "_currentNewWordToPlant",
    "_plantingWord",
)
print("Replaced _currentNewWordToPlant references")

# ── 3. Fix _hasShownUnlockBanner -> _hasShownUnlockBannerForCurrent ──────────
result = result.replace(
    "_hasShownUnlockBanner = false; // ready to show again for next new word",
    "_hasShownUnlockBannerForCurrent = false;",
)
result = result.replace(
    "if (!_hasShownUnlockBanner)",
    "if (!_hasShownUnlockBannerForCurrent)",
)
result = result.replace(
    "_hasShownUnlockBanner = true;",
    "_hasShownUnlockBannerForCurrent = true;",
)
result = result.replace(
    "bool _hasShownUnlockBanner = false; // only show once per new word",
    "bool _hasShownUnlockBannerForCurrent = false;",
)
print("Replaced _hasShownUnlockBanner references")

# ── 4. Fix _newWordPlanted reference leftover in _onPlantingComplete ─────────
result = result.replace("      _newWordPlanted = true;\n", "")
print("Removed stray _newWordPlanted assignment")

# ── 5. Fix any stray _newWordInjected references in the build method ─────────
# These are only in _checkDone but that's already been replaced -- let's find
# any remaining ones and replace them with the correct SILE equivalents.
if "_newWordInjected" in result:
    print("WARNING: _newWordInjected still present -- fixing...")
    result = result.replace(
        "if (!_newWordInjected &&\n        _currentNewWordToPlant != null &&",
        "if (_queue.pendingNewWords.isNotEmpty &&",
    )
    # fallback: just flag any remaining
    count = result.count("_newWordInjected")
    print(f"  Remaining _newWordInjected references: {count}")

open(PATH, "w", encoding="utf-8").write(result)
print("Done! File written.")
