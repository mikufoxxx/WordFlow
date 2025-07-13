import 'dart:math' as math;

/// 算法类型枚举
enum AlgorithmType {
  superMemo,      // SuperMemo算法
  anki,           // Anki算法
  adaptive,       // 智能自适应算法
}

/// 基础算法配置
abstract class AlgorithmConfig {
  final AlgorithmType type;
  final String name;
  final String description;
  final bool isEnabled;
  final Map<String, dynamic> parameters;

  const AlgorithmConfig({
    required this.type,
    required this.name,
    required this.description,
    this.isEnabled = true,
    this.parameters = const {},
  });

  /// 从JSON创建配置
  factory AlgorithmConfig.fromJson(Map<String, dynamic> json) {
    final type = AlgorithmType.values[json['type']];
    switch (type) {
      case AlgorithmType.superMemo:
        return SuperMemoConfig.fromJson(json);
      case AlgorithmType.anki:
        return AnkiConfig.fromJson(json);
      case AlgorithmType.adaptive:
        return AdaptiveConfig.fromJson(json);
    }
  }

  /// 转换为JSON
  Map<String, dynamic> toJson();

  /// 创建副本
  AlgorithmConfig copyWith({Map<String, dynamic>? newParameters});
}

/// SuperMemo算法配置
class SuperMemoConfig extends AlgorithmConfig {
  // 基础间隔设置
  final double initialInterval;      // 初始间隔（天）
  final double minInterval;          // 最小间隔（天）
  final double maxInterval;          // 最大间隔（天）
  
  // 难度系数设置
  final double initialEaseFactor;    // 初始难度系数
  final double minEaseFactor;        // 最小难度系数
  final double maxEaseFactor;        // 最大难度系数
  
  // 反馈调整倍数
  final double forgotPenalty;        // 忘记惩罚倍数
  final double hardAdjustment;       // 困难调整倍数
  final double easyBonus;            // 简单奖励倍数
  
  // 高级设置
  final double easeFactorChange;     // 难度系数变化率
  final double randomFuzz;           // 随机波动范围(0-1)
  final bool gradientAdjustment;     // 梯度调整开关
  final double difficultyModifier;   // 全局难度调整器

  const SuperMemoConfig({
    this.initialInterval = 1.0,
    this.minInterval = 1.0,
    this.maxInterval = 365.0,
    this.initialEaseFactor = 2.5,
    this.minEaseFactor = 1.3,
    this.maxEaseFactor = 5.0,
    this.forgotPenalty = 0.2,
    this.hardAdjustment = 1.2,
    this.easyBonus = 1.3,
    this.easeFactorChange = 0.15,
    this.randomFuzz = 0.1,
    this.gradientAdjustment = true,
    this.difficultyModifier = 1.0,
  }) : super(
          type: AlgorithmType.superMemo,
          name: 'SuperMemo (SM-2)',
          description: '科学记忆算法，基于遗忘曲线\n适合：系统学习，追求效率',
        );

  factory SuperMemoConfig.fromJson(Map<String, dynamic> json) {
    return SuperMemoConfig(
      initialInterval: (json['initialInterval'] ?? 1.0).toDouble(),
      minInterval: (json['minInterval'] ?? 1.0).toDouble(),
      maxInterval: (json['maxInterval'] ?? 365.0).toDouble(),
      initialEaseFactor: (json['initialEaseFactor'] ?? 2.5).toDouble(),
      minEaseFactor: (json['minEaseFactor'] ?? 1.3).toDouble(),
      maxEaseFactor: (json['maxEaseFactor'] ?? 5.0).toDouble(),
      forgotPenalty: (json['forgotPenalty'] ?? 0.2).toDouble(),
      hardAdjustment: (json['hardAdjustment'] ?? 1.2).toDouble(),
      easyBonus: (json['easyBonus'] ?? 1.3).toDouble(),
      easeFactorChange: (json['easeFactorChange'] ?? 0.15).toDouble(),
      randomFuzz: (json['randomFuzz'] ?? 0.1).toDouble(),
      gradientAdjustment: json['gradientAdjustment'] ?? true,
      difficultyModifier: (json['difficultyModifier'] ?? 1.0).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'initialInterval': initialInterval,
      'minInterval': minInterval,
      'maxInterval': maxInterval,
      'initialEaseFactor': initialEaseFactor,
      'minEaseFactor': minEaseFactor,
      'maxEaseFactor': maxEaseFactor,
      'forgotPenalty': forgotPenalty,
      'hardAdjustment': hardAdjustment,
      'easyBonus': easyBonus,
      'easeFactorChange': easeFactorChange,
      'randomFuzz': randomFuzz,
      'gradientAdjustment': gradientAdjustment,
      'difficultyModifier': difficultyModifier,
    };
  }

