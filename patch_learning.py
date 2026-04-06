"""
patch_learning.py - Applies SILE logic to learning.dart
"""
import re

PATH = "lib/screens/learning.dart"
content = open(PATH, encoding="utf-8").read()

# 1. State variable replacement
content = content.replace("Word? _newWordToPlant;", "List<Word> _pendingNewWords = [];")

# 2. _loadSession replacement
LOAD_SESSION_OLD = r"""    // ── Forgotten Curve Detection: load critically overdue words first ──────
    final forgottenWords = await db.getForgottenWords\(
      nativeLang,
      targetLang,
      limit: 3,
    \);

    final due = await db.getSRSDueWords\(
      nativeLang,
      targetLang,
      limit: 15,
      categoryId: null,
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
    \);

    // Merge forgotten words at the front \(they are highest priority\)
    final mergedDue = <Word>\[
      \.\.\.forgottenWords,
      \.\.\.due.where\(\(w\) => !forgottenWords.any\(\(f\) => f.id == w.id\)\),
    \];

    // Derive active sub-domain from the loaded words for contextual grouping
    _activeSubDomain = IntelligenceService.instance.getDominantSubDomain\(
      mergedDue,
    \);

    if \(!mounted\) return;

    setState\(\(\) \{
      _dueWords = mergedDue;
      _newWordToPlant = isBrandNew
          \? null
          : \(newWords.isNotEmpty \? newWords.first : null\);
      _initialPlantedWords = isBrandNew \? newWords : \[\];
      _isFirstSession = isBrandNew;
      _isLimitReached = limitReached; // New state variable needed

      if \(isBrandNew && _initialPlantedWords.isNotEmpty\) \{
        _phase = _SessionPhase.noWordsYet;
      \} else if \(mergedDue.isEmpty && _newWordToPlant == null\) \{"""

LOAD_SESSION_NEW = """    // ── Forgotten Curve Detection: load critically overdue words first ──────
    final forgottenWords = await db.getForgottenWords(
      nativeLang,
      targetLang,
      limit: 3,
    );

    final due = await db.getSRSDueWords(
      nativeLang,
      targetLang,
      limit: 15,
      categoryId: null,
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
    );

    // ── SILE: Cross-Subtheme Reviews ──────────────────────────────────────────
    final crossReviews = await db.getCrossSubthemeReviews(
      nativeLang,
      targetLang,
      limit: 5, // up to 5 interleaves
      excludedSubTheme: widget.subDomain ?? _activeSubDomain,
    );

    // Merge forgotten, theme due, and cross-subtheme (shuffle cross reviews)
    final mergedDue = <Word>[
      ...forgottenWords,
      ...due.where((w) => !forgottenWords.any((f) => f.id == w.id)),
      ...crossReviews,
    ];
    // We could shuffle mergedDue slightly, but QuizManager _AdaptiveQueue will shuffle anyway.

    // ── SILE: Fetch additional new word candidates for pending queue ──────────
    if (!isBrandNew && canPlant && newWords.isNotEmpty) {
      final moreCandidates = await db.getSmartNewWordCandidates(
        nativeLang,
        targetLang,
        limit: 2, 
        categoryId: widget.categoryId,
        domain: widget.domain,
        subDomain: widget.subDomain,
        activeSubDomain: _activeSubDomain,
        coverageGaps: _coverageGaps,
      );
      for (final mw in moreCandidates) {
        if (!newWords.any((w) => w.id == mw.id)) {
          newWords.add(mw);
        }
      }
    }

    // Derive active sub-domain from the loaded words for contextual grouping
    _activeSubDomain = IntelligenceService.instance.getDominantSubDomain(
      mergedDue,
    );

    if (!mounted) return;

    setState(() {
      _dueWords = mergedDue;
      _pendingNewWords = isBrandNew ? [] : newWords;
      _initialPlantedWords = isBrandNew ? newWords : [];
      _isFirstSession = isBrandNew;
      _isLimitReached = limitReached; // New state variable needed

      if (isBrandNew && _initialPlantedWords.isNotEmpty) {
        _phase = _SessionPhase.noWordsYet;
      } else if (mergedDue.isEmpty && _pendingNewWords.isEmpty) {"""

content = re.sub(LOAD_SESSION_OLD, LOAD_SESSION_NEW, content)


