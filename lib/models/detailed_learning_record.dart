import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'word_learning_record.dart';

/// 详细的学习会话记录
class DetailedLearningSession {
  final String sessionId;              // 会话ID
  final DateTime sessionTime;          // 学习时间
  final LearningMode learningMode;     // 学习模式
  final LearningResult result;         // 学习结果
  final int score;                     // 评分 (0-10)
  final String? userInput;             // 用户输入（造句内容）
  final SentenceAnalysis? sentenceAnalysis; // 造句分析
  final Duration studyDuration;        // 学习耗时
  final List<String> mistakes;         // 错误记录
  final String? feedback;              // 反馈信息
  final Map<String, dynamic> metadata; // 其他元数据

  const DetailedLearningSession({
    required this.sessionId,
    required this.sessionTime,
    required this.learningMode,
    required this.result,
    required this.score,
    this.userInput,
    this.sentenceAnalysis,
    required this.studyDuration,
    this.mistakes = const [],
    this.feedback,
    this.metadata = const {},
  });

  factory DetailedLearningSession.fromJson(Map<String, dynamic> json) {
    return DetailedLearningSession(
      sessionId: json['sessionId'],
      sessionTime: DateTime.parse(json['sessionTime']),
      learningMode: LearningMode.values[json['learningMode']],
      result: LearningResult.values[json['result']],
      score: json['score'],
      userInput: json['userInput'],
      sentenceAnalysis: json['sentenceAnalysis'] != null 
          ? SentenceAnalysis.fromJson(json['sentenceAnalysis'])
          : null,
      studyDuration: Duration(milliseconds: json['studyDuration']),
      mistakes: List<String>.from(json['mistakes'] ?? []),
      feedback: json['feedback'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionTime': sessionTime.toIso8601String(),
      'learningMode': learningMode.index,
      'result': result.index,
      'score': score,
      'userInput': userInput,
      'sentenceAnalysis': sentenceAnalysis?.toJson(),
      'studyDuration': studyDuration.inMilliseconds,
      'mistakes': mistakes,
      'feedback': feedback,
      'metadata': metadata,
    };
  }
}

/// 学习模式枚举
enum LearningMode {
  quickMemory,    // 快速记忆模式
  deepLearning,   // 深入学习模式
  review,         // 复习模式
  test,           // 测试模式
}

/// 学习结果枚举
enum LearningResult {
  unknown,        // 不认识
  known,          // 认识
  skipped,        // 跳过
  correct,        // 正确
  incorrect,      // 错误
  excellent,      // 优秀
}

/// 造句分析
class SentenceAnalysis {
  final bool isCorrect;                // 是否正确
  final int grammarScore;              // 语法分数 (0-10)
  final int usageScore;                // 用法分数 (0-10)
  final int complexityScore;           // 复杂度分数 (0-10)
  final List<GrammarError> grammarErrors; // 语法错误
  final List<UsageError> usageErrors;  // 用法错误
  final String? betterSentence;        // 更好的句子建议
  final List<String> improvements;     // 改进建议
  final SentenceComplexity complexity; // 复杂度评级

  const SentenceAnalysis({
    required this.isCorrect,
    required this.grammarScore,
    required this.usageScore,
    required this.complexityScore,
    required this.grammarErrors,
    required this.usageErrors,
    this.betterSentence,
    required this.improvements,
    required this.complexity,
  });

  factory SentenceAnalysis.fromJson(Map<String, dynamic> json) {
    return SentenceAnalysis(
      isCorrect: json['isCorrect'],
      grammarScore: json['grammarScore'],
      usageScore: json['usageScore'],
      complexityScore: json['complexityScore'],
      grammarErrors: (json['grammarErrors'] as List<dynamic>?)
          ?.map((e) => GrammarError.fromJson(e))
          .toList() ?? [],
      usageErrors: (json['usageErrors'] as List<dynamic>?)
          ?.map((e) => UsageError.fromJson(e))
          .toList() ?? [],
      betterSentence: json['betterSentence'],
      improvements: List<String>.from(json['improvements'] ?? []),
      complexity: SentenceComplexity.values[json['complexity']],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isCorrect': isCorrect,
      'grammarScore': grammarScore,
      'usageScore': usageScore,
      'complexityScore': complexityScore,
      'grammarErrors': grammarErrors.map((e) => e.toJson()).toList(),
      'usageErrors': usageErrors.map((e) => e.toJson()).toList(),
      'betterSentence': betterSentence,
      'improvements': improvements,
      'complexity': complexity.index,
    };
  }

  /// 获取总分
  int get totalScore => (grammarScore + usageScore + complexityScore / 3).round();
}

/// 语法错误
class GrammarError {
  final String type;           // 错误类型
  final String description;    // 错误描述
  final String suggestion;     // 修改建议
  final int position;          // 错误位置

  const GrammarError({
    required this.type,
    required this.description,
    required this.suggestion,
    required this.position,
  });