  @override
  SuperMemoConfig copyWith({Map<String, dynamic>? newParameters}) {
    if (newParameters == null) return this;
    
    return SuperMemoConfig(
      initialInterval: (newParameters['initialInterval'] ?? initialInterval).toDouble(),
      minInterval: (newParameters['minInterval'] ?? minInterval).toDouble(),
      maxInterval: (newParameters['maxInterval'] ?? maxInterval).toDouble(),
      initialEaseFactor: (newParameters['initialEaseFactor'] ?? initialEaseFactor).toDouble(),
      minEaseFactor: (newParameters['minEaseFactor'] ?? minEaseFactor).toDouble(),
      maxEaseFactor: (newParameters['maxEaseFactor'] ?? maxEaseFactor).toDouble(),
      forgotPenalty: (newParameters['forgotPenalty'] ?? forgotPenalty).toDouble(),
      hardAdjustment: (newParameters['hardAdjustment'] ?? hardAdjustment).toDouble(),
      easyBonus: (newParameters['easyBonus'] ?? easyBonus).toDouble(),
      easeFactorChange: (newParameters['easeFactorChange'] ?? easeFactorChange).toDouble(),
      randomFuzz: (newParameters['randomFuzz'] ?? randomFuzz).toDouble(),
      gradientAdjustment: newParameters['gradientAdjustment'] ?? gradientAdjustment,
      difficultyModifier: (newParameters['difficultyModifier'] ?? difficultyModifier).toDouble(),
    );
  }

  /// 预设配置
  static SuperMemoConfig conservative() {
    return const SuperMemoConfig(
      easyBonus: 1.15,
      forgotPenalty: 0.3,
      difficultyModifier: 0.8,
    );
  }

  static SuperMemoConfig balanced() {
    return const SuperMemoConfig();
  }

  static SuperMemoConfig aggressive() {
    return const SuperMemoConfig(
      easyBonus: 1.5,
      forgotPenalty: 0.1,
      difficultyModifier: 1.2,
    );
  }
}

/// Anki算法配置
class AnkiConfig extends AlgorithmConfig {
  // 新卡片设置
  final List<int> learningSteps;     // 学习步骤（分钟）
  final int graduatingInterval;      // 毕业间隔（天）
  final int easyInterval;            // 简单间隔（天）
  
  // 复习卡片设置
  final double easyBonus;            // 简单奖励倍数
  final double intervalModifier;     // 间隔修正百分比
  final int maxInterval;             // 最大间隔（天）
  
  // 失败处理
  final List<int> relearningSteps;   // 重新学习步骤（分钟）
  final int minInterval;             // 最小间隔（天）
  final int leechThreshold;          // 水蛭阈值
  
  // 高级设置
  final bool hardAdjustment;         // 困难调整开关
  final double fuzzFactor;           // 模糊化因子
  final String priorityMode;         // 优先级模式

  const AnkiConfig({
    this.learningSteps = const [1, 10],
    this.graduatingInterval = 1,
    this.easyInterval = 4,
    this.easyBonus = 1.3,
    this.intervalModifier = 1.0,
    this.maxInterval = 36500,
    this.relearningSteps = const [10],
    this.minInterval = 1,
    this.leechThreshold = 8,
    this.hardAdjustment = true,
    this.fuzzFactor = 0.05,
    this.priorityMode = 'difficulty',
  }) : super(
          type: AlgorithmType.anki,
          name: 'Anki算法',
          description: '稳定记忆算法，注重长期保持\n适合：稳定学习，不易遗忘',
        );

