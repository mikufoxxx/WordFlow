import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/algorithm_config.dart';
import '../models/detailed_learning_record.dart';
import 'multi_algorithm_service.dart';

/// 算法管理器
/// 统一管理三种算法的配置、切换和数据服务
class AlgorithmManager {
  static const String _currentAlgorithmKey = 'current_algorithm';
  static const String _algorithmConfigsKey = 'algorithm_configs';
  
  static AlgorithmManager? _instance;
  static AlgorithmManager get instance => _instance ??= AlgorithmManager._();
  
  AlgorithmManager._();

  // 当前算法配置
  AlgorithmConfig? _currentConfig;
  
  // 所有算法配置
  final Map<AlgorithmType, AlgorithmConfig> _configs = {};
  
  // 当前算法服务
  MultiAlgorithmService? _currentService;

  /// 初始化算法管理器
  Future<void> initialize() async {
    await _loadConfigs();
    await _loadCurrentAlgorithm();
  }

  /// 获取当前算法配置
  AlgorithmConfig? get currentConfig => _currentConfig;

  /// 获取当前算法服务
  MultiAlgorithmService? get currentService => _currentService;

  /// 获取所有算法配置
  Map<AlgorithmType, AlgorithmConfig> get allConfigs => Map.unmodifiable(_configs);

  /// 切换算法
  Future<void> switchAlgorithm(AlgorithmType type) async {
    if (_configs.containsKey(type)) {
      _currentConfig = _configs[type]!;
      _currentService = MultiAlgorithmService(config: _currentConfig!);
      
      await _saveCurrentAlgorithm();
    } else {
      throw ArgumentError('未找到算法配置: $type');
    }
  }

  /// 更新算法配置
  Future<void> updateConfig(AlgorithmConfig config) async {
    _configs[config.type] = config;
    
    // 如果是当前算法，更新服务
    if (_currentConfig?.type == config.type) {
      _currentConfig = config;
      _currentService?.updateConfig(config);
    }
    
    await _saveConfigs();
  }

  /// 重置算法配置
  Future<void> resetConfig(AlgorithmType type) async {
    final defaultConfig = type.defaultConfig;
    await updateConfig(defaultConfig);
  }

  /// 获取指定算法配置
  AlgorithmConfig? getConfig(AlgorithmType type) {
    return _configs[type];
  }

  /// 验证配置
  ValidationResult validateConfig(AlgorithmConfig config) {
    switch (config.type) {
      case AlgorithmType.superMemo:
        return ParameterValidator.validateSuperMemo(config as SuperMemoConfig);
      case AlgorithmType.anki:
        return ParameterValidator.validateAnki(config as AnkiConfig);
      case AlgorithmType.adaptive:
        return ParameterValidator.validateAdaptive(config as AdaptiveConfig);
    }
  }

  /// 导出配置
  String exportConfig(AlgorithmType type) {
    final config = _configs[type];
    if (config == null) {
      throw ArgumentError('未找到算法配置: $type');
    }
    
    return jsonEncode(config.toJson());
  }

  /// 导入配置
  Future<void> importConfig(String configJson) async {
    try {
      final json = jsonDecode(configJson) as Map<String, dynamic>;
      final config = AlgorithmConfig.fromJson(json);
      
      // 验证配置
      final validation = validateConfig(config);
      if (!validation.isValid) {
        throw ArgumentError('配置验证失败: ${validation.errors.join(', ')}');
      }
      
      await updateConfig(config);
    } catch (e) {
      throw ArgumentError('导入配置失败: $e');
    }
  }

  /// 获取算法性能统计
  Map<String, dynamic> getAlgorithmStats(List<EnhancedWordLearningRecord> records) {
    if (_currentService == null) {
      return {'error': '未初始化算法服务'};
    }
    
    final stats = _currentService!.getStatistics(records);
    stats['algorithmType'] = _currentConfig!.type.displayName;
    stats['configName'] = _currentConfig!.name;
    
    return stats;
  }

  /// 推荐算法
  AlgorithmType recommendAlgorithm(List<EnhancedWordLearningRecord> records) {
    if (records.isEmpty) {
      return AlgorithmType.adaptive; // 新用户推荐自适应
    }
    
    // 分析用户学习模式
    final learningPattern = _analyzeUserLearningPattern(records);
    
    // 基于学习模式推荐算法
    if (learningPattern.isConsistent && learningPattern.prefersChallenging) {
      return AlgorithmType.superMemo; // 适合系统性学习
    } else if (learningPattern.prefersStable) {
      return AlgorithmType.anki; // 适合稳定学习
    } else {
      return AlgorithmType.adaptive; // 适合大多数用户
    }
  }