  factory GrammarError.fromJson(Map<String, dynamic> json) {
    return GrammarError(
      type: json['type'],
      description: json['description'],
      suggestion: json['suggestion'],
      position: json['position'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'suggestion': suggestion,
      'position': position,
    };
  }
}

/// 用法错误
class UsageError {
  final String type;           // 错误类型
  final String description;    // 错误描述
  final String correctUsage;   // 正确用法
  final String example;        // 示例

  const UsageError({
    required this.type,
    required this.description,
    required this.correctUsage,
    required this.example,
  });

  factory UsageError.fromJson(Map<String, dynamic> json) {
    return UsageError(
      type: json['type'],
      description: json['description'],
      correctUsage: json['correctUsage'],
      example: json['example'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'correctUsage': correctUsage,
      'example': example,
    };
  }
}

/// 句子复杂度
enum SentenceComplexity {
  simple,      // 简单
  medium,      // 中等
  complex,     // 复杂
  advanced,    // 高级
}

/// 扩展的单词学习记录
class EnhancedWordLearningRecord extends WordLearningRecord {
  final List<DetailedLearningSession> sessions; // 详细学习会话
  final WordDifficulty difficulty;               // 单词难度
  final List<String> commonMistakes;             // 常见错误
  final double averageScore;                     // 平均分数
  final int totalStudyTime;                      // 总学习时间（秒）
  final Map<LearningMode, int> modeStats;        // 各模式统计
  final List<String> tags;                       // 标签

  const EnhancedWordLearningRecord({
    required String word,
    required String translation,
    String? wordBookName,
    required DateTime firstLearningTime,
    required DateTime lastLearningTime,
    required DateTime nextReviewTime,
    required MemoryLevel memoryLevel,
    int learningCount = 1,
    int correctCount = 0,
    int incorrectCount = 0,
    double reviewInterval = 1.0,
    double easeFactor = 2.5,
    List<ReviewRecord> reviewHistory = const [],
    required this.sessions,
    required this.difficulty,
    this.commonMistakes = const [],
    this.averageScore = 0.0,
    this.totalStudyTime = 0,
    this.modeStats = const {},
    this.tags = const [],
  }) : super(
          word: word,
          translation: translation,
          wordBookName: wordBookName,
          firstLearningTime: firstLearningTime,
          lastLearningTime: lastLearningTime,
          nextReviewTime: nextReviewTime,
          memoryLevel: memoryLevel,
          learningCount: learningCount,
          correctCount: correctCount,
          incorrectCount: incorrectCount,
          reviewInterval: reviewInterval,
          easeFactor: easeFactor,
          reviewHistory: reviewHistory,
        );

  factory EnhancedWordLearningRecord.fromWordLearningRecord(
    WordLearningRecord record, {
    List<DetailedLearningSession> sessions = const [],
    WordDifficulty difficulty = WordDifficulty.unknown,
    List<String> commonMistakes = const [],
    double averageScore = 0.0,
    int totalStudyTime = 0,
    Map<LearningMode, int> modeStats = const {},
    List<String> tags = const [],
  }) {
    return EnhancedWordLearningRecord(
      word: record.word,
      translation: record.translation,
      wordBookName: record.wordBookName,
      firstLearningTime: record.firstLearningTime,
      lastLearningTime: record.lastLearningTime,
      nextReviewTime: record.nextReviewTime,
      memoryLevel: record.memoryLevel,
      learningCount: record.learningCount,
      correctCount: record.correctCount,
      incorrectCount: record.incorrectCount,
      reviewInterval: record.reviewInterval,
      easeFactor: record.easeFactor,
      reviewHistory: record.reviewHistory,
      sessions: sessions,
      difficulty: difficulty,
      commonMistakes: commonMistakes,
      averageScore: averageScore,
      totalStudyTime: totalStudyTime,
      modeStats: modeStats,
      tags: tags,
    );
  }

