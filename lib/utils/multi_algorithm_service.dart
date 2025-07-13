import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import '../models/word_learning_record.dart';
import '../models/detailed_learning_record.dart';
import '../models/algorithm_config.dart';
import 'deepseek_api_service.dart';

/// 多算法服务
/// 支持SuperMemo、Anki和智能自适应三种算法
class MultiAlgorithmService {
  static const _uuid = Uuid();
  
  final AlgorithmConfig config;
  late final BaseAlgorithmImplementation _implementation;

  MultiAlgorithmService({
    required this.config,
  }) {
    _implementation = _createImplementation(config);
  }

  /// 创建具体算法实现
  BaseAlgorithmImplementation _createImplementation(AlgorithmConfig config) {
    switch (config.type) {
      case AlgorithmType.superMemo:
        return SuperMemoImplementation(config as SuperMemoConfig);
      case AlgorithmType.anki:
        return AnkiImplementation(config as AnkiConfig);
      case AlgorithmType.adaptive:
        return AdaptiveImplementation(config as AdaptiveConfig);
    }
  }

  /// 计算下一次复习时间
  DateTime calculateNextReviewTime(EnhancedWordLearningRecord record, DetailedLearningSession session) {
    return _implementation.calculateNextReviewTime(record, session);
  }

  /// 获取需要复习的单词
  List<EnhancedWordLearningRecord> getReviewWords(List<EnhancedWordLearningRecord> allRecords) {
    return _implementation.getReviewWords(allRecords);
  }

  /// 创建学习会话
  DetailedLearningSession createLearningSession({
    required LearningMode mode,
    required LearningResult result,
    required int score,
    String? userInput,
    SentenceAnalysis? sentenceAnalysis,
    required Duration studyDuration,
    List<String> mistakes = const [],
    String? feedback,
  }) {
    return DetailedLearningSession(
      sessionId: _uuid.v4(),
      sessionTime: DateTime.now(),
      learningMode: mode,
      result: result,
      score: score,
      userInput: userInput,
      sentenceAnalysis: sentenceAnalysis,
      studyDuration: studyDuration,
      mistakes: mistakes,
      feedback: feedback,
    );
  }

  /// 分析造句质量
  Future<SentenceAnalysis> analyzeSentence({
    required String word,
    required String sentence,
    required String translation,
  }) async {
    return _implementation.analyzeSentence(
      word: word,
      sentence: sentence,
      translation: translation,
    );
  }

  /// 更新配置
  void updateConfig(AlgorithmConfig newConfig) {
    if (newConfig.type != config.type) {
      throw ArgumentError('不能更改算法类型');
    }
    _implementation.updateConfig(newConfig);
  }

  /// 获取学习统计
  Map<String, dynamic> getStatistics(List<EnhancedWordLearningRecord> records) {
    return _implementation.getStatistics(records);
  }
}

/// 基础算法实现接口
abstract class BaseAlgorithmImplementation {
  AlgorithmConfig config;

  BaseAlgorithmImplementation(this.config);

  /// 计算下一次复习时间
  DateTime calculateNextReviewTime(EnhancedWordLearningRecord record, DetailedLearningSession session);

  /// 获取需要复习的单词
  List<EnhancedWordLearningRecord> getReviewWords(List<EnhancedWordLearningRecord> allRecords);

  /// 分析造句质量
  Future<SentenceAnalysis> analyzeSentence({
    required String word,
    required String sentence,
    required String translation,
  });

  /// 更新配置
  void updateConfig(AlgorithmConfig newConfig);

  /// 获取学习统计
  Map<String, dynamic> getStatistics(List<EnhancedWordLearningRecord> records);
}

/// SuperMemo算法实现
class SuperMemoImplementation extends BaseAlgorithmImplementation {
  SuperMemoImplementation(SuperMemoConfig config) : super(config);

  SuperMemoConfig get smConfig => config as SuperMemoConfig;

