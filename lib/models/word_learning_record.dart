import 'dart:math' as math;
import 'package:flutter/material.dart';
/// 单词学习记录模型
/// 存储单词的学习进度和记忆情况
class WordLearningRecord {
  final String word;                    // 单词
  final String translation;             // 翻译
  final String? wordBookName;           // 所属词书名称
  final DateTime firstLearningTime;     // 首次学习时间
  final DateTime lastLearningTime;      // 最后学习时间
  final DateTime nextReviewTime;        // 下次复习时间
  final MemoryLevel memoryLevel;        // 记忆程度
  final int learningCount;              // 学习次数
  final int correctCount;               // 正确次数
  final int incorrectCount;             // 错误次数
  final double reviewInterval;          // 复习间隔（天）
  final double easeFactor;              // 难度系数（SuperMemo算法）
  final List<ReviewRecord> reviewHistory; // 复习历史记录
  
  const WordLearningRecord({
    required this.word,
    required this.translation,
    this.wordBookName,
    required this.firstLearningTime,
    required this.lastLearningTime,
    required this.nextReviewTime,
    required this.memoryLevel,
    this.learningCount = 1,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.reviewInterval = 1.0,
    this.easeFactor = 2.5,
    this.reviewHistory = const [],
  });

  /// 从JSON创建WordLearningRecord对象
  factory WordLearningRecord.fromJson(Map<String, dynamic> json) {
    return WordLearningRecord(
      word: json['word'] ?? '',
      translation: json['translation'] ?? '',
      wordBookName: json['wordBookName'],
      firstLearningTime: DateTime.parse(json['firstLearningTime']),
      lastLearningTime: DateTime.parse(json['lastLearningTime']),
      nextReviewTime: DateTime.parse(json['nextReviewTime']),
      memoryLevel: MemoryLevel.values[json['memoryLevel'] ?? 0],
      learningCount: json['learningCount'] ?? 1,
      correctCount: json['correctCount'] ?? 0,
      incorrectCount: json['incorrectCount'] ?? 0,
      reviewInterval: (json['reviewInterval'] ?? 1.0).toDouble(),
      easeFactor: (json['easeFactor'] ?? 2.5).toDouble(),
      reviewHistory: (json['reviewHistory'] as List<dynamic>?)
          ?.map((item) => ReviewRecord.fromJson(item))
          .toList() ?? [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'translation': translation,
      'wordBookName': wordBookName,
      'firstLearningTime': firstLearningTime.toIso8601String(),
      'lastLearningTime': lastLearningTime.toIso8601String(),
      'nextReviewTime': nextReviewTime.toIso8601String(),
      'memoryLevel': memoryLevel.index,
      'learningCount': learningCount,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'reviewInterval': reviewInterval,
      'easeFactor': easeFactor,
      'reviewHistory': reviewHistory.map((record) => record.toJson()).toList(),
    };
  }

  /// 创建首次学习记录
  factory WordLearningRecord.firstTime({
    required String word,
    required String translation,
    String? wordBookName,
  }) {
    final now = DateTime.now();
    return WordLearningRecord(
      word: word,
      translation: translation,
      wordBookName: wordBookName,
      firstLearningTime: now,
      lastLearningTime: now,
      nextReviewTime: now.add(const Duration(days: 1)),
      memoryLevel: MemoryLevel.new_word,
      learningCount: 1,
      correctCount: 0,
      incorrectCount: 0,
      reviewInterval: 1.0,
      easeFactor: 2.5,
      reviewHistory: [],
    );
  }

  /// 更新学习记录
  WordLearningRecord updateLearning({
    required ReviewResult reviewResult,
    required DateTime reviewTime,
    String? newWordBookName,
  }) {
    final newReviewRecord = ReviewRecord(
      reviewTime: reviewTime,
      reviewResult: reviewResult,
      reviewInterval: reviewInterval,
    );

    // 计算新的记忆程度
    final newMemoryLevel = _calculateNewMemoryLevel(reviewResult);
    
    // 计算新的复习间隔和难度系数
    final newIntervalAndEase = _calculateNewIntervalAndEase(reviewResult);
    
    return WordLearningRecord(
      word: word,
      translation: translation,
      wordBookName: newWordBookName ?? wordBookName,
      firstLearningTime: firstLearningTime,
      lastLearningTime: reviewTime,
      nextReviewTime: reviewTime.add(Duration(days: newIntervalAndEase.interval.round())),
      memoryLevel: newMemoryLevel,
      learningCount: learningCount + 1,
      correctCount: correctCount + (reviewResult.isCorrect ? 1 : 0),
      incorrectCount: incorrectCount + (reviewResult.isCorrect ? 0 : 1),
      reviewInterval: newIntervalAndEase.interval,
      easeFactor: newIntervalAndEase.easeFactor,
      reviewHistory: [...reviewHistory, newReviewRecord],
    );
  }

  /// 计算新的记忆程度
  MemoryLevel _calculateNewMemoryLevel(ReviewResult reviewResult) {
    switch (reviewResult) {
      case ReviewResult.forgot:
        return MemoryLevel.new_word;
      case ReviewResult.hard:
        return memoryLevel.index > 0 ? MemoryLevel.values[memoryLevel.index - 1] : MemoryLevel.new_word;
      case ReviewResult.good:
        return memoryLevel.index < MemoryLevel.values.length - 1 
            ? MemoryLevel.values[memoryLevel.index + 1] 
            : MemoryLevel.mastered;
      case ReviewResult.easy:
        return memoryLevel.index < MemoryLevel.values.length - 2
            ? MemoryLevel.values[memoryLevel.index + 2]
            : MemoryLevel.mastered;
    }
  }

  /// 计算新的复习间隔和难度系数（基于SuperMemo算法）
  IntervalAndEase _calculateNewIntervalAndEase(ReviewResult reviewResult) {
    double newInterval = reviewInterval;
    double newEaseFactor = easeFactor;

    switch (reviewResult) {
      case ReviewResult.forgot:
        newInterval = 1.0;
        newEaseFactor = math.max(1.3, easeFactor - 0.2);
        break;
      case ReviewResult.hard:
        newInterval = reviewInterval * 1.2;
        newEaseFactor = math.max(1.3, easeFactor - 0.15);
        break;
      case ReviewResult.good:
        newInterval = reviewInterval * easeFactor;
        break;
      case ReviewResult.easy:
        newInterval = reviewInterval * easeFactor * 1.3;
        newEaseFactor = easeFactor + 0.15;
        break;
    }

    return IntervalAndEase(interval: newInterval, easeFactor: newEaseFactor);
  }

  /// 获取掌握程度百分比
  double get masteryPercentage {
    if (learningCount == 0) return 0.0;
    
    final correctRate = correctCount / learningCount;
    final levelBonus = memoryLevel.index / (MemoryLevel.values.length - 1);
    
    return (correctRate * 0.7 + levelBonus * 0.3).clamp(0.0, 1.0);
  }

  /// 是否需要复习
  bool get needsReview => DateTime.now().isAfter(nextReviewTime);

  /// 获取学习天数
  int get learningDays => DateTime.now().difference(firstLearningTime).inDays + 1;

  @override
  String toString() => 'WordLearningRecord(word: $word, level: $memoryLevel)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordLearningRecord && other.word == word;
  }
  
