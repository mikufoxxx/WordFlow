import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/word_learning_record.dart';
import '../models/word_book.dart';
import 'spaced_repetition_service.dart';

/// 学习数据管理服务
/// 统一管理所有学习相关数据的存储、加载和同步
class LearningDataService {
  static const String _learningRecordsKey = 'learning_records';
  static const String _algorithmConfigKey = 'algorithm_config';
  static const String _globalWordRecordsKey = 'global_word_records';
  
  static LearningDataService? _instance;
  static LearningDataService get instance => _instance ??= LearningDataService._();
  
  LearningDataService._();

  /// 间隔重复算法服务
  SpacedRepetitionService? _spacedRepetitionService;
  
  /// 缓存的学习记录
  Map<String, List<WordLearningRecord>> _cachedRecords = {};
  
  /// 全局单词记录（用于词书间同步）
  Map<String, WordLearningRecord> _globalWordRecords = {};
  
  /// 获取间隔重复算法服务
  SpacedRepetitionService get spacedRepetitionService {
    _spacedRepetitionService ??= SpacedRepetitionService(
      config: _loadedAlgorithmConfig,
    );
    return _spacedRepetitionService!;
  }

  SpacedRepetitionConfig? _loadedAlgorithmConfig;

  /// 初始化服务
  Future<void> initialize() async {
    await _loadAlgorithmConfig();
    await _loadGlobalWordRecords();
  }

  /// 获取指定词书的学习记录
  Future<List<WordLearningRecord>> getWordBookRecords(String wordBookName) async {
    // 先检查缓存
    if (_cachedRecords.containsKey(wordBookName)) {
      return _cachedRecords[wordBookName]!;
    }

    // 从存储中加载
    final records = await _loadWordBookRecords(wordBookName);
    _cachedRecords[wordBookName] = records;
    return records;
  }

  /// 保存学习记录
  Future<void> saveWordLearningRecord(WordLearningRecord record) async {
    final wordBookName = record.wordBookName ?? 'default';
    
    // 更新缓存
    final records = await getWordBookRecords(wordBookName);
    final existingIndex = records.indexWhere((r) => r.word == record.word);
    
    if (existingIndex >= 0) {
      records[existingIndex] = record;
    } else {
      records.add(record);
    }
    
    // 同步到全局记录
    _globalWordRecords[record.word] = record;
    
    // 保存到存储
    await _saveWordBookRecords(wordBookName, records);
    await _saveGlobalWordRecords();
  }

  /// 批量保存学习记录
  Future<void> saveWordLearningRecords(List<WordLearningRecord> records) async {
    for (final record in records) {
      await saveWordLearningRecord(record);
    }
  }

  /// 获取需要复习的单词（无限流）
  Future<List<WordLearningRecord>> getReviewWords(String wordBookName) async {
    final records = await getWordBookRecords(wordBookName);
    return spacedRepetitionService.getReviewWords(records);
  }

  /// 获取学习进度概览
  Future<LearningProgress> getStudyProgress(String wordBookName) async {
    final records = await getWordBookRecords(wordBookName);
    return spacedRepetitionService.getStudyProgress(records);
  }

  /// 获取智能推荐的学习单词
  Future<List<String>> getRecommendedWords(String wordBookName, List<String> availableWords, {int maxCount = 10}) async {
    final records = await getWordBookRecords(wordBookName);
    return spacedRepetitionService.getRecommendedWords(records, availableWords, maxCount: maxCount);
  }

  /// 获取学习统计
  Future<LearningStats> getLearningStats(String wordBookName) async {
    final records = await getWordBookRecords(wordBookName);
    return spacedRepetitionService.generateLearningStats(records);
  }