  @override
  DateTime calculateNextReviewTime(EnhancedWordLearningRecord record, DetailedLearningSession session) {
    final now = DateTime.now();
    final newInterval = _calculateNewInterval(record, session);
    
    // 添加随机波动
    final randomOffset = _getRandomOffset(newInterval);
    final intervalInHours = ((newInterval + randomOffset) * 24).round();
    
    return now.add(Duration(hours: intervalInHours));
  }

  double _calculateNewInterval(EnhancedWordLearningRecord record, DetailedLearningSession session) {
    double newInterval = record.reviewInterval;
    double newEaseFactor = record.easeFactor;

    // 根据学习结果调整间隔
    switch (session.result) {
      case LearningResult.unknown:
      case LearningResult.incorrect:
        // 忘记或错误：重置间隔
        newInterval = smConfig.initialInterval * smConfig.forgotPenalty;
        newEaseFactor = math.max(smConfig.minEaseFactor, newEaseFactor - smConfig.easeFactorChange);
        break;
      case LearningResult.correct:
        // 正确但困难：小幅增加间隔
        newInterval = record.reviewInterval * smConfig.hardAdjustment;
        newEaseFactor = math.max(smConfig.minEaseFactor, newEaseFactor - smConfig.easeFactorChange * 0.5);
        break;
      case LearningResult.known:
        // 良好：按难度系数增加间隔
        newInterval = record.reviewInterval * newEaseFactor;
        break;
      case LearningResult.excellent:
        // 优秀：大幅增加间隔
        newInterval = record.reviewInterval * newEaseFactor * smConfig.easyBonus;
        newEaseFactor = math.min(smConfig.maxEaseFactor, newEaseFactor + smConfig.easeFactorChange);
        break;
      case LearningResult.skipped:
        // 跳过：保持原间隔
        break;
    }

    // 应用全局难度调整
    newInterval *= smConfig.difficultyModifier;

    // 应用间隔限制
    return newInterval.clamp(smConfig.minInterval, smConfig.maxInterval);
  }

  double _getRandomOffset(double interval) {
    if (smConfig.randomFuzz == 0) return 0;
    
    final maxOffset = interval * smConfig.randomFuzz;
    return (math.Random().nextDouble() - 0.5) * maxOffset;
  }

  @override
  List<EnhancedWordLearningRecord> getReviewWords(List<EnhancedWordLearningRecord> allRecords) {
    final now = DateTime.now();
    
    final reviewWords = allRecords.where((record) {
      return record.nextReviewTime.isBefore(now) || record.nextReviewTime.isAtSameMomentAs(now);
    }).toList();

    // 按优先级排序
    reviewWords.sort((a, b) => _getReviewPriority(a, b));

    return reviewWords;
  }

  int _getReviewPriority(EnhancedWordLearningRecord a, EnhancedWordLearningRecord b) {
    final now = DateTime.now();
    
    // 1. 延迟时间（越延迟优先级越高）
    final aDelay = now.difference(a.nextReviewTime).inHours;
    final bDelay = now.difference(b.nextReviewTime).inHours;
    
    if (aDelay != bDelay) {
      return bDelay.compareTo(aDelay);
    }
    
    // 2. 记忆程度（越低优先级越高）
    if (a.memoryLevel != b.memoryLevel) {
      return a.memoryLevel.index.compareTo(b.memoryLevel.index);
    }
    
    // 3. 难度等级（越难优先级越高）
    return b.difficulty.index.compareTo(a.difficulty.index);
  }

