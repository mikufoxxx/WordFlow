import '../models/word_learning_record.dart';

/// A compact, local-only snapshot of a learner's daily activity.
///
/// `todayStudiedWords` counts unique words so reviewing the same word several
/// times does not inflate a user's daily goal or streak.
class DailyLearningSummary {
  const DailyLearningSummary({
    required this.todayStudiedWords,
    required this.dailyGoal,
    required this.currentStreak,
    required this.didStudyToday,
  });

  final int todayStudiedWords;
  final int dailyGoal;
  final int currentStreak;
  final bool didStudyToday;

  bool get isGoalComplete => todayStudiedWords >= dailyGoal;

  int get remainingWords => isGoalComplete
      ? 0
      : (dailyGoal - todayStudiedWords).clamp(0, dailyGoal).toInt();

  double get goalProgress =>
      (todayStudiedWords / dailyGoal).clamp(0.0, 1.0).toDouble();
}

/// Calculates daily activity from the review history already stored on device.
///
/// The streak is anchored to today after a learner studies. Before their first
/// review of the day, it preserves yesterday's unbroken streak so the home
/// screen can encourage them to keep it going instead of prematurely showing 0.
class DailyLearningSummaryCalculator {
  const DailyLearningSummaryCalculator._();

  static DailyLearningSummary calculate(
    Iterable<WordLearningRecord> records, {
    required int dailyGoal,
    DateTime? now,
  }) {
    final currentTime = (now ?? DateTime.now()).toLocal();
    final today = _startOfDay(currentTime);
    final activeDays = <DateTime>{};
    final studiedWordsToday = <String>{};

    for (final record in records) {
      final reviewTimes = record.reviewHistory.isEmpty
          ? <DateTime>[record.lastLearningTime]
          : record.reviewHistory
                .map((review) => review.reviewTime)
                .toList(growable: false);

      for (final reviewTime in reviewTimes) {
        final reviewDay = _startOfDay(reviewTime.toLocal());
        activeDays.add(reviewDay);

        if (reviewDay == today) {
          studiedWordsToday.add(record.word);
        }
      }
    }

    final didStudyToday = activeDays.contains(today);
    final normalizedGoal = dailyGoal < 1 ? 1 : dailyGoal;

    return DailyLearningSummary(
      todayStudiedWords: studiedWordsToday.length,
      dailyGoal: normalizedGoal,
      currentStreak: _calculateCurrentStreak(
        activeDays: activeDays,
        today: today,
        didStudyToday: didStudyToday,
      ),
      didStudyToday: didStudyToday,
    );
  }

  static int _calculateCurrentStreak({
    required Set<DateTime> activeDays,
    required DateTime today,
    required bool didStudyToday,
  }) {
    var cursor = didStudyToday ? today : _previousDay(today);
    var streak = 0;

    while (activeDays.contains(cursor)) {
      streak++;
      cursor = _previousDay(cursor);
    }

    return streak;
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _previousDay(DateTime value) =>
      DateTime(value.year, value.month, value.day - 1);
}
