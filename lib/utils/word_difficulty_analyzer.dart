import '../models/detailed_learning_record.dart';

/// 单词难度分析器（简化版）
/// 只分为认识和不认识两种状态
class WordDifficultyAnalyzer {
  /// 分析单词难度（简化版：只分认识/不认识）
  static WordDifficulty analyzeDifficulty(String word) {
    // 默认为不认识，等用户学习后再根据学习结果调整
    return WordDifficulty.unknown;
  }
  
  /// 根据学习表现调整难度（认识/不认识）
  static WordDifficulty adjustDifficultyByPerformance(
    WordDifficulty currentDifficulty,
    double masteryPercentage,
    int learningCount,
  ) {
    // 如果连续认识3次以上，且掌握程度超过80%，标记为认识
    if (learningCount >= 3 && masteryPercentage >= 0.8) {
      return WordDifficulty.known;
    }
    
    // 如果掌握程度很低，标记为不认识
    if (masteryPercentage < 0.3) {
      return WordDifficulty.unknown;
    }
    
    return currentDifficulty;
  }
  
  /// 批量分析单词难度
  static Map<String, WordDifficulty> batchAnalyze(List<String> words) {
    final results = <String, WordDifficulty>{};
    
    for (final word in words) {
      results[word] = analyzeDifficulty(word);
    }
    
    return results;
  }
  
  /// 获取难度统计
  static Map<WordDifficulty, int> getDifficultyStatistics(List<String> words) {
    final stats = <WordDifficulty, int>{
      WordDifficulty.known: 0,
      WordDifficulty.unknown: 0,
    };
    
    for (final word in words) {
      final difficulty = analyzeDifficulty(word);
      stats[difficulty] = stats[difficulty]! + 1;
    }
    
    return stats;
  }
} 