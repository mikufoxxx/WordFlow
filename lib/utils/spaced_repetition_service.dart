import 'dart:math' as math;
import '../models/word_learning_record.dart';

/// 间隔重复算法服务
/// 基于艾宾浩斯遗忘曲线和SuperMemo算法实现科学的单词复习推送
/// 采用无限流设计，动态调整推送策略
class SpacedRepetitionService {
  /// 默认算法参数
  static const double _defaultInitialInterval = 1.0;
  static const double _defaultEaseFactor = 2.5;
  static const double _minEaseFactor = 1.3;
  static const double _maxEaseFactor = 5.0;

  /// 学习参数配置
  final SpacedRepetitionConfig config;

  SpacedRepetitionService({
    SpacedRepetitionConfig? config,
  }) : config = config ?? SpacedRepetitionConfig.defaultConfig();

  /// 计算下一次复习时间
  DateTime calculateNextReviewTime(WordLearningRecord record, ReviewResult result) {
    final now = DateTime.now();
    final newIntervalAndEase = _calculateNewIntervalAndEase(record, result);
    
    // 添加一些随机性以避免所有复习集中在同一时间
    final randomOffset = _getRandomOffset(newIntervalAndEase.interval);
    final intervalInHours = (newIntervalAndEase.interval * 24 + randomOffset).round();
    
    return now.add(Duration(hours: intervalInHours));
  }

  /// 获取需要复习的单词列表（无限流模式）
  List<WordLearningRecord> getReviewWords(List<WordLearningRecord> allRecords) {
    final now = DateTime.now();
    
    // 筛选需要复习的单词（所有到期的单词）
    final reviewWords = allRecords.where((record) {
      return record.nextReviewTime.isBefore(now) || record.nextReviewTime.isAtSameMomentAs(now);
    }).toList();

    // 按优先级排序
    reviewWords.sort((a, b) => _getReviewPriority(a, b));

    return reviewWords;
  }

  /// 获取学习进度概览（无限流模式）
  LearningProgress getStudyProgress(List<WordLearningRecord> allRecords) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 今天学习的单词数量
    final todayStudied = allRecords.where((record) {
      final lastLearningDate = DateTime(
        record.lastLearningTime.year,
        record.lastLearningTime.month,
        record.lastLearningTime.day,
      );
      return lastLearningDate.isAtSameMomentAs(today);
    }).length;
    
    // 需要复习的单词数量
    final dueWords = getReviewWords(allRecords).length;
    
    // 计算学习强度（基于最近7天的学习情况）
    final weekAgo = now.subtract(const Duration(days: 7));
    final recentStudied = allRecords.where((record) {
      return record.lastLearningTime.isAfter(weekAgo);
    }).length;
    
    final averageDailyStudy = recentStudied / 7.0;
    