  factory AnkiConfig.fromJson(Map<String, dynamic> json) {
    return AnkiConfig(
      learningSteps: List<int>.from(json['learningSteps'] ?? [1, 10]),
      graduatingInterval: json['graduatingInterval'] ?? 1,
      easyInterval: json['easyInterval'] ?? 4,
      easyBonus: (json['easyBonus'] ?? 1.3).toDouble(),
      intervalModifier: (json['intervalModifier'] ?? 1.0).toDouble(),
      maxInterval: json['maxInterval'] ?? 36500,
      relearningSteps: List<int>.from(json['relearningSteps'] ?? [10]),
      minInterval: json['minInterval'] ?? 1,
      leechThreshold: json['leechThreshold'] ?? 8,
      hardAdjustment: json['hardAdjustment'] ?? true,
      fuzzFactor: (json['fuzzFactor'] ?? 0.05).toDouble(),
      priorityMode: json['priorityMode'] ?? 'difficulty',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'learningSteps': learningSteps,
      'graduatingInterval': graduatingInterval,
      'easyInterval': easyInterval,
      'easyBonus': easyBonus,
      'intervalModifier': intervalModifier,
      'maxInterval': maxInterval,
      'relearningSteps': relearningSteps,
      'minInterval': minInterval,
      'leechThreshold': leechThreshold,
      'hardAdjustment': hardAdjustment,
      'fuzzFactor': fuzzFactor,
      'priorityMode': priorityMode,
    };
  }

  @override
  AnkiConfig copyWith({Map<String, dynamic>? newParameters}) {
    if (newParameters == null) return this;
    
    return AnkiConfig(
      learningSteps: List<int>.from(newParameters['learningSteps'] ?? learningSteps),
      graduatingInterval: newParameters['graduatingInterval'] ?? graduatingInterval,
      easyInterval: newParameters['easyInterval'] ?? easyInterval,
      easyBonus: (newParameters['easyBonus'] ?? easyBonus).toDouble(),
      intervalModifier: (newParameters['intervalModifier'] ?? intervalModifier).toDouble(),
      maxInterval: newParameters['maxInterval'] ?? maxInterval,
      relearningSteps: List<int>.from(newParameters['relearningSteps'] ?? relearningSteps),
      minInterval: newParameters['minInterval'] ?? minInterval,
      leechThreshold: newParameters['leechThreshold'] ?? leechThreshold,
      hardAdjustment: newParameters['hardAdjustment'] ?? hardAdjustment,
      fuzzFactor: (newParameters['fuzzFactor'] ?? fuzzFactor).toDouble(),
      priorityMode: newParameters['priorityMode'] ?? priorityMode,
    );
  }

  /// 预设配置
  static AnkiConfig conservative() {
    return const AnkiConfig(
      learningSteps: [1, 10, 30],
      graduatingInterval: 2,
      easyInterval: 7,
      intervalModifier: 0.8,
    );
  }

  static AnkiConfig balanced() {
    return const AnkiConfig();
  }

  static AnkiConfig aggressive() {
    return const AnkiConfig(
      learningSteps: [1, 5],
      graduatingInterval: 1,
      easyInterval: 3,
      intervalModifier: 1.2,
    );
  }
}

/// 智能自适应算法配置
class AdaptiveConfig extends AlgorithmConfig {
  // 自适应设置
  final bool enableAIOptimization;    // 启用AI优化
  final bool enableMLOptimization;    // 启用机器学习优化
  final String adaptationMode;        // 适应模式
  final double adaptationSpeed;       // 适应速度
  
  // 学习能力分析
  final double learningAbility;       // 学习能力评估
  final double memoryRetention;       // 记忆保持评估
  final double studyConsistency;      // 学习一致性
  final String forgettingPattern;     // 遗忘模式
  
  // 优化策略
  final double easyWordMultiplier;    // 简单词汇倍数
  final double hardWordMultiplier;    // 困难词汇倍数
  final double newWordFrequency;      // 新词推送频率
  final double reviewDensity;         // 复习密度
  
  // 实时调整
  final bool realTimeAdjustment;      // 实时调整开关
  final int analysisWindowDays;       // 分析时间窗口
  final double adjustmentSensitivity; // 调整敏感度
  
  // 个性化设置
  final Map<String, double> personalFactors; // 个性化因子

  const AdaptiveConfig({
    this.enableAIOptimization = false,
    this.enableMLOptimization = true,
    this.adaptationMode = 'balanced',
    this.adaptationSpeed = 0.5,
    this.learningAbility = 0.68,
    this.memoryRetention = 0.82,
    this.studyConsistency = 0.75,
    this.forgettingPattern = 'standard',
    this.easyWordMultiplier = 2.1,
    this.hardWordMultiplier = 0.8,
    this.newWordFrequency = 0.5,
    this.reviewDensity = 0.5,
    this.realTimeAdjustment = true,
    this.analysisWindowDays = 7,
    this.adjustmentSensitivity = 0.3,
    this.personalFactors = const {},
  }) : super(
          type: AlgorithmType.adaptive,
          name: '智能自适应',
          description: 'AI优化算法，自动调整参数\n适合：新手用户，省心省力',
        );