  @override
  Future<SentenceAnalysis> analyzeSentence({
    required String word,
    required String sentence,
    required String translation,
  }) async {
    // 使用DeepSeek API分析句子
    final result = await DeepSeekApiService.judgeSentence(
      word: word,
      sentence: sentence,
      translation: translation,
    );

    // 转换为SentenceAnalysis
    return SentenceAnalysis(
      isCorrect: result?.isCorrect ?? false,
      grammarScore: _calculateGrammarScore(result),
      usageScore: _calculateUsageScore(result),
      complexityScore: _calculateComplexityScore(sentence),
      grammarErrors: _parseGrammarErrors(result),
      usageErrors: _parseUsageErrors(result),
      betterSentence: result?.betterSentences?.isNotEmpty == true ? result!.betterSentences.first : null,
      improvements: result?.suggestions ?? [],
      complexity: _determineComplexity(sentence),
    );
  }

  int _calculateGrammarScore(dynamic result) {
    if (result?.isCorrect == true) {
      return (result?.score ?? 0) > 0 ? math.max(7, (result?.score ?? 0).toInt()) : 8;
    }
    return math.max(3, (result?.score ?? 0).toInt());
  }

  int _calculateUsageScore(dynamic result) {
    // 基于错误类型和建议质量计算用法分数
    if (result?.isCorrect == true) {
      return (result?.score ?? 0) > 0 ? math.max(7, (result?.score ?? 0).toInt()) : 8;
    }
    return math.max(4, (result?.score ?? 0).toInt());
  }

  int _calculateComplexityScore(String sentence) {
    // 基于句子长度、词汇复杂度等计算复杂度分数
    final wordCount = sentence.split(' ').length;
    if (wordCount < 5) return 3;
    if (wordCount < 10) return 5;
    if (wordCount < 15) return 7;
    return 9;
  }

  List<GrammarError> _parseGrammarErrors(dynamic result) {
    // 解析语法错误
    final errors = <GrammarError>[];
    if (result?.errors != null) {
      for (int i = 0; i < result!.errors.length; i++) {
        final error = result.errors[i];
        errors.add(GrammarError(
          type: error?.type ?? 'grammar',
          description: error?.description ?? '',
          suggestion: error?.suggestion ?? '',
          position: i,
        ));
      }
    }
    return errors;
  }

  List<UsageError> _parseUsageErrors(dynamic result) {
    // 解析用法错误
    final errors = <UsageError>[];
    if (result?.suggestions?.isNotEmpty == true) {
      for (final suggestion in result!.suggestions) {
        errors.add(UsageError(
          type: 'usage',
          description: suggestion ?? '',
          correctUsage: result.betterSentences?.isNotEmpty == true ? result.betterSentences!.first : '',
          example: result.betterSentences?.isNotEmpty == true ? result.betterSentences!.first : '',
        ));
      }
    }
    return errors;
  }

  SentenceComplexity _determineComplexity(String sentence) {
    final wordCount = sentence.split(' ').length;
    if (wordCount < 5) return SentenceComplexity.simple;
    if (wordCount < 10) return SentenceComplexity.medium;
    if (wordCount < 15) return SentenceComplexity.complex;
    return SentenceComplexity.advanced;
  }

  @override
  void updateConfig(AlgorithmConfig newConfig) {
    config = newConfig;
  }

  @override
  Map<String, dynamic> getStatistics(List<EnhancedWordLearningRecord> records) {
    final stats = <String, dynamic>{};
    
    // 基础统计
    stats['totalWords'] = records.length;
    stats['reviewWords'] = getReviewWords(records).length;
    
    // 记忆程度分布
    final levelDistribution = <String, int>{};
    for (final level in MemoryLevel.values) {
      levelDistribution[level.displayName] = records.where((r) => r.memoryLevel == level).length;
    }
    stats['memoryLevelDistribution'] = levelDistribution;
    
    // 平均掌握程度
    if (records.isNotEmpty) {
      final avgMastery = records.map((r) => r.masteryPercentage).reduce((a, b) => a + b) / records.length;
      stats['averageMastery'] = avgMastery;
    }
    
    return stats;
  }
}

/// Anki算法实现
class AnkiImplementation extends BaseAlgorithmImplementation {
  AnkiImplementation(AnkiConfig config) : super(config);

