import 'package:flutter_test/flutter_test.dart';
import 'package:wordflow/models/word_learning_record.dart';
import 'package:wordflow/utils/daily_learning_summary.dart';

WordLearningRecord _record(
  String word, {
  required List<DateTime> reviewTimes,
  DateTime? lastLearningTime,
}) {
  final lastReviewTime =
      lastLearningTime ??
      (reviewTimes.isEmpty ? DateTime(2026, 8, 1) : reviewTimes.last);

  return WordLearningRecord(
    word: word,
    translation: '$word translation',
    wordBookName: 'test-book',
    firstLearningTime: reviewTimes.isEmpty ? lastReviewTime : reviewTimes.first,
    lastLearningTime: lastReviewTime,
    nextReviewTime: lastReviewTime.add(const Duration(days: 1)),
    memoryLevel: MemoryLevel.reviewing,
    learningCount: reviewTimes.length,
    correctCount: reviewTimes.length,
    reviewHistory: reviewTimes
        .map(
          (reviewTime) => ReviewRecord(
            reviewTime: reviewTime,
            reviewResult: ReviewResult.good,
            reviewInterval: 1,
          ),
        )
        .toList(growable: false),
  );
}

void main() {
  group('DailyLearningSummaryCalculator', () {
    final now = DateTime(2026, 8, 14, 12);

    test('counts unique words, completes a goal, and builds a streak', () {
      final summary = DailyLearningSummaryCalculator.calculate(
        [
          _record(
            'adapt',
            reviewTimes: [now, now.add(const Duration(hours: 2))],
          ),
          _record('build', reviewTimes: [now]),
          _record('create', reviewTimes: [DateTime(2026, 8, 13, 10)]),
          _record('deliver', reviewTimes: [DateTime(2026, 8, 12, 10)]),
        ],
        dailyGoal: 2,
        now: now,
      );

      expect(summary.todayStudiedWords, 2);
      expect(summary.currentStreak, 3);
      expect(summary.didStudyToday, isTrue);
      expect(summary.isGoalComplete, isTrue);
      expect(summary.remainingWords, 0);
      expect(summary.goalProgress, 1);
    });

    test('keeps yesterday’s streak visible before today’s first review', () {
      final summary = DailyLearningSummaryCalculator.calculate(
        [
          _record('focus', reviewTimes: [DateTime(2026, 8, 13, 9)]),
          _record('grow', reviewTimes: [DateTime(2026, 8, 12, 9)]),
        ],
        dailyGoal: 10,
        now: now,
      );

      expect(summary.todayStudiedWords, 0);
      expect(summary.currentStreak, 2);
      expect(summary.didStudyToday, isFalse);
      expect(summary.goalProgress, 0);
    });

    test('does not bridge an inactive day', () {
      final summary = DailyLearningSummaryCalculator.calculate(
        [
          _record('habit', reviewTimes: [now]),
          _record('iterate', reviewTimes: [DateTime(2026, 8, 12, 9)]),
        ],
        dailyGoal: 3,
        now: now,
      );

      expect(summary.currentStreak, 1);
      expect(summary.remainingWords, 2);
    });

    test(
      'uses last learning time for legacy records without review history',
      () {
        final summary = DailyLearningSummaryCalculator.calculate(
          [_record('legacy', reviewTimes: const [], lastLearningTime: now)],
          dailyGoal: 0,
          now: now,
        );

        expect(summary.dailyGoal, 1);
        expect(summary.todayStudiedWords, 1);
        expect(summary.currentStreak, 1);
        expect(summary.isGoalComplete, isTrue);
      },
    );
  });
}