  /// 分析用户学习模式
  UserLearningPattern _analyzeUserLearningPattern(List<EnhancedWordLearningRecord> records) {
    // 计算学习一致性
    final studyDays = records.map((r) => r.lastLearningTime.day).toSet().length;
    final totalDays = records.isNotEmpty 
        ? DateTime.now().difference(records.first.firstLearningTime).inDays + 1
        : 1;
    final consistency = studyDays / totalDays;
    
    // 计算挑战偏好
    final avgDifficulty = records.map((r) => r.difficulty.index).reduce((a, b) => a + b) / records.length;
    final challengingPreference = avgDifficulty / (WordDifficulty.values.length - 1);
    
    // 计算稳定性偏好 - 基于good和easy的比例
    final avgAccuracy = records.map((r) => (r.goodCount + r.easyCount) / math.max(1, r.learningCount.toDouble())).reduce((a, b) => a + b) / records.length;
    
    return UserLearningPattern(
      isConsistent: consistency > 0.7,
      prefersChallenging: challengingPreference > 0.6,
      prefersStable: avgAccuracy > 0.8,
      consistency: consistency,
      challengingPreference: challengingPreference,
      stabilityPreference: avgAccuracy,
    );
  }

  /// 加载配置
  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final configsJson = prefs.getString(_algorithmConfigsKey);
    
    if (configsJson != null) {
      try {
        final configsMap = jsonDecode(configsJson) as Map<String, dynamic>;
        for (final entry in configsMap.entries) {
          final type = AlgorithmType.values[int.parse(entry.key)];
          final config = AlgorithmConfig.fromJson(entry.value);
          _configs[type] = config;
        }
      } catch (e) {
        _initializeDefaultConfigs();
      }
    } else {
      _initializeDefaultConfigs();
    }
  }

  /// 初始化默认配置
  void _initializeDefaultConfigs() {
    _configs[AlgorithmType.superMemo] = SuperMemoConfig.balanced();
    _configs[AlgorithmType.anki] = AnkiConfig.balanced();
    _configs[AlgorithmType.adaptive] = const AdaptiveConfig();
  }

  /// 保存配置
  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final configsMap = <String, dynamic>{};
    
    for (final entry in _configs.entries) {
      configsMap[entry.key.index.toString()] = entry.value.toJson();
    }
    
    await prefs.setString(_algorithmConfigsKey, jsonEncode(configsMap));
  }

  /// 加载当前算法
  Future<void> _loadCurrentAlgorithm() async {
    final prefs = await SharedPreferences.getInstance();
    final currentAlgorithmIndex = prefs.getInt(_currentAlgorithmKey);
    
    if (currentAlgorithmIndex != null) {
      final type = AlgorithmType.values[currentAlgorithmIndex];
      if (_configs.containsKey(type)) {
        _currentConfig = _configs[type]!;
        _currentService = MultiAlgorithmService(config: _currentConfig!);
      }
    }
    
    // 如果没有设置当前算法，默认使用自适应
    if (_currentConfig == null) {
      await switchAlgorithm(AlgorithmType.adaptive);
    }
  }

  /// 保存当前算法
  Future<void> _saveCurrentAlgorithm() async {
    if (_currentConfig != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_currentAlgorithmKey, _currentConfig!.type.index);
    }
  }
}

/// 用户学习模式分析结果
class UserLearningPattern {
  final bool isConsistent;          // 是否一致
  final bool prefersChallenging;    // 是否偏好挑战
  final bool prefersStable;         // 是否偏好稳定
  final double consistency;         // 一致性分数
  final double challengingPreference; // 挑战偏好分数
  final double stabilityPreference;  // 稳定性偏好分数

  const UserLearningPattern({
    required this.isConsistent,
    required this.prefersChallenging,
    required this.prefersStable,
    required this.consistency,
    required this.challengingPreference,
    required this.stabilityPreference,
  });

  @override
  String toString() {
    return 'UserLearningPattern(consistency: $consistency, challenging: $challengingPreference, stability: $stabilityPreference)';
  }
}

/// 算法切换历史记录
class AlgorithmSwitchHistory {
  final DateTime switchTime;
  final AlgorithmType fromType;
  final AlgorithmType toType;
  final String reason;

  const AlgorithmSwitchHistory({
    required this.switchTime,
    required this.fromType,
    required this.toType,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'switchTime': switchTime.toIso8601String(),
      'fromType': fromType.index,
      'toType': toType.index,
      'reason': reason,
    };
  }

  factory AlgorithmSwitchHistory.fromJson(Map<String, dynamic> json) {
    return AlgorithmSwitchHistory(
      switchTime: DateTime.parse(json['switchTime']),
      fromType: AlgorithmType.values[json['fromType']],
      toType: AlgorithmType.values[json['toType']],
      reason: json['reason'],
    );
  }
} 