  AnkiConfig get ankiConfig => config as AnkiConfig;

  @override
  DateTime calculateNextReviewTime(EnhancedWordLearningRecord record, DetailedLearningSession session) {
    final now = DateTime.now();
    final newInterval = _calculateNewInterval(record, session);
    
    // 添加模糊化
    final fuzzedInterval = _applyFuzz(newInterval);
    final intervalInHours = (fuzzedInterval * 24).round();
    
    return now.add(Duration(hours: intervalInHours));
  }

  double _calculateNewInterval(EnhancedWordLearningRecord record, DetailedLearningSession session) {
    double newInterval;

    // 根据学习结果调整间隔
    switch (session.result) {
      case LearningResult.unknown:
      case LearningResult.incorrect:
        // 进入重新学习阶段
        newInterval = ankiConfig.relearningSteps.first / (24 * 60); // 转换为天
        break;
      case LearningResult.correct:
        // 困难：间隔 × 1.2
        newInterval = record.reviewInterval * 1.2;
        break;
      case LearningResult.known:
        // 良好：间隔 × 间隔修正
        newInterval = record.reviewInterval * record.easeFactor * ankiConfig.intervalModifier;
        break;
      case LearningResult.excellent:
        // 简单：间隔 × 间隔修正 × 简单奖励
        newInterval = record.reviewInterval * record.easeFactor * ankiConfig.intervalModifier * ankiConfig.easyBonus;
        break;
      case LearningResult.skipped:
        // 跳过：保持原间隔
        newInterval = record.reviewInterval;
        break;
    }

    // 应用间隔限制
    return newInterval.clamp(ankiConfig.minInterval.toDouble(), ankiConfig.maxInterval.toDouble());
  }

  double _applyFuzz(double interval) {
    if (ankiConfig.fuzzFactor == 0) return interval;
    
    final fuzzRange = interval * ankiConfig.fuzzFactor;
    final fuzzOffset = (math.Random().nextDouble() - 0.5) * fuzzRange;
    
    return interval + fuzzOffset;
  }

  @override
  List<EnhancedWordLearningRecord> getReviewWords(List<EnhancedWordLearningRecord> allRecords) {
    final now = DateTime.now();
    
    final reviewWords = allRecords.where((record) {
      return record.nextReviewTime.isBefore(now) || record.nextReviewTime.isAtSameMomentAs(now);
    }).toList();

    // 按优先级排序
    reviewWords.sort((a, b) => _getReviewPriority(a, b));

    return reviewWords;
  }

  int _getReviewPriority(EnhancedWordLearningRecord a, EnhancedWordLearningRecord b) {
    // 根据优先级模式排序
    switch (ankiConfig.priorityMode) {
      case 'difficulty':
        return b.difficulty.index.compareTo(a.difficulty.index);
      case 'delay':
        final now = DateTime.now();
        final aDelay = now.difference(a.nextReviewTime).inHours;
        final bDelay = now.difference(b.nextReviewTime).inHours;
        return bDelay.compareTo(aDelay);
      case 'random':
        return math.Random().nextBool() ? 1 : -1;
      default:
        return 0;
    }
  }

  @override
  Future<SentenceAnalysis> analyzeSentence({
    required String word,
    required String sentence,
    required String translation,
  }) async {
    // 使用与SuperMemo相同的分析逻辑
    final superMemoImpl = SuperMemoImplementation(SuperMemoConfig.balanced());
    return superMemoImpl.analyzeSentence(
      word: word,
      sentence: sentence,
      translation: translation,
    );
  }

  @override
  void updateConfig(AlgorithmConfig newConfig) {
    config = newConfig;
  }