    return LearningProgress(
      averageNewWordsPerDay: averageDailyStudy,
      daysToMaster: 0, // 无限流模式不预测完成时间
      estimatedMasteryDate: now,
      currentMasteryRate: _calculateOverallMastery(allRecords),
      todayStudied: todayStudied,
      dueWords: dueWords,
      recentIntensity: averageDailyStudy,
    );
  }

  /// 生成学习统计报告
  LearningStats generateLearningStats(List<WordLearningRecord> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 今天的复习数据
    final todayReviews = records.where((record) {
      return record.reviewHistory.any((review) {
        final reviewDate = DateTime(
          review.reviewTime.year,
          review.reviewTime.month,
          review.reviewTime.day,
        );
        return reviewDate.isAtSameMomentAs(today);
      });
    }).length;

    // 需要复习的单词数
    final dueWords = getReviewWords(records).length;

    // 各个记忆程度的统计
    final levelStats = <MemoryLevel, int>{};
    for (final level in MemoryLevel.values) {
      levelStats[level] = records.where((r) => r.memoryLevel == level).length;
    }

    // 学习天数
    final learningDays = records.isNotEmpty
        ? records.map((r) => r.learningDays).reduce(math.max)
        : 0;

    // 总体掌握程度
    final overallMastery = records.isNotEmpty
        ? records.map((r) => r.masteryPercentage).reduce((a, b) => a + b) / records.length
        : 0.0;

    return LearningStats(
      totalWords: records.length,
      todayReviews: todayReviews,
      dueWords: dueWords,
      levelStats: levelStats,
      learningDays: learningDays,
      overallMastery: overallMastery,
    );
  }

  /// 计算新的间隔和难度系数
  IntervalAndEase _calculateNewIntervalAndEase(WordLearningRecord record, ReviewResult result) {
    double newInterval = record.reviewInterval;
    double newEaseFactor = record.easeFactor;

    switch (result) {
      case ReviewResult.forgot:
        // 忘记了，重置间隔
        newInterval = config.forgotIntervalMultiplier;
        newEaseFactor = math.max(_minEaseFactor, newEaseFactor - 0.2);
        break;
      case ReviewResult.hard:
        // 困难，稍微增加间隔
        newInterval = record.reviewInterval * config.hardIntervalMultiplier;
        newEaseFactor = math.max(_minEaseFactor, newEaseFactor - 0.15);
        break;
      case ReviewResult.good:
        // 良好，按难度系数增加间隔
        newInterval = record.reviewInterval * newEaseFactor;
        break;
      case ReviewResult.easy:
        // 简单，更大幅度增加间隔
        newInterval = record.reviewInterval * newEaseFactor * config.easyIntervalMultiplier;
        newEaseFactor = math.min(_maxEaseFactor, newEaseFactor + 0.15);
        break;
    }

    // 应用最小和最大间隔限制
    newInterval = newInterval.clamp(config.minInterval, config.maxInterval);

    return IntervalAndEase(interval: newInterval, easeFactor: newEaseFactor);
  }

  /// 获取随机偏移量以分散复习时间
  double _getRandomOffset(double interval) {
    // 为较长的间隔添加更多随机性
    final maxOffset = math.min(interval * 0.1, 2.0);
    return (math.Random().nextDouble() - 0.5) * maxOffset;
  }

  /// 计算复习优先级
  int _getReviewPriority(WordLearningRecord a, WordLearningRecord b) {
    // 优先级因素：
    // 1. 延迟天数（越延迟优先级越高）
    // 2. 记忆程度（越低优先级越高）
    // 3. 学习次数（越少优先级越高）
    
    final now = DateTime.now();
    final aDelayDays = now.difference(a.nextReviewTime).inDays;
    final bDelayDays = now.difference(b.nextReviewTime).inDays;
    
    // 首先按延迟天数排序
    if (aDelayDays != bDelayDays) {
      return bDelayDays.compareTo(aDelayDays);
    }
    
    // 其次按记忆程度排序
    if (a.memoryLevel != b.memoryLevel) {
      return a.memoryLevel.index.compareTo(b.memoryLevel.index);
    }
    
    // 最后按学习次数排序
    return a.learningCount.compareTo(b.learningCount);
  }

  /// 计算总体掌握度
  double _calculateOverallMastery(List<WordLearningRecord> records) {
    if (records.isEmpty) return 0.0;
    
    final totalMastery = records.map((r) => r.masteryPercentage).reduce((a, b) => a + b);
    return totalMastery / records.length;
  }

  /// 获取智能推荐的下一批学习单词
  /// 基于用户的学习节奏和记忆曲线动态推荐
  List<String> getRecommendedWords(List<WordLearningRecord> learnedWords, List<String> availableWords, {int maxCount = 10}) {
    final reviewWords = getReviewWords(learnedWords);
    final progress = getStudyProgress(learnedWords);
    
    // 如果有需要复习的单词，优先推荐复习
    if (reviewWords.isNotEmpty) {
      return reviewWords.take(maxCount).map((r) => r.word).toList();
    }
    
    // 如果没有复习单词，基于学习强度推荐新单词
    final recommendCount = _calculateRecommendedNewWords(progress);
    final unlearnedWords = availableWords.where((word) {
      return !learnedWords.any((learned) => learned.word == word);
    }).toList();
    
    return unlearnedWords.take(math.min(recommendCount, maxCount)).toList();
  }
  
  /// 基于学习节奏计算推荐的新单词数量
  int _calculateRecommendedNewWords(LearningProgress progress) {
    // 基于最近的学习强度动态调整
    if (progress.recentIntensity > 20) return 15; // 高强度学习者
    if (progress.recentIntensity > 10) return 10; // 中等强度学习者
    if (progress.recentIntensity > 5) return 8;   // 轻度学习者
    return 5; // 初学者或低强度学习者
  }
}