  @override
  int get hashCode => word.hashCode;
}

/// 记忆程度枚举
enum MemoryLevel {
  new_word,    // 新单词
  learning,    // 学习中
  familiar,    // 熟悉
  known,       // 认识
  mastered,    // 掌握
}

/// 复习结果枚举
enum ReviewResult {
  forgot,  // 忘记了
  hard,    // 困难
  good,    // 良好
  easy,    // 简单
}

/// 复习记录
class ReviewRecord {
  final DateTime reviewTime;
  final ReviewResult reviewResult;
  final double reviewInterval;
  
  const ReviewRecord({
    required this.reviewTime,
    required this.reviewResult,
    required this.reviewInterval,
  });

  factory ReviewRecord.fromJson(Map<String, dynamic> json) {
    return ReviewRecord(
      reviewTime: DateTime.parse(json['reviewTime']),
      reviewResult: ReviewResult.values[json['reviewResult']],
      reviewInterval: (json['reviewInterval'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewTime': reviewTime.toIso8601String(),
      'reviewResult': reviewResult.index,
      'reviewInterval': reviewInterval,
    };
  }
}

/// 间隔和难度系数结果
class IntervalAndEase {
  final double interval;
  final double easeFactor;
  
  const IntervalAndEase({
    required this.interval,
    required this.easeFactor,
  });
}

/// 扩展方法
extension ReviewResultExtension on ReviewResult {
  bool get isCorrect => this == ReviewResult.good || this == ReviewResult.easy;
  
  String get displayName {
    switch (this) {
      case ReviewResult.forgot:
        return '忘记了';
      case ReviewResult.hard:
        return '困难';
      case ReviewResult.good:
        return '良好';
      case ReviewResult.easy:
        return '简单';
    }
  }
}

extension MemoryLevelExtension on MemoryLevel {
  String get displayName {
    switch (this) {
      case MemoryLevel.new_word:
        return '新单词';
      case MemoryLevel.learning:
        return '学习中';
      case MemoryLevel.familiar:
        return '熟悉';
      case MemoryLevel.known:
        return '认识';
      case MemoryLevel.mastered:
        return '掌握';
    }
  }
  
  Color get color {
    switch (this) {
      case MemoryLevel.new_word:
        return const Color(0xFFE57373);
      case MemoryLevel.learning:
        return const Color(0xFFFFB74D);
      case MemoryLevel.familiar:
        return const Color(0xFFFFF176);
      case MemoryLevel.known:
        return const Color(0xFF81C784);
      case MemoryLevel.mastered:
        return const Color(0xFF64B5F6);
    }
  }
}