  @override
  Map<String, dynamic> getStatistics(List<EnhancedWordLearningRecord> records) {
    final stats = <String, dynamic>{};
    
    // 基础统计
    stats['totalWords'] = records.length;
    stats['reviewWords'] = getReviewWords(records).length;
    
    // 水蛭卡片统计
    final leechCards = records.where((r) => r.incorrectCount >= ankiConfig.leechThreshold).length;
    stats['leechCards'] = leechCards;
    
    // 学习阶段分布
    final learningCards = records.where((r) => r.memoryLevel == MemoryLevel.reviewing).length;
    final graduatedCards = records.where((r) => r.memoryLevel.index >= MemoryLevel.stable.index).length;
    
    stats['learningCards'] = learningCards;
    stats['graduatedCards'] = graduatedCards;
    
    return stats;
  }
}

/// 智能自适应算法实现
class AdaptiveImplementation extends BaseAlgorithmImplementation {
  AdaptiveImplementation(AdaptiveConfig config) : super(config);

  AdaptiveConfig get adaptiveConfig => config as AdaptiveConfig;

  @override
  DateTime calculateNextReviewTime(EnhancedWordLearningRecord record, DetailedLearningSession session) {
    final now = DateTime.now();
    final baseInterval = _calculateBaseInterval(record, session);
    final adaptedInterval = _applyAdaptiveAdjustments(record, baseInterval);
    
    final intervalInHours = (adaptedInterval * 24).round();
    return now.add(Duration(hours: intervalInHours));
  }

  double _calculateBaseInterval(EnhancedWordLearningRecord record, DetailedLearningSession session) {
    // 基础间隔计算（类似SuperMemo）
    double baseInterval = record.reviewInterval;
    
    switch (session.result) {
      case LearningResult.unknown:
      case LearningResult.incorrect:
        baseInterval = 1.0;
        break;
      case LearningResult.correct:
        baseInterval = record.reviewInterval * 1.2;
        break;
      case LearningResult.known:
        baseInterval = record.reviewInterval * record.easeFactor;
        break;
      case LearningResult.excellent:
        baseInterval = record.reviewInterval * record.easeFactor * 1.3;
        break;
      case LearningResult.skipped:
        break;
    }
    
    return baseInterval;
  }

  double _applyAdaptiveAdjustments(EnhancedWordLearningRecord record, double baseInterval) {
    double adjustedInterval = baseInterval;
    
    // 根据单词难度调整
    switch (record.difficulty) {
      case WordDifficulty.known:
        adjustedInterval *= adaptiveConfig.easyWordMultiplier;
        break;
      case WordDifficulty.unknown:
        adjustedInterval *= adaptiveConfig.hardWordMultiplier;
        break;
    }
    
    // 根据学习能力调整
    adjustedInterval *= adaptiveConfig.learningAbility;
    
    // 根据记忆保持能力调整
    adjustedInterval *= adaptiveConfig.memoryRetention;
    
    // 应用个性化因子
    for (final factor in adaptiveConfig.personalFactors.entries) {
      adjustedInterval *= factor.value;
    }
    
    return adjustedInterval.clamp(0.1, 365.0);
  }

  @override
  List<EnhancedWordLearningRecord> getReviewWords(List<EnhancedWordLearningRecord> allRecords) {
    final now = DateTime.now();
    
    final reviewWords = allRecords.where((record) {
      return record.nextReviewTime.isBefore(now) || record.nextReviewTime.isAtSameMomentAs(now);
    }).toList();

    // 智能排序
    reviewWords.sort((a, b) => _getAdaptivePriority(a, b));

    return reviewWords;
  }

  int _getAdaptivePriority(EnhancedWordLearningRecord a, EnhancedWordLearningRecord b) {
    // 综合考虑多个因素
    final aScore = _calculatePriorityScore(a);
    final bScore = _calculatePriorityScore(b);
    
    return bScore.compareTo(aScore);
  }