# 3. _handleQueueDepleted replacement
DEPLETED_OLD = r"""    // 1. Smart new word: biased by active sub-domain \+ coverage gaps
    Word\? nextNewWord;
    final canPlant = await UsageService\(\).canPlantWord\(\);

    if \(canPlant\) \{
      nextNewWord = await db.getSmartNewWord\(
        nativeLang,
        targetLang,
        categoryId: widget.categoryId,
        domain: widget.domain,
        subDomain: widget.subDomain,
        partOfSpeech: widget.partOfSpeech,
        microCategory: widget.microCategory,
        activeSubDomain: _activeSubDomain,
        coverageGaps: _coverageGaps,
      \);
    \} else \{
      _isLimitReached = true;
    \}

    // 2. More due reviews
    final moreDue = await db.getSRSDueWords\(
      nativeLang,
      targetLang,
      limit: 10,
      categoryId: null,
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
    \);

    if \(nextNewWord == null && moreDue.isEmpty\) \{
      _isReplenishing = false;
      if \(_isLimitReached\) \{
        _showPremiumForPlanting\(\);
      \} else \{
        _forceEndSession\(\);
      \}
      return;
    \}

    // Update contextual sub-domain for next replenishment
    if \(nextNewWord\?.subDomain != null\) \{
      _activeSubDomain = nextNewWord!.subDomain;
    \}

    if \(!mounted\) return;

    setState\(\(\) \{
      _isReplenishing = false;
      _quizKey.currentState\?.replenish\(moreDue, nextNewWord\);
    \}\);"""

DEPLETED_NEW = """    // 1. Smart new words (SILE: fetch multiple candidates)
    List<Word> nextNewWords = [];
    final canPlant = await UsageService().canPlantWord();

    if (canPlant) {
      nextNewWords = await db.getSmartNewWordCandidates(
        nativeLang,
        targetLang,
        limit: 2,
        categoryId: widget.categoryId,
        domain: widget.domain,
        subDomain: widget.subDomain,
        partOfSpeech: widget.partOfSpeech,
        microCategory: widget.microCategory,
        activeSubDomain: _activeSubDomain,
        coverageGaps: _coverageGaps,
      );
    } else {
      _isLimitReached = true;
    }

    // 2. More due reviews (theme + cross-subtheme)
    final moreDue = await db.getSRSDueWords(
      nativeLang,
      targetLang,
      limit: 10,
      categoryId: null,
      partOfSpeech: widget.partOfSpeech,
      microCategory: widget.microCategory,
    );
    final moreCrossReviews = await db.getCrossSubthemeReviews(
      nativeLang,
      targetLang,
      limit: 3,
      excludedSubTheme: widget.subDomain ?? _activeSubDomain,
    );
    final combinedDue = [...moreDue, ...moreCrossReviews];

    if (nextNewWords.isEmpty && combinedDue.isEmpty) {
      _isReplenishing = false;
      if (_isLimitReached) {
        _showPremiumForPlanting();
      } else {
        _forceEndSession();
      }
      return;
    }

    // Update contextual sub-domain for next replenishment
    if (nextNewWords.isNotEmpty && nextNewWords.first.subDomain != null) {
      _activeSubDomain = nextNewWords.first.subDomain;
    }

    if (!mounted) return;

    setState(() {
      _isReplenishing = false;
      _quizKey.currentState?.replenish(combinedDue, nextNewWords);
    });"""

content = re.sub(DEPLETED_OLD, DEPLETED_NEW, content)


# 4. _buildReviewPhase QuizManager update
QUIZ_MGR_OLD = r"""    return QuizManager\(
      key: _quizKey,
      dueWords: _dueWords,
      newWordToPlant: _newWordToPlant,
      isFirstSession: _isFirstSession,
      initialPlantedWords: _initialPlantedWords,
      onProgressUpdate: \(correct, total\) \{"""

QUIZ_MGR_NEW = """    return QuizManager(
      key: _quizKey,
      dueWords: _dueWords,
      pendingNewWords: _pendingNewWords,
      isFirstSession: _isFirstSession,
      initialPlantedWords: _initialPlantedWords,
      onProgressUpdate: (correct, total) {"""

content = re.sub(QUIZ_MGR_OLD, QUIZ_MGR_NEW, content)


open(PATH, "w", encoding="utf-8").write(content)
print("done patching learning.dart")