  /// 词书间数据同步
  Future<void> syncWordBookData(String fromWordBook, String toWordBook) async {
    final fromRecords = await getWordBookRecords(fromWordBook);
    final toRecords = await getWordBookRecords(toWordBook);
    
    final Map<String, WordLearningRecord> toRecordsMap = {
      for (final record in toRecords) record.word: record
    };
    
    final List<WordLearningRecord> updatedRecords = [];
    
    for (final fromRecord in fromRecords) {
      if (toRecordsMap.containsKey(fromRecord.word)) {
        // 词书中已存在该单词，继承学习数据
        final existingRecord = toRecordsMap[fromRecord.word]!;
        final inheritedRecord = _inheritLearningData(fromRecord, existingRecord, toWordBook);
        updatedRecords.add(inheritedRecord);
        toRecordsMap[fromRecord.word] = inheritedRecord;
      }
    }
    
    // 更新缓存和存储
    _cachedRecords[toWordBook] = toRecordsMap.values.toList();
    await _saveWordBookRecords(toWordBook, _cachedRecords[toWordBook]!);
    
    // 同步到全局记录
    for (final record in updatedRecords) {
      _globalWordRecords[record.word] = record;
    }
    await _saveGlobalWordRecords();
  }

  /// 自动同步词书数据（切换词书时调用）
  Future<void> autoSyncWordBook(String targetWordBook) async {
    try {
      // 从全局记录中继承相同单词的学习数据
      final targetRecords = await getWordBookRecords(targetWordBook);
      final targetWordsMap = {for (final record in targetRecords) record.word: record};
      
      bool hasUpdates = false;
      final List<WordLearningRecord> updatedRecords = [];
      
      for (final globalEntry in _globalWordRecords.entries) {
        final word = globalEntry.key;
        final globalRecord = globalEntry.value;
        
        if (targetWordsMap.containsKey(word)) {
          final targetRecord = targetWordsMap[word]!;
          
          // 比较学习进度，选择更好的数据
          if (_shouldInheritData(globalRecord, targetRecord)) {
            final inheritedRecord = _inheritLearningData(globalRecord, targetRecord, targetWordBook);
            updatedRecords.add(inheritedRecord);
            targetWordsMap[word] = inheritedRecord;
            hasUpdates = true;
          }
        }
      }
      
      if (hasUpdates) {
        // 更新缓存和存储
        _cachedRecords[targetWordBook] = targetWordsMap.values.toList();
        await _saveWordBookRecords(targetWordBook, _cachedRecords[targetWordBook]!);
        
        print('✅ 自动同步了 ${updatedRecords.length} 个单词的学习数据到 $targetWordBook');
      }
    } catch (e) {
      print('❌ 自动同步失败: $e');
    }
  }

  /// 判断是否应该继承全局数据
  bool _shouldInheritData(WordLearningRecord globalRecord, WordLearningRecord targetRecord) {
    // 如果全局记录的记忆程度更高，则继承
    if (globalRecord.memoryLevel.index > targetRecord.memoryLevel.index) {
      return true;
    }
    
    // 如果记忆程度相同，但学习次数更多，则继承
    if (globalRecord.memoryLevel == targetRecord.memoryLevel && 
        globalRecord.learningCount > targetRecord.learningCount) {
      return true;
    }
    
    // 如果目标记录是新单词，但全局记录有学习历史，则继承
    if (targetRecord.memoryLevel == MemoryLevel.new_word && 
        globalRecord.learningCount > 1) {
      return true;
    }
    
    return false;
  }

  /// 继承学习数据
  WordLearningRecord _inheritLearningData(
    WordLearningRecord sourceRecord, 
    WordLearningRecord targetRecord, 
    String newWordBookName
  ) {
    // 选择更好的学习数据进行继承
    final betterRecord = sourceRecord.memoryLevel.index > targetRecord.memoryLevel.index 
        ? sourceRecord 
        : targetRecord;
    
    return WordLearningRecord(
      word: targetRecord.word,
      translation: targetRecord.translation,
      wordBookName: newWordBookName,
      firstLearningTime: _earlierDateTime(sourceRecord.firstLearningTime, targetRecord.firstLearningTime),
      lastLearningTime: _laterDateTime(sourceRecord.lastLearningTime, targetRecord.lastLearningTime),
      nextReviewTime: betterRecord.nextReviewTime,
      memoryLevel: betterRecord.memoryLevel,
      learningCount: sourceRecord.learningCount + targetRecord.learningCount,
      correctCount: sourceRecord.correctCount + targetRecord.correctCount,
      incorrectCount: sourceRecord.incorrectCount + targetRecord.incorrectCount,
      reviewInterval: betterRecord.reviewInterval,
      easeFactor: betterRecord.easeFactor,
      reviewHistory: [...sourceRecord.reviewHistory, ...targetRecord.reviewHistory]
        ..sort((a, b) => a.reviewTime.compareTo(b.reviewTime)),
    );
  }

