import 'package:shared_preferences/shared_preferences.dart';
import 'english_word_api_service.dart';

/// 学习模式枚举
enum LearningMode {
  /// 快速记忆模式 - 不显示造句，点击认识就进入下一个单词
  quickMemory('quick_memory', '快速记忆'),
  /// 深入学习模式 - 有造句和AI评估
  deepLearning('deep_learning', '深入学习');

  const LearningMode(this.code, this.displayName);
  
  /// 模式代码
  final String code;
  /// 显示名称
  final String displayName;
  
  /// 根据代码获取对应的学习模式
  static LearningMode fromCode(String code) {
    switch (code) {
      case 'quick_memory':
        return LearningMode.quickMemory;
      case 'deep_learning':
        return LearningMode.deepLearning;
      default:
        return LearningMode.quickMemory; // 默认为快速记忆模式
    }
  }
}

/// 设置帮助类
/// 提供便捷的方法来获取和保存应用设置
class SettingsHelper {
  /// 获取发音类型设置
  static Future<PronunciationType> getPronunciationType() async {
    final prefs = await SharedPreferences.getInstance();
    final pronunciationTypeStr = prefs.getString('pronunciation_type') ?? 'uk';
    return pronunciationTypeStr == 'us' ? PronunciationType.us : PronunciationType.uk;
  }
  
  /// 保存发音类型设置
  static Future<void> setPronunciationType(PronunciationType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pronunciation_type', type.code);
  }
  
  /// 获取自动播放发音设置
  static Future<bool> getAutoPlayPronunciation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_play_pronunciation') ?? true;
  }
  
  /// 保存自动播放发音设置
  static Future<void> setAutoPlayPronunciation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play_pronunciation', value);
  }
  
  /// 获取显示单词动画设置
  static Future<bool> getShowWordAnimation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('show_word_animation') ?? true;
  }
  
  /// 保存显示单词动画设置
  static Future<void> setShowWordAnimation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_word_animation', value);
  }
  
  /// 获取学习模式设置
  static Future<LearningMode> getLearningMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeCode = prefs.getString('learning_mode') ?? 'quick_memory';
    return LearningMode.fromCode(modeCode);
  }
  
  /// 保存学习模式设置
  static Future<void> setLearningMode(LearningMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('learning_mode', mode.code);
  }
} 