  double _calculatePriorityScore(EnhancedWordLearningRecord record) {
    double score = 0.0;
    
    // 延迟权重
    final delay = DateTime.now().difference(record.nextReviewTime).inHours;
    score += delay * 0.3;
    
    // 难度权重
    score += record.difficulty.index * 0.2;
    
    // 记忆程度权重（越低越优先）
    score += (MemoryLevel.values.length - record.memoryLevel.index) * 0.2;
    
    // 错误率权重
    if (record.learningCount > 0) {
      final errorRate = record.incorrectCount / record.learningCount;
      score += errorRate * 0.3;
    }
    
    return score;
  }

  @override
  Future<SentenceAnalysis> analyzeSentence({
    required String word,
    required String sentence,
    required String translation,
  }) async {
    // 优先使用AI分析
    if (adaptiveConfig.enableAIOptimization) {
      return _aiAnalyzeSentence(word, sentence, translation);
    }
    
    // 否则使用传统分析
    final superMemoImpl = SuperMemoImplementation(SuperMemoConfig.balanced());
    return superMemoImpl.analyzeSentence(
      word: word,
      sentence: sentence,
      translation: translation,
    );
  }

  Future<SentenceAnalysis> _aiAnalyzeSentence(String word, String sentence, String translation) async {
    // 使用DeepSeek API进行深度分析
    final result = await DeepSeekApiService.judgeSentence(
      word: word,
      sentence: sentence,
      translation: translation,
    );

    // 更详细的分析
    return SentenceAnalysis(
      isCorrect: result?.isCorrect ?? false,
      grammarScore: _calculateEnhancedGrammarScore(result, sentence),
      usageScore: _calculateEnhancedUsageScore(result, word, sentence),
      complexityScore: _calculateEnhancedComplexityScore(sentence),
      grammarErrors: _parseEnhancedGrammarErrors(result),
      usageErrors: _parseEnhancedUsageErrors(result),
      betterSentence: result?.betterSentences?.isNotEmpty == true ? result!.betterSentences.first : null,
      improvements: result?.suggestions ?? [],
      complexity: _determineEnhancedComplexity(sentence),
    );
  }

  int _calculateEnhancedGrammarScore(dynamic result, String sentence) {
    // 更精确的语法分数计算
    int baseScore = result?.isCorrect == true ? 8 : 4;
    
    // 根据句子长度调整
    final wordCount = sentence.split(' ').length;
    if (wordCount > 10) baseScore += 1;
    if (wordCount > 15) baseScore += 1;
    
    // 根据错误数量调整
    if (result?.errors != null) {
      baseScore = math.max(1, baseScore - (result!.errors.length as int));
    }
    
    return baseScore.clamp(1, 10);
  }

  int _calculateEnhancedUsageScore(dynamic result, String word, String sentence) {
    // 更精确的用法分数计算
    int baseScore = result?.isCorrect == true ? 8 : 4;
    
    // 检查单词是否在正确的上下文中使用
    if (sentence.toLowerCase().contains(word.toLowerCase())) {
      baseScore += 1;
    }
    
    // 根据建议质量调整
    if (result?.suggestions?.isNotEmpty == true) {
      baseScore = math.max(1, baseScore - ((result!.suggestions.length as int) ~/ 2));
    }
    
    return baseScore.clamp(1, 10);
  }

  int _calculateEnhancedComplexityScore(String sentence) {
    // 更精确的复杂度分数计算
    int score = 5;
    
    final wordCount = sentence.split(' ').length;
    
    // 基于长度
    if (wordCount < 5) score = 3;
    else if (wordCount < 10) score = 5;
    else if (wordCount < 15) score = 7;
    else score = 9;
    
    // 基于语法复杂性
    if (sentence.contains(',')) score += 1;
    if (sentence.contains(';')) score += 1;
    if (sentence.contains('which') || sentence.contains('that')) score += 1;
    
    return score.clamp(1, 10);
  }

  List<GrammarError> _parseEnhancedGrammarErrors(dynamic result) {
    // 增强的语法错误解析
    final errors = <GrammarError>[];
    if (result?.errors != null) {
      for (int i = 0; i < result!.errors.length; i++) {
        final error = result.errors[i];
        errors.add(GrammarError(
          type: error?.type ?? 'grammar',
          description: error?.description ?? '',
          suggestion: error?.suggestion ?? '',
          position: i,
        ));
      }
    }
    return errors;
  }

