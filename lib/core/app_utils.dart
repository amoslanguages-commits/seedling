// Utility helpers used globally across the Seedling app.

/// Returns a time-aware, streak-aware greeting for the home screen.
/// e.g. "Good morning! 🌱" or "Nice streak — 5 days 🔥 Keep growing!"
String buildGreeting({required int streak, required bool practicedToday}) {
  final hour = DateTime.now().hour;

  final timeGreeting = hour < 12
      ? 'Good morning'
      : hour < 17
      ? 'Good afternoon'
      : 'Good evening';

  if (streak >= 7) {
    return '$timeGreeting — $streak days strong 🔥';
  } else if (streak >= 3) {
    return '$timeGreeting! On a $streak-day streak 🌿';
  } else if (practicedToday) {
    return "$timeGreeting! You've practiced today ✅";
  } else if (streak == 0) {
    return '$timeGreeting! Start your streak 🌱';
  } else {
    return '$timeGreeting! 🌿';
  }
}

/// Returns an encouraging subtitle for the home screen mascot area.
String buildSubtitle({
  required int totalLearned,
  required bool practicedToday,
}) {
  if (!practicedToday) {
    return 'Your seedlings need water today!';
  }
  if (totalLearned >= 100) {
    return 'Impressive garden — $totalLearned words planted!';
  } else if (totalLearned >= 50) {
    return '$totalLearned words growing in your garden 🌱';
  }
  return 'Ready to grow your vocabulary?';
}

/// Returns a relative time string from a DateTime.
/// e.g. "Just now", "2 mins ago", "Yesterday", "3 days ago"
String relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60)
    return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 6)
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';

  final today = DateTime(now.year, now.month, now.day);
  final dtDay = DateTime(dt.year, dt.month, dt.day);
  final dayDiff = today.difference(dtDay).inDays;

  if (dayDiff == 0) return 'Today';
  if (dayDiff == 1) return 'Yesterday';
  if (dayDiff < 7) return '$dayDiff days ago';
  return '${(dayDiff / 7).floor()} week${(dayDiff / 7).floor() == 1 ? '' : 's'} ago';
}