  factory AdaptiveConfig.fromJson(Map<String, dynamic> json) {
    return AdaptiveConfig(
      enableAIOptimization: json['enableAIOptimization'] ?? false,
      enableMLOptimization: json['enableMLOptimization'] ?? true,
      adaptationMode: json['adaptationMode'] ?? 'balanced',
      adaptationSpeed: (json['adaptationSpeed'] ?? 0.5).toDouble(),
      learningAbility: (json['learningAbility'] ?? 0.68).toDouble(),
      memoryRetention: (json['memoryRetention'] ?? 0.82).toDouble(),
      studyConsistency: (json['studyConsistency'] ?? 0.75).toDouble(),
      forgettingPattern: json['forgettingPattern'] ?? 'standard',
      easyWordMultiplier: (json['easyWordMultiplier'] ?? 2.1).toDouble(),
      hardWordMultiplier: (json['hardWordMultiplier'] ?? 0.8).toDouble(),
      newWordFrequency: (json['newWordFrequency'] ?? 0.5).toDouble(),
      reviewDensity: (json['reviewDensity'] ?? 0.5).toDouble(),
      realTimeAdjustment: json['realTimeAdjustment'] ?? true,
      analysisWindowDays: json['analysisWindowDays'] ?? 7,
      adjustmentSensitivity: (json['adjustmentSensitivity'] ?? 0.3).toDouble(),
      personalFactors: Map<String, double>.from(json['personalFactors'] ?? {}),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'enableAIOptimization': enableAIOptimization,
      'enableMLOptimization': enableMLOptimization,
      'adaptationMode': adaptationMode,
      'adaptationSpeed': adaptationSpeed,
      'learningAbility': learningAbility,
      'memoryRetention': memoryRetention,
      'studyConsistency': studyConsistency,
      'forgettingPattern': forgettingPattern,
      'easyWordMultiplier': easyWordMultiplier,
      'hardWordMultiplier': hardWordMultiplier,
      'newWordFrequency': newWordFrequency,
      'reviewDensity': reviewDensity,
      'realTimeAdjustment': realTimeAdjustment,
      'analysisWindowDays': analysisWindowDays,
      'adjustmentSensitivity': adjustmentSensitivity,
      'personalFactors': personalFactors,
    };
  }

  @override
  AdaptiveConfig copyWith({Map<String, dynamic>? newParameters}) {
    if (newParameters == null) return this;
    
    return AdaptiveConfig(
      enableAIOptimization: newParameters['enableAIOptimization'] ?? enableAIOptimization,
      enableMLOptimization: newParameters['enableMLOptimization'] ?? enableMLOptimization,
      adaptationMode: newParameters['adaptationMode'] ?? adaptationMode,
      adaptationSpeed: (newParameters['adaptationSpeed'] ?? adaptationSpeed).toDouble(),
      learningAbility: (newParameters['learningAbility'] ?? learningAbility).toDouble(),
      memoryRetention: (newParameters['memoryRetention'] ?? memoryRetention).toDouble(),
      studyConsistency: (newParameters['studyConsistency'] ?? studyConsistency).toDouble(),
      forgettingPattern: newParameters['forgettingPattern'] ?? forgettingPattern,
      easyWordMultiplier: (newParameters['easyWordMultiplier'] ?? easyWordMultiplier).toDouble(),
      hardWordMultiplier: (newParameters['hardWordMultiplier'] ?? hardWordMultiplier).toDouble(),
      newWordFrequency: (newParameters['newWordFrequency'] ?? newWordFrequency).toDouble(),
      reviewDensity: (newParameters['reviewDensity'] ?? reviewDensity).toDouble(),
      realTimeAdjustment: newParameters['realTimeAdjustment'] ?? realTimeAdjustment,
      analysisWindowDays: newParameters['analysisWindowDays'] ?? analysisWindowDays,
      adjustmentSensitivity: (newParameters['adjustmentSensitivity'] ?? adjustmentSensitivity).toDouble(),
      personalFactors: Map<String, double>.from(newParameters['personalFactors'] ?? personalFactors),
    );
  }

  /// 更新个性化因子
  AdaptiveConfig updatePersonalFactor(String key, double value) {
    final newFactors = Map<String, double>.from(personalFactors);
    newFactors[key] = value;
    return copyWith(newParameters: {'personalFactors': newFactors});
  }

  /// 重置学习模式
  AdaptiveConfig resetLearningMode() {
    return const AdaptiveConfig();
  }
}

