import 'package:shared_preferences/shared_preferences.dart';
import 'english_word_api_service.dart';

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
} 