  factory EnhancedWordLearningRecord.fromJson(Map<String, dynamic> json) {
    final baseRecord = WordLearningRecord.fromJson(json);
    
    // 如果JSON中没有难度信息，根据单词自动分析难度
    WordDifficulty difficulty;
    if (json.containsKey('difficulty')) {
      difficulty = WordDifficulty.values[json['difficulty']];
    } else {
      // 使用难度分析器自动分配
      difficulty = _analyzeDifficulty(baseRecord.word);
    }
    
    return EnhancedWordLearningRecord.fromWordLearningRecord(
      baseRecord,
      sessions: (json['sessions'] as List<dynamic>?)
          ?.map((e) => DetailedLearningSession.fromJson(e))
          .toList() ?? [],
      difficulty: difficulty,
      commonMistakes: List<String>.from(json['commonMistakes'] ?? []),
      averageScore: (json['averageScore'] ?? 0.0).toDouble(),
      totalStudyTime: json['totalStudyTime'] ?? 0,
      modeStats: Map<LearningMode, int>.from(
        (json['modeStats'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(LearningMode.values[int.parse(k)], v),
        ) ?? {},
      ),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  /// 分析单词难度的简化版本（只分认识/不认识）
  static WordDifficulty _analyzeDifficulty(String word) {
    // 默认为不认识，等用户学习后再根据表现调整
    return WordDifficulty.unknown;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'difficulty': difficulty.index,
      'commonMistakes': commonMistakes,
      'averageScore': averageScore,
      'totalStudyTime': totalStudyTime,
      'modeStats': modeStats.map((k, v) => MapEntry(k.index.toString(), v)),
      'tags': tags,
    });
    return json;
  }

  /// 添加学习会话
  EnhancedWordLearningRecord addSession(DetailedLearningSession session) {
    final newSessions = [...sessions, session];
    final newModeStats = Map<LearningMode, int>.from(modeStats);
    newModeStats[session.learningMode] = (newModeStats[session.learningMode] ?? 0) + 1;
    
    final newAverageScore = sessions.isEmpty 
        ? session.score.toDouble()
        : (averageScore * sessions.length + session.score) / (sessions.length + 1);
    
    return EnhancedWordLearningRecord(
      word: word,
      translation: translation,
      wordBookName: wordBookName,
      firstLearningTime: firstLearningTime,
      lastLearningTime: session.sessionTime,
      nextReviewTime: nextReviewTime,
      memoryLevel: memoryLevel,
      learningCount: learningCount + 1,
      correctCount: correctCount + (session.result.isCorrect ? 1 : 0),
      incorrectCount: incorrectCount + (session.result.isCorrect ? 0 : 1),
      reviewInterval: reviewInterval,
      easeFactor: easeFactor,
      reviewHistory: reviewHistory,
      sessions: newSessions,
      difficulty: difficulty,
      commonMistakes: commonMistakes,
      averageScore: newAverageScore,
      totalStudyTime: totalStudyTime + session.studyDuration.inSeconds,
      modeStats: newModeStats,
      tags: tags,
    );
  }

  /// 获取最近的学习会话
  DetailedLearningSession? get lastSession {
    return sessions.isNotEmpty ? sessions.last : null;
  }

  /// 获取造句会话
  List<DetailedLearningSession> get sentenceSessions {
    return sessions.where((s) => s.userInput != null).toList();
  }

  /// 获取快速记忆会话
  List<DetailedLearningSession> get quickMemorySessions {
    return sessions.where((s) => s.learningMode == LearningMode.quickMemory).toList();
  }
}

/// 单词难度（简化版）
enum WordDifficulty {
  known,      // 认识
  unknown,    // 不认识
}

/// 扩展方法
extension LearningModeExtension on LearningMode {
  String get displayName {
    switch (this) {
      case LearningMode.quickMemory:
        return '快速记忆';
      case LearningMode.deepLearning:
        return '深入学习';
      case LearningMode.review:
        return '复习模式';
      case LearningMode.test:
        return '测试模式';
    }
  }

  IconData get icon {
    switch (this) {
      case LearningMode.quickMemory:
        return Icons.flash_on;
      case LearningMode.deepLearning:
        return Icons.psychology;
      case LearningMode.review:
        return Icons.refresh;
      case LearningMode.test:
        return Icons.quiz;
    }
  }
}

extension LearningResultExtension on LearningResult {
  String get displayName {
    switch (this) {
      case LearningResult.unknown:
        return '不认识';
      case LearningResult.known:
        return '认识';
      case LearningResult.skipped:
        return '跳过';
      case LearningResult.correct:
        return '正确';
      case LearningResult.incorrect:
        return '错误';
      case LearningResult.excellent:
        return '优秀';
    }
  }

  bool get isCorrect {
    return this == LearningResult.known || 
           this == LearningResult.correct || 
           this == LearningResult.excellent;
  }

  Color get color {
    switch (this) {
      case LearningResult.unknown:
      case LearningResult.incorrect:
        return const Color(0xFF387665); // 深绿色替代红色
      case LearningResult.known:
      case LearningResult.correct:
        return const Color(0xFF60B49D); // 主要初音色
      case LearningResult.excellent:
        return const Color(0xFF60A1B4); // 蓝色调
      case LearningResult.skipped:
        return const Color(0xFF60B473); // 绿色调替代橙色
    }
  }
}

extension WordDifficultyExtension on WordDifficulty {
  String get displayName {
    switch (this) {
      case WordDifficulty.known:
        return '认识';
      case WordDifficulty.unknown:
        return '不认识';
    }
  }

  Color get color {
    switch (this) {
      case WordDifficulty.known:
        return Colors.green;
      case WordDifficulty.unknown:
        return Colors.red;
    }
  }
}

extension SentenceComplexityExtension on SentenceComplexity {
  String get displayName {
    switch (this) {
      case SentenceComplexity.simple:
        return '简单';
      case SentenceComplexity.medium:
        return '中等';
      case SentenceComplexity.complex:
        return '复杂';
      case SentenceComplexity.advanced:
        return '高级';
    }
  }

  Color get color {
    switch (this) {
      case SentenceComplexity.simple:
        return Colors.green;
      case SentenceComplexity.medium:
        return Colors.orange;
      case SentenceComplexity.complex:
        return Colors.red;
      case SentenceComplexity.advanced:
        return Colors.purple;
    }
  }
} 