/// 算法类型扩展
extension AlgorithmTypeExtension on AlgorithmType {
  String get displayName {
    switch (this) {
      case AlgorithmType.superMemo:
        return 'SuperMemo (SM-2)';
      case AlgorithmType.anki:
        return 'Anki算法';
      case AlgorithmType.adaptive:
        return '智能自适应';
    }
  }

  String get description {
    switch (this) {
      case AlgorithmType.superMemo:
        return '科学记忆算法，基于遗忘曲线\n适合：系统学习，追求效率';
      case AlgorithmType.anki:
        return '稳定记忆算法，注重长期保持\n适合：稳定学习，不易遗忘';
      case AlgorithmType.adaptive:
        return 'AI优化算法，自动调整参数\n适合：新手用户，省心省力';
    }
  }

  /// 获取默认配置
  AlgorithmConfig get defaultConfig {
    switch (this) {
      case AlgorithmType.superMemo:
        return SuperMemoConfig.balanced();
      case AlgorithmType.anki:
        return AnkiConfig.balanced();
      case AlgorithmType.adaptive:
        return const AdaptiveConfig();
    }
  }
}

/// 参数验证结果
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  static ValidationResult valid() {
    return const ValidationResult(isValid: true);
  }

  static ValidationResult invalid(List<String> errors, {List<String> warnings = const []}) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// 参数验证器
class ParameterValidator {
  /// 验证SuperMemo配置
  static ValidationResult validateSuperMemo(SuperMemoConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // 检查基础间隔
    if (config.initialInterval < 0.1 || config.initialInterval > 30) {
      errors.add('初始间隔应在0.1-30天之间');
    }
    if (config.minInterval < 0.1 || config.minInterval > config.maxInterval) {
      errors.add('最小间隔应在0.1天以上且不超过最大间隔');
    }
    if (config.maxInterval < 1 || config.maxInterval > 36500) {
      errors.add('最大间隔应在1-36500天之间');
    }

    // 检查难度系数
    if (config.initialEaseFactor < 1.0 || config.initialEaseFactor > 10.0) {
      errors.add('初始难度系数应在1.0-10.0之间');
    }
    if (config.minEaseFactor < 1.0 || config.minEaseFactor > config.maxEaseFactor) {
      errors.add('最小难度系数应在1.0以上且不超过最大难度系数');
    }

    // 检查调整倍数
    if (config.forgotPenalty < 0.01 || config.forgotPenalty > 1.0) {
      errors.add('忘记惩罚倍数应在0.01-1.0之间');
    }
    if (config.hardAdjustment < 0.1 || config.hardAdjustment > 3.0) {
      errors.add('困难调整倍数应在0.1-3.0之间');
    }

    return errors.isEmpty 
        ? ValidationResult.valid() 
        : ValidationResult.invalid(errors, warnings: warnings);
  }

  /// 验证Anki配置
  static ValidationResult validateAnki(AnkiConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // 检查学习步骤
    if (config.learningSteps.isEmpty) {
      errors.add('学习步骤不能为空');
    }
    if (config.learningSteps.any((step) => step < 1 || step > 10080)) {
      errors.add('学习步骤应在1-10080分钟之间');
    }

    // 检查间隔设置
    if (config.graduatingInterval < 1 || config.graduatingInterval > 100) {
      errors.add('毕业间隔应在1-100天之间');
    }
    if (config.easyInterval < 1 || config.easyInterval > 365) {
      errors.add('简单间隔应在1-365天之间');
    }

    return errors.isEmpty 
        ? ValidationResult.valid() 
        : ValidationResult.invalid(errors, warnings: warnings);
  }

  /// 验证自适应配置
  static ValidationResult validateAdaptive(AdaptiveConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // 检查评估数值
    if (config.learningAbility < 0.0 || config.learningAbility > 1.0) {
      errors.add('学习能力评估应在0.0-1.0之间');
    }
    if (config.memoryRetention < 0.0 || config.memoryRetention > 1.0) {
      errors.add('记忆保持评估应在0.0-1.0之间');
    }

    // 检查调整参数
    if (config.adaptationSpeed < 0.1 || config.adaptationSpeed > 2.0) {
      errors.add('适应速度应在0.1-2.0之间');
    }
    if (config.adjustmentSensitivity < 0.1 || config.adjustmentSensitivity > 1.0) {
      errors.add('调整敏感度应在0.1-1.0之间');
    }

    return errors.isEmpty 
        ? ValidationResult.valid() 
        : ValidationResult.invalid(errors, warnings: warnings);
  }
} 