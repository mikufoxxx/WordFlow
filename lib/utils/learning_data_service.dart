// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/word_book.dart';
import '../models/word_learning_record.dart';
import '../pages/settings_page.dart'; // 导入ImportMode枚举
import 'spaced_repetition_service.dart';
import 'settings_helper.dart';
import 'cache_service.dart';

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
  final Map<String, List<WordLearningRecord>> _cachedRecords = {};
  
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

  /// 删除单词学习记录
  Future<void> removeWordLearningRecord(String word, String wordBookName) async {
    // 更新缓存
    final records = await getWordBookRecords(wordBookName);
    records.removeWhere((r) => r.word == word);
    
    // 从全局记录中删除
    _globalWordRecords.remove(word);
    
    // 保存到存储
    await _saveWordBookRecords(wordBookName, records);
    await _saveGlobalWordRecords();
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
      // 检查智能同步是否开启
      final smartSyncEnabled = await SettingsHelper.getSmartSyncEnabled();
      if (!smartSyncEnabled) {
        return;
      }
      

      // 获取目标词书现有的学习记录
      final targetRecords = await getWordBookRecords(targetWordBook);
      final targetWordsMap = {for (final record in targetRecords) record.word: record};
      
      // 获取目标词书的所有可用单词（用于检查单词是否存在于目标词书中）
      final targetWordData = await CacheService.getCachedWordData(targetWordBook);
      final targetAvailableWords = targetWordData?.map((w) => w.word).toSet() ?? <String>{};
      

      bool hasUpdates = false;
      int checkedWords = 0;
      int syncedWords = 0;
      
      // 遍历全局记录中的所有单词（这些是源词书的学习记录）
      for (final globalEntry in _globalWordRecords.entries) {
        final word = globalEntry.key;
        final globalRecord = globalEntry.value;
        
        // 检查这个单词是否存在于目标词书中
        if (targetAvailableWords.contains(word)) {
          checkedWords++;
          

          // 检查目标词书中是否已有这个单词的学习记录
          if (targetWordsMap.containsKey(word)) {
            final targetRecord = targetWordsMap[word]!;

            // 如果目标记录需要更新，则同步数据
            if (_shouldInheritData(globalRecord, targetRecord)) {
              final syncedRecord = _inheritLearningData(globalRecord, targetRecord, targetWordBook);
              targetWordsMap[word] = syncedRecord;
              hasUpdates = true;
              syncedWords++;
            } else {
            }
          } else {
            // 目标词书中没有这个单词的学习记录，但单词存在于词书中
            // 创建新的学习记录，继承全局记录的数据

            // 获取目标词书中这个单词的翻译
            final targetWordInfo = targetWordData?.firstWhere(
              (w) => w.word == word,
              orElse: () => WordData(word: word, translation: globalRecord.translation),
            );
            
            final newRecord = WordLearningRecord(
              word: word,
              translation: targetWordInfo?.translation ?? globalRecord.translation,
              wordBookName: targetWordBook,
              firstLearningTime: globalRecord.firstLearningTime,
              lastLearningTime: globalRecord.lastLearningTime,
              nextReviewTime: globalRecord.nextReviewTime,
              memoryLevel: globalRecord.memoryLevel,
              learningCount: globalRecord.learningCount,
              correctCount: globalRecord.correctCount,
              incorrectCount: globalRecord.incorrectCount,
              reviewInterval: globalRecord.reviewInterval,
              easeFactor: globalRecord.easeFactor,
              reviewHistory: globalRecord.reviewHistory.map((review) => ReviewRecord(
                reviewTime: review.reviewTime,
                reviewResult: review.reviewResult,
                reviewInterval: review.reviewInterval,
              )).toList(),
            );
            
            targetWordsMap[word] = newRecord;
            hasUpdates = true;
            syncedWords++;
          }
        }
      }
      

      if (hasUpdates) {
        // 更新缓存和存储
        _cachedRecords[targetWordBook] = targetWordsMap.values.toList();
        await _saveWordBookRecords(targetWordBook, _cachedRecords[targetWordBook]!);
        
      } else {
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
    if (targetRecord.memoryLevel == MemoryLevel.first_time && 
        globalRecord.learningCount > 1) {
      return true;
    }
    
    // 如果目标记录是新单词，全局记录也是新单词但有学习次数，则继承
    if (targetRecord.memoryLevel == MemoryLevel.first_time && 
        globalRecord.memoryLevel == MemoryLevel.first_time &&
        globalRecord.learningCount > targetRecord.learningCount) {
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

  /// 获取学习数据的CSV字符串
  Future<String> getLearningDataCsv([String? wordBookName]) async {
    List<WordLearningRecord> records;
    
    if (wordBookName == null) {
      // 导出公共单词本（全局记录）
      records = _globalWordRecords.values.toList();
    } else {
      // 导出指定词书的记录
      records = await getWordBookRecords(wordBookName);
    }
    
    final csvData = StringBuffer();
    
    // CSV头部
    csvData.writeln('word,word_book,first_learned_timestamp,last_learned_timestamp,next_review_timestamp,memory_level,learning_count,forgot_count,hard_count,good_count,easy_count,review_interval,ease_factor,mastery_percentage');
    
    // 数据行
    for (final record in records) {
      csvData.writeln([
        _escapeCsvField(record.word),
        _escapeCsvField(record.wordBookName ?? ''),
        (record.firstLearningTime.millisecondsSinceEpoch / 1000).round(),
        (record.lastLearningTime.millisecondsSinceEpoch / 1000).round(),
        (record.nextReviewTime.millisecondsSinceEpoch / 1000).round(),
        _getMemoryLevelName(record.memoryLevel),
        record.learningCount,
        record.forgotCount,
        record.hardCount,
        record.goodCount,
        record.easyCount,
        record.reviewInterval.toStringAsFixed(2),
        record.easeFactor.toStringAsFixed(2),
        (record.masteryPercentage * 100).toStringAsFixed(1),
      ].join(','));
    }
    
    return csvData.toString();
  }

  /// 导出学习数据为CSV文件
  Future<String> exportLearningDataToCsv([String? wordBookName]) async {
    final csvData = await getLearningDataCsv(wordBookName);
    
    // 保存到文件
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = wordBookName == null 
          ? 'wordflow_global_$timestamp.csv'
          : 'wordflow_${wordBookName}_$timestamp.csv';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(csvData, encoding: utf8);
      return file.path;
    } catch (e) {
      throw Exception('导出文件失败: $e');
    }
  }

  /// 转义CSV字段
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// 获取记忆等级的英文名称
  String _getMemoryLevelName(MemoryLevel level) {
    switch (level) {
      case MemoryLevel.first_time:
        return 'first_time';
      case MemoryLevel.reviewing:
        return 'reviewing';
      case MemoryLevel.strengthening:
        return 'strengthening';
      case MemoryLevel.stable:
        return 'stable';
      case MemoryLevel.mastered:
        return 'mastered';
    }
  }

  /// 从CSV导入学习数据
  Future<ImportResult> importLearningDataFromCsv(String csvData, [String? wordBookName, ImportMode importMode = ImportMode.update]) async {
    final lines = csvData.split('\n');
    if (lines.length < 2) {
      return ImportResult(success: false, message: 'CSV文件格式错误');
    }
    
    final importedRecords = <WordLearningRecord>[];
    var importedCount = 0;
    var errorCount = 0;
    var updatedCount = 0;
    var skippedCount = 0;
    
    try {
      // 如果是全部覆盖模式，先清空现有数据
      if (importMode == ImportMode.overwrite) {
        if (wordBookName == null) {
          // 清空全局记录
          _globalWordRecords.clear();
        } else {
          // 清空指定词书的记录
          _cachedRecords[wordBookName] = [];
          await _saveWordBookRecords(wordBookName, []);
          
          // 从全局记录中移除该词书的记录
          final recordsToRemove = <String>[];
          for (final entry in _globalWordRecords.entries) {
            if (entry.value.wordBookName == wordBookName) {
              recordsToRemove.add(entry.key);
            }
          }
          for (final word in recordsToRemove) {
            _globalWordRecords.remove(word);
          }
        }
      }
      
      // 跳过头部，从第二行开始
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = line.split(',');
        if (parts.length < 14) {
          errorCount++;
          continue;
        }
        
        try {
          // 根据导入的统计数据重建reviewHistory（简化版本）
          final forgotCount = int.parse(parts[7]);
          final hardCount = int.parse(parts[8]);
          final goodCount = int.parse(parts[9]);
          final easyCount = int.parse(parts[10]);
          
          final reviewHistory = <ReviewRecord>[];
          final now = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[3]) * 1000); // 使用lastLearningTime，转换为毫秒
          
          // 创建简化的复习历史记录（用于统计计算）
          for (int i = 0; i < forgotCount; i++) {
            reviewHistory.add(ReviewRecord(
              reviewTime: now.subtract(Duration(days: forgotCount - i)),
              reviewResult: ReviewResult.forgot,
              reviewInterval: 1.0,
            ));
          }
          for (int i = 0; i < hardCount; i++) {
            reviewHistory.add(ReviewRecord(
              reviewTime: now.subtract(Duration(days: hardCount - i)),
              reviewResult: ReviewResult.hard,
              reviewInterval: 1.0,
            ));
          }
          for (int i = 0; i < goodCount; i++) {
            reviewHistory.add(ReviewRecord(
              reviewTime: now.subtract(Duration(days: goodCount - i)),
              reviewResult: ReviewResult.good,
              reviewInterval: 1.0,
            ));
          }
          for (int i = 0; i < easyCount; i++) {
            reviewHistory.add(ReviewRecord(
              reviewTime: now.subtract(Duration(days: easyCount - i)),
              reviewResult: ReviewResult.easy,
              reviewInterval: 1.0,
            ));
          }
          
          final newRecord = WordLearningRecord(
            word: parts[0],
            translation: '', // 导入时translation为空，需要重新获取
            wordBookName: wordBookName ?? parts[1], // 如果没有指定词书名，使用CSV中的词书名
            firstLearningTime: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2]) * 1000),
            lastLearningTime: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[3]) * 1000),
            nextReviewTime: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[4]) * 1000),
            memoryLevel: _parseMemoryLevel(parts[5]),
            learningCount: int.parse(parts[6]),
            correctCount: goodCount + easyCount, // 兼容旧字段，根据good和easy计算
            incorrectCount: forgotCount + hardCount, // 兼容旧字段，根据forgot和hard计算
            reviewInterval: double.parse(parts[11]),
            easeFactor: double.parse(parts[12]),
            reviewHistory: reviewHistory,
          );
          
          // 根据导入模式处理记录
          if (importMode == ImportMode.update) {
            // 数据更新模式：检查是否需要更新
            final existingRecord = wordBookName == null 
                ? _globalWordRecords[newRecord.word]
                : (await getWordBookRecords(wordBookName)).where((r) => r.word == newRecord.word).firstOrNull;
            
            if (existingRecord == null) {
              // 新记录，直接添加
              importedRecords.add(newRecord);
              importedCount++;
            } else {
              // 已存在记录，检查是否需要更新（学习进度更好的记录）
              if (_shouldInheritData(newRecord, existingRecord)) {
                importedRecords.add(newRecord);
                updatedCount++;
              } else {
                skippedCount++;
              }
            }
          } else {
            // 全部覆盖模式：直接添加所有记录
            importedRecords.add(newRecord);
            importedCount++;
          }
        } catch (e) {
          errorCount++;
        }
      }
      
      // 保存导入的记录
      if (wordBookName == null) {
        // 导入到公共单词本（全局记录）
        for (final record in importedRecords) {
          _globalWordRecords[record.word] = record;
        }
        await _saveGlobalWordRecords();
      } else {
        // 导入到指定词书
        await saveWordLearningRecords(importedRecords);
      }
      
      // 构建结果消息
      String message;
      if (importMode == ImportMode.update) {
        message = '新增 $importedCount 条记录，更新 $updatedCount 条记录';
        if (skippedCount > 0) {
          message += '，跳过 $skippedCount 条记录';
        }
        if (errorCount > 0) {
          message += '，$errorCount 条记录导入失败';
        }
      } else {
        message = '成功导入 $importedCount 条记录';
        if (errorCount > 0) {
          message += '，$errorCount 条记录导入失败';
        }
      }
      
      return ImportResult(
        success: true,
        message: message,
        importedCount: importedCount + updatedCount,
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
        final recordsJson = jsonDecode(recordsString) as List;
        return recordsJson
            .map((json) => WordLearningRecord.fromJson(json))
            .toList();
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
        final configJson = jsonDecode(configString) as Map<String, dynamic>;
        _loadedAlgorithmConfig = SpacedRepetitionConfig(
          minInterval: configJson['minInterval'] ?? 1.0,
          maxInterval: configJson['maxInterval'] ?? 365.0,
          forgotIntervalMultiplier: configJson['forgotIntervalMultiplier'] ?? 1.0,
          hardIntervalMultiplier: configJson['hardIntervalMultiplier'] ?? 1.2,
          easyIntervalMultiplier: configJson['easyIntervalMultiplier'] ?? 1.3,
          difficultyAdjustment: configJson['difficultyAdjustment'] ?? 1.0,
        );
    }
    
    _loadedAlgorithmConfig ??= SpacedRepetitionConfig.defaultConfig();
  }

  /// 加载全局单词记录
  Future<void> _loadGlobalWordRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsString = prefs.getString(_globalWordRecordsKey);
    
    if (recordsString != null) {
        final recordsJson = jsonDecode(recordsString) as Map<String, dynamic>;
        _globalWordRecords = recordsJson.map((key, value) => 
          MapEntry(key, WordLearningRecord.fromJson(value))
        );
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
    // 先尝试英文名称
    switch (levelName.toLowerCase()) {
      case 'first_time':
        return MemoryLevel.first_time;
      case 'reviewing':
        return MemoryLevel.reviewing;
      case 'strengthening':
        return MemoryLevel.strengthening;
      case 'stable':
        return MemoryLevel.stable;
      case 'mastered':
        return MemoryLevel.mastered;
    }
    
    // 兼容旧的中文名称
    for (final level in MemoryLevel.values) {
      if (level.displayName == levelName) {
        return level;
      }
    }
    
    return MemoryLevel.first_time;
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