  /// 导出学习数据为CSV文件
  Future<String> exportLearningDataToCsv(String wordBookName) async {
    final records = await getWordBookRecords(wordBookName);
    final csvData = StringBuffer();
    
    // CSV头部
    csvData.writeln('单词,翻译,词书,首次学习时间,最后学习时间,下次复习时间,记忆程度,学习次数,正确次数,错误次数,复习间隔,难度系数,掌握程度');
    
    // 数据行
    for (final record in records) {
      csvData.writeln([
        record.word,
        record.translation,
        record.wordBookName ?? '',
        record.firstLearningTime.toIso8601String(),
        record.lastLearningTime.toIso8601String(),
        record.nextReviewTime.toIso8601String(),
        record.memoryLevel.displayName,
        record.learningCount,
        record.correctCount,
        record.incorrectCount,
        record.reviewInterval,
        record.easeFactor,
        '${(record.masteryPercentage * 100).toStringAsFixed(1)}%',
      ].join(','));
    }
    
    // 保存到文件
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'wordflow_${wordBookName}_$timestamp.csv';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(csvData.toString());
      return file.path;
    } catch (e) {
      throw Exception('导出文件失败: $e');
    }
  }

  /// 从CSV导入学习数据
  Future<ImportResult> importLearningDataFromCsv(String csvData, String wordBookName) async {
    final lines = csvData.split('\n');
    if (lines.length < 2) {
      return ImportResult(success: false, message: 'CSV文件格式错误');
    }
    
    final importedRecords = <WordLearningRecord>[];
    var importedCount = 0;
    var errorCount = 0;
    
    try {
      // 跳过头部，从第二行开始
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = line.split(',');
        if (parts.length < 13) {
          errorCount++;
          continue;
        }
        
        try {
          final record = WordLearningRecord(
            word: parts[0],
            translation: parts[1],
            wordBookName: wordBookName,
            firstLearningTime: DateTime.parse(parts[3]),
            lastLearningTime: DateTime.parse(parts[4]),
            nextReviewTime: DateTime.parse(parts[5]),
            memoryLevel: _parseMemoryLevel(parts[6]),
            learningCount: int.parse(parts[7]),
            correctCount: int.parse(parts[8]),
            incorrectCount: int.parse(parts[9]),
            reviewInterval: double.parse(parts[10]),
            easeFactor: double.parse(parts[11]),
            reviewHistory: [], // 复习历史暂不导入
          );
          
          importedRecords.add(record);
          importedCount++;
        } catch (e) {
          errorCount++;
        }
      }
      
      // 保存导入的记录
      await saveWordLearningRecords(importedRecords);
      
      return ImportResult(
        success: true,
        message: '成功导入 $importedCount 条记录${errorCount > 0 ? '，$errorCount 条记录导入失败' : ''}',
        importedCount: importedCount,
        errorCount: errorCount,
      );
      
    } catch (e) {
      return ImportResult(success: false, message: '导入失败: ${e.toString()}');
    }
  }

  /// 保存算法配置
  Future<void> saveAlgorithmConfig(SpacedRepetitionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = {
      'minInterval': config.minInterval,
      'maxInterval': config.maxInterval,
      'forgotIntervalMultiplier': config.forgotIntervalMultiplier,
      'hardIntervalMultiplier': config.hardIntervalMultiplier,
      'easyIntervalMultiplier': config.easyIntervalMultiplier,
      'difficultyAdjustment': config.difficultyAdjustment,
    };
    
    await prefs.setString(_algorithmConfigKey, jsonEncode(configJson));
    _loadedAlgorithmConfig = config;
    _spacedRepetitionService = SpacedRepetitionService(config: config);
  }

  /// 获取算法配置
  Future<SpacedRepetitionConfig> getAlgorithmConfig() async {
    if (_loadedAlgorithmConfig != null) {
      return _loadedAlgorithmConfig!;
    }
    
    await _loadAlgorithmConfig();
    return _loadedAlgorithmConfig ?? SpacedRepetitionConfig.defaultConfig();
  }

  /// 清除学习数据
  Future<void> clearLearningData([String? wordBookName]) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (wordBookName != null) {
      // 清除指定词书的数据
      await prefs.remove('${_learningRecordsKey}_$wordBookName');
      _cachedRecords.remove(wordBookName);
      
      // 从全局记录中移除
      final records = await _loadWordBookRecords(wordBookName);
      for (final record in records) {
        _globalWordRecords.remove(record.word);
      }
    } else {
      // 清除所有学习数据
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_learningRecordsKey)) {
          await prefs.remove(key);
        }
      }
      await prefs.remove(_globalWordRecordsKey);
      _cachedRecords.clear();
      _globalWordRecords.clear();
    }
    
    await _saveGlobalWordRecords();
  }

  /// 从存储中加载指定词书的学习记录
  Future<List<WordLearningRecord>> _loadWordBookRecords(String wordBookName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_learningRecordsKey}_$wordBookName';
    final recordsString = prefs.getString(key);
    
    if (recordsString != null) {
      try {
        final recordsJson = jsonDecode(recordsString) as List;
        return recordsJson
            .map((json) => WordLearningRecord.fromJson(json))
            .toList();
      } catch (e) {
        print('❌ 加载学习记录失败: $e');
      }
    }
    
    return [];
  }

  /// 保存指定词书的学习记录到存储
  Future<void> _saveWordBookRecords(String wordBookName, List<WordLearningRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_learningRecordsKey}_$wordBookName';
    final recordsJson = records.map((record) => record.toJson()).toList();
    await prefs.setString(key, jsonEncode(recordsJson));
  }

  /// 加载算法配置
  Future<void> _loadAlgorithmConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configString = prefs.getString(_algorithmConfigKey);
    
    if (configString != null) {
      try {
        final configJson = jsonDecode(configString) as Map<String, dynamic>;
        _loadedAlgorithmConfig = SpacedRepetitionConfig(
          minInterval: configJson['minInterval'] ?? 1.0,
          maxInterval: configJson['maxInterval'] ?? 365.0,
          forgotIntervalMultiplier: configJson['forgotIntervalMultiplier'] ?? 1.0,
          hardIntervalMultiplier: configJson['hardIntervalMultiplier'] ?? 1.2,
          easyIntervalMultiplier: configJson['easyIntervalMultiplier'] ?? 1.3,
          difficultyAdjustment: configJson['difficultyAdjustment'] ?? 1.0,
        );
      } catch (e) {
        print('❌ 加载算法配置失败: $e');
      }
    }
    
    _loadedAlgorithmConfig ??= SpacedRepetitionConfig.defaultConfig();
  }

  /// 加载全局单词记录
  Future<void> _loadGlobalWordRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsString = prefs.getString(_globalWordRecordsKey);
    
    if (recordsString != null) {
      try {
        final recordsJson = jsonDecode(recordsString) as Map<String, dynamic>;
        _globalWordRecords = recordsJson.map((key, value) => 
          MapEntry(key, WordLearningRecord.fromJson(value))
        );
      } catch (e) {
        print('❌ 加载全局单词记录失败: $e');
      }
    }
  }

  /// 保存全局单词记录
  Future<void> _saveGlobalWordRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = _globalWordRecords.map((key, value) => 
      MapEntry(key, value.toJson())
    );
    await prefs.setString(_globalWordRecordsKey, jsonEncode(recordsJson));
  }

  /// 解析记忆程度
  MemoryLevel _parseMemoryLevel(String levelName) {
    for (final level in MemoryLevel.values) {
      if (level.displayName == levelName) {
        return level;
      }
    }
    return MemoryLevel.new_word;
  }

  /// 获取较早的时间
  DateTime _earlierDateTime(DateTime a, DateTime b) {
    return a.isBefore(b) ? a : b;
  }

  /// 获取较晚的时间
  DateTime _laterDateTime(DateTime a, DateTime b) {
    return a.isAfter(b) ? a : b;
  }
}

/// 导入结果
class ImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final int errorCount;

  const ImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
    this.errorCount = 0,
  });
} 