  List<UsageError> _parseEnhancedUsageErrors(dynamic result) {
    // 增强的用法错误解析
    final errors = <UsageError>[];
    if (result?.suggestions?.isNotEmpty == true) {
      for (final suggestion in result!.suggestions) {
        errors.add(UsageError(
          type: 'usage',
          description: suggestion ?? '',
          correctUsage: result.betterSentences?.isNotEmpty == true ? result.betterSentences!.first : '',
          example: result.betterSentences?.isNotEmpty == true ? result.betterSentences!.first : '',
        ));
      }
    }
    return errors;
  }

  SentenceComplexity _determineEnhancedComplexity(String sentence) {
    // 增强的复杂度判断
    final wordCount = sentence.split(' ').length;
    int complexityScore = 0;
    
    // 基于长度
    if (wordCount >= 5) complexityScore += 1;
    if (wordCount >= 10) complexityScore += 1;
    if (wordCount >= 15) complexityScore += 1;
    
    // 基于语法结构
    if (sentence.contains(',')) complexityScore += 1;
    if (sentence.contains(';')) complexityScore += 1;
    if (sentence.contains('which') || sentence.contains('that')) complexityScore += 1;
    
    switch (complexityScore) {
      case 0:
      case 1:
        return SentenceComplexity.simple;
      case 2:
      case 3:
        return SentenceComplexity.medium;
      case 4:
      case 5:
        return SentenceComplexity.complex;
      default:
        return SentenceComplexity.advanced;
    }
  }

  @override
  void updateConfig(AlgorithmConfig newConfig) {
    config = newConfig;
    
    // 实时调整开关
    if (adaptiveConfig.realTimeAdjustment) {
      _performRealTimeAdjustment();
    }
  }

  void _performRealTimeAdjustment() {
    // 实时调整算法参数
    // 这里可以根据最近的学习数据调整配置
  }

  @override
  Map<String, dynamic> getStatistics(List<EnhancedWordLearningRecord> records) {
    final stats = <String, dynamic>{};
    
    // 基础统计
    stats['totalWords'] = records.length;
    stats['reviewWords'] = getReviewWords(records).length;
    
    // 自适应特有统计
    stats['learningAbility'] = adaptiveConfig.learningAbility;
    stats['memoryRetention'] = adaptiveConfig.memoryRetention;
    stats['studyConsistency'] = adaptiveConfig.studyConsistency;
    
    // 个性化因子
    stats['personalFactors'] = adaptiveConfig.personalFactors;
    
    // 推荐的学习强度
    final recommendedIntensity = _calculateRecommendedIntensity(records);
    stats['recommendedIntensity'] = recommendedIntensity;
    
    return stats;
  }

  double _calculateRecommendedIntensity(List<EnhancedWordLearningRecord> records) {
    // 根据用户的学习数据计算推荐的学习强度
    if (records.isEmpty) return 0.5;
    
    // 基于最近的学习表现
    final recentRecords = records.where((r) {
      final daysSinceLastLearning = DateTime.now().difference(r.lastLearningTime).inDays;
      return daysSinceLastLearning <= adaptiveConfig.analysisWindowDays;
    }).toList();
    
    if (recentRecords.isEmpty) return 0.5;
    
    // 计算平均掌握程度
    final avgMastery = recentRecords.map((r) => r.masteryPercentage).reduce((a, b) => a + b) / recentRecords.length;
    
    // 根据掌握程度调整强度
    if (avgMastery > 0.8) return 0.7; // 高掌握度，可以提高强度
    if (avgMastery > 0.6) return 0.5; // 中等掌握度，维持平衡
    return 0.3; // 低掌握度，降低强度
  }
} 