/// 间隔重复算法配置
class SpacedRepetitionConfig {
  final double minInterval;              // 最小间隔（天）
  final double maxInterval;              // 最大间隔（天）
  final double forgotIntervalMultiplier; // 忘记时的间隔倍数
  final double hardIntervalMultiplier;   // 困难时的间隔倍数
  final double easyIntervalMultiplier;   // 简单时的间隔倍数
  final double difficultyAdjustment;     // 难度调整系数（0.5-1.5）

  const SpacedRepetitionConfig({
    this.minInterval = 1.0,
    this.maxInterval = 365.0,
    this.forgotIntervalMultiplier = 1.0,
    this.hardIntervalMultiplier = 1.2,
    this.easyIntervalMultiplier = 1.3,
    this.difficultyAdjustment = 1.0, // 默认难度调整系数
  });

  factory SpacedRepetitionConfig.defaultConfig() {
    return const SpacedRepetitionConfig();
  }

  factory SpacedRepetitionConfig.conservative() {
    return const SpacedRepetitionConfig(
      easyIntervalMultiplier: 1.2,
      difficultyAdjustment: 0.8,
    );
  }

  factory SpacedRepetitionConfig.aggressive() {
    return const SpacedRepetitionConfig(
      easyIntervalMultiplier: 1.5,
      difficultyAdjustment: 1.2,
    );
  }

  SpacedRepetitionConfig copyWith({
    double? minInterval,
    double? maxInterval,
    double? forgotIntervalMultiplier,
    double? hardIntervalMultiplier,
    double? easyIntervalMultiplier,
    double? difficultyAdjustment,
  }) {
    return SpacedRepetitionConfig(
      minInterval: minInterval ?? this.minInterval,
      maxInterval: maxInterval ?? this.maxInterval,
      forgotIntervalMultiplier: forgotIntervalMultiplier ?? this.forgotIntervalMultiplier,
      hardIntervalMultiplier: hardIntervalMultiplier ?? this.hardIntervalMultiplier,
      easyIntervalMultiplier: easyIntervalMultiplier ?? this.easyIntervalMultiplier,
      difficultyAdjustment: difficultyAdjustment ?? this.difficultyAdjustment, // 难度调整系数
    );
  }
}

/// 学习统计
class LearningStats {
  final int totalWords;
  final int todayReviews;
  final int dueWords;
  final Map<MemoryLevel, int> levelStats;
  final int learningDays;
  final double overallMastery;

  const LearningStats({
    required this.totalWords,
    required this.todayReviews,
    required this.dueWords,
    required this.levelStats,
    required this.learningDays,
    required this.overallMastery,
  });
}

/// 学习进度预测
class LearningProgress {
  final double averageNewWordsPerDay;
  final int daysToMaster;
  final DateTime estimatedMasteryDate;
  final double currentMasteryRate;
  final int todayStudied;      // 今天学习的单词数
  final int dueWords;          // 待复习的单词数
  final double recentIntensity; // 最近的学习强度

  const LearningProgress({
    required this.averageNewWordsPerDay,
    required this.daysToMaster,
    required this.estimatedMasteryDate,
    required this.currentMasteryRate,
    this.todayStudied = 0,
    this.dueWords = 0,
    this.recentIntensity = 0.0,
  });
} 