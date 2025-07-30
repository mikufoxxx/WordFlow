import 'dart:math' as math;
import '../utils/algorithm_manager.dart';
import 'detailed_learning_record.dart';
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
      memoryLevel: MemoryLevel.first_time,
      learningCount: 0,
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
    // 计算新的记忆程度
    final newMemoryLevel = _calculateNewMemoryLevel(reviewResult);
    
    // 使用算法管理器计算复习间隔
    final newIntervalAndEase = _calculateIntervalUsingAlgorithm(reviewResult, reviewTime);
    
    // 创建复习记录，使用新计算的间隔
    final newReviewRecord = ReviewRecord(
      reviewTime: reviewTime,
      reviewResult: reviewResult,
      reviewInterval: newIntervalAndEase.interval,
    );
    
    return WordLearningRecord(
      word: word,
      translation: translation,
      wordBookName: newWordBookName ?? wordBookName,
      firstLearningTime: firstLearningTime,
      lastLearningTime: reviewTime,
      nextReviewTime: newIntervalAndEase.nextReviewTime,
      memoryLevel: newMemoryLevel,
      learningCount: learningCount + 1,
      correctCount: correctCount + (reviewResult.isCorrect ? 1 : 0),
      incorrectCount: incorrectCount + (reviewResult.isCorrect ? 0 : 1),
      reviewInterval: newIntervalAndEase.interval,
      easeFactor: newIntervalAndEase.easeFactor,
      reviewHistory: [...reviewHistory, newReviewRecord],
    );
  }

  /// 使用算法管理器计算复习间隔
  IntervalAndNextTime _calculateIntervalUsingAlgorithm(ReviewResult reviewResult, DateTime reviewTime) {
      // 导入算法管理器
      final algorithmManager = AlgorithmManager.instance;
      final algorithmService = algorithmManager.currentService;
      
      if (algorithmService != null) {
        // 创建增强学习记录用于算法计算
        final enhancedRecord = EnhancedWordLearningRecord(
          word: word,
          translation: translation,
          wordBookName: wordBookName,
          firstLearningTime: firstLearningTime,
          lastLearningTime: lastLearningTime,
          nextReviewTime: DateTime.now().add(Duration(days: reviewInterval.round())),
          memoryLevel: memoryLevel,
          learningCount: learningCount,
          correctCount: correctCount,
          incorrectCount: incorrectCount,
          reviewInterval: reviewInterval,
          easeFactor: easeFactor,
          reviewHistory: reviewHistory,
          sessions: [], // 暂时为空，因为这是旧的会话系统
          difficulty: _getWordDifficulty(),
        );
        
        // 创建学习会话
        final session = algorithmService.createLearningSession(
          mode: LearningMode.quickMemory, // 默认为快速记忆模式
          result: _mapReviewResultToLearningResult(reviewResult),
          score: _calculateScore(reviewResult),
          studyDuration: const Duration(seconds: 10), // 默认学习时长
        );
        
        // 使用算法计算下次复习时间
        final nextReviewTime = algorithmService.calculateNextReviewTime(enhancedRecord, session);
        
        // 计算新的间隔和难度系数
        final intervalInDays = nextReviewTime.difference(reviewTime).inHours / 24.0;

        // 根据学习结果调整难度系数
        double newEaseFactor = easeFactor;
        switch (reviewResult) {
          case ReviewResult.forgot:
            newEaseFactor = math.max(1.3, easeFactor - 0.2);
            break;
          case ReviewResult.hard:
            newEaseFactor = math.max(1.3, easeFactor - 0.15);
            break;
          case ReviewResult.good:
            // 保持不变
            break;
          case ReviewResult.easy:
            newEaseFactor = math.min(2.5, easeFactor + 0.15);
            break;
        }
        
        return IntervalAndNextTime(
          interval: intervalInDays,
          easeFactor: newEaseFactor,
          nextReviewTime: nextReviewTime,
        );
      }
    
    // 备用：使用原来的SuperMemo算法
    final fallbackResult = _calculateNewIntervalAndEase(reviewResult);
    return IntervalAndNextTime(
      interval: fallbackResult.interval,
      easeFactor: fallbackResult.easeFactor,
      nextReviewTime: reviewTime.add(Duration(days: fallbackResult.interval.round())),
    );
  }

  /// 获取单词难度（基于学习表现）
  WordDifficulty _getWordDifficulty() {
    if (learningCount == 0) return WordDifficulty.unknown;
    
    final errorRate = incorrectCount / learningCount;
    if (errorRate > 0.5) {
      return WordDifficulty.unknown;
    } else {
      return WordDifficulty.known;
    }
  }

  /// 将ReviewResult映射到LearningResult
  LearningResult _mapReviewResultToLearningResult(ReviewResult reviewResult) {
    switch (reviewResult) {
      case ReviewResult.forgot:
        return LearningResult.incorrect;
      case ReviewResult.hard:
        return LearningResult.correct;
      case ReviewResult.good:
        return LearningResult.known;
      case ReviewResult.easy:
        return LearningResult.excellent;
    }
  }

  /// 根据学习结果计算分数
  int _calculateScore(ReviewResult reviewResult) {
    switch (reviewResult) {
      case ReviewResult.forgot:
        return 2;
      case ReviewResult.hard:
        return 5;
      case ReviewResult.good:
        return 7;
      case ReviewResult.easy:
        return 9;
    }
  }

  /// 计算新的记忆程度
  MemoryLevel _calculateNewMemoryLevel(ReviewResult reviewResult) {
    switch (reviewResult) {
      case ReviewResult.forgot:
        return MemoryLevel.first_time;
      case ReviewResult.hard:
        return memoryLevel.index > 0 ? MemoryLevel.values[memoryLevel.index - 1] : MemoryLevel.first_time;
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

  /// 获取掌握程度百分比（简化版：基于连续正确次数）
  double get masteryPercentage {
    if (learningCount == 0) return 0.0;
    
    // 基于4分类统计计算掌握程度
    final total = forgotCount + hardCount + goodCount + easyCount;
    if (total == 0) return 0.0;
    
    // 权重计算：简单3分，良好2分，困难1分，忘记0分
    final weightedScore = (easyCount * 3 + goodCount * 2 + hardCount * 1 + forgotCount * 0) / (total * 3);
    
    // 记忆级别奖励
    final levelBonus = memoryLevel.index * 0.05; // 每个等级+5%
    
    // 最近连续正确奖励
    final recentCorrectStreak = _getRecentCorrectStreak();
    final streakBonus = recentCorrectStreak >= 3 ? 0.15 : 0.0;
    
    return (weightedScore * 0.7 + levelBonus + streakBonus).clamp(0.0, 1.0);
  }
  
  /// 获取最近的连续正确次数
  int _getRecentCorrectStreak() {
    if (reviewHistory.isEmpty) return 0;
    
    int streak = 0;
    // 从最新的记录开始往前查找连续正确的次数
    for (int i = reviewHistory.length - 1; i >= 0; i--) {
      if (reviewHistory[i].reviewResult.isCorrect) {
        streak++;
      } else {
        break; // 遇到错误就停止计算
      }
    }
    
    return streak;
  }

  /// 获取忘记次数
  int get forgotCount {
    final count = reviewHistory.where((r) => r.reviewResult == ReviewResult.forgot).length;
    // 如果没有reviewHistory但有旧统计数据，估算忘记次数
    if (reviewHistory.isEmpty && learningCount > 0) {
      return (incorrectCount * 0.6).round(); // 假设60%的错误是忘记
    }
    return count;
  }
  
  /// 获取困难次数
  int get hardCount {
    final count = reviewHistory.where((r) => r.reviewResult == ReviewResult.hard).length;
    // 如果没有reviewHistory但有旧统计数据，估算困难次数
    if (reviewHistory.isEmpty && learningCount > 0) {
      return (incorrectCount * 0.4).round(); // 假设40%的错误是困难
    }
    return count;
  }
  
  /// 获取良好次数
  int get goodCount {
    final count = reviewHistory.where((r) => r.reviewResult == ReviewResult.good).length;
    // 如果没有reviewHistory但有旧统计数据，估算良好次数
    if (reviewHistory.isEmpty && learningCount > 0) {
      return (correctCount * 0.8).round(); // 假设80%的正确是良好
    }
    return count;
  }
  
  /// 获取简单次数
  int get easyCount {
    final count = reviewHistory.where((r) => r.reviewResult == ReviewResult.easy).length;
    // 如果没有reviewHistory但有旧统计数据，估算简单次数
    if (reviewHistory.isEmpty && learningCount > 0) {
      return (correctCount * 0.2).round(); // 假设20%的正确是简单
    }
    return count;
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
  // ignore: constant_identifier_names
  first_time,    // 首次学习
  reviewing,     // 复习中
  strengthening, // 强化中
  stable,        // 稳定掌握
  mastered,      // 完全掌握
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

/// 间隔和下次复习时间结果
class IntervalAndNextTime {
  final double interval;
  final double easeFactor;
  final DateTime nextReviewTime;
  
  const IntervalAndNextTime({
    required this.interval,
    required this.easeFactor,
    required this.nextReviewTime,
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

/// 扩展 MemoryLevel 枚举
extension MemoryLevelExtension on MemoryLevel {
  /// 显示名称
  String get displayName {
    switch (this) {
      case MemoryLevel.first_time:
        return '首次学习';
      case MemoryLevel.reviewing:
        return '复习中';
      case MemoryLevel.strengthening:
        return '强化中';
      case MemoryLevel.stable:
        return '稳定掌握';
      case MemoryLevel.mastered:
        return '完全掌握';
    }
  }
  
  /// 显示颜色（初音莫奈配色）
  Color get color {
    switch (this) {
      case MemoryLevel.first_time:
        return const Color(0xFFA5D5C8); // 浅绿色
      case MemoryLevel.reviewing:
        return const Color(0xFF60B473); // 绿色调
      case MemoryLevel.strengthening:
        return const Color(0xFF60B488); // 绿青色调
      case MemoryLevel.stable:
        return const Color(0xFF60B49D); // 主要初音色
      case MemoryLevel.mastered:
        return const Color(0xFF60A1B4); // 蓝色调
    }
  }
  
  /// 获取下一个记忆级别
  MemoryLevel get nextLevel {
    switch (this) {
      case MemoryLevel.first_time:
        return MemoryLevel.reviewing;
      case MemoryLevel.reviewing:
        return MemoryLevel.strengthening;
      case MemoryLevel.strengthening:
        return MemoryLevel.stable;
      case MemoryLevel.stable:
        return MemoryLevel.mastered;
      case MemoryLevel.mastered:
        return MemoryLevel.mastered; // 已经是最高级别
    }
  }
}