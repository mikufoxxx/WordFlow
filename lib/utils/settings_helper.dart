import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'english_word_api_service.dart';

/// 版本信息类
class VersionInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;

  const VersionInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final version = tagName.replaceFirst('v', '');

    // 构造代理下载链接
    // 格式: http://git.techox.cc/https://github.com/mikufoxxx/WordFlow/releases/download/v1.0.4/app-release.apk
    final downloadUrl = tagName.isNotEmpty
        ? 'http://git.techox.cc/https://github.com/mikufoxxx/WordFlow/releases/download/$tagName/app-release.apk'
        : '';

    return VersionInfo(
      version: version,
      downloadUrl: downloadUrl,
      releaseNotes: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 版本检查结果
class UpdateCheckResult {
  final bool hasUpdate;
  final VersionInfo? latestVersion;
  final String currentVersion;
  final String? error;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    required this.currentVersion,
    this.error,
  });

  /// 获取版本信息（为了兼容性）
  VersionInfo? get versionInfo => latestVersion;
}

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
  /// GitHub仓库信息
  static const String _githubRepo = 'mikufoxxx/WordFlow';
  static const String _updateCheckUrl =
      'https://api.github.com/repos/$_githubRepo/releases/latest';
  static const String _aiAutoParseEnabledKey = 'ai_auto_parse_enabled';

  /// 获取应用包信息
  static Future<PackageInfo> getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  /// 检查应用更新
  static Future<UpdateCheckResult> checkForUpdates(
      String currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse(_updateCheckUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> releaseData = json.decode(response.body);
        final latestVersionInfo = VersionInfo.fromJson(releaseData);

        final hasUpdate =
            _isNewerVersion(currentVersion, latestVersionInfo.version);

        return UpdateCheckResult(
          hasUpdate: hasUpdate,
          latestVersion: latestVersionInfo,
          currentVersion: currentVersion,
        );
      } else {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          error: '检查更新失败: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        error: '检查更新失败: ${e.toString()}',
      );
    }
  }

  /// 比较版本号
  static bool _isNewerVersion(String currentVersion, String latestVersion) {
    List<int> current = currentVersion.split('.').map(int.parse).toList();
    List<int> latest = latestVersion.split('.').map(int.parse).toList();

    // 补齐版本号长度
    while (current.length < latest.length) {
      current.add(0);
    }
    while (latest.length < current.length) {
      latest.add(0);
    }

    for (int i = 0; i < current.length; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }

  /// 格式化更新内容
  static String formatReleaseNotes(String rawNotes) {
    if (rawNotes.isEmpty) {
      return '• 版本更新\n• 性能优化\n• Bug修复';
    }

    // 提取实际的更新内容部分
    String actualNotes = _extractActualReleaseNotes(rawNotes);

    if (actualNotes.isEmpty) {
      return '• 版本更新\n• 性能优化\n• Bug修复';
    }

    // 保留Markdown格式，只做基本的清理
    String formatted = actualNotes.trim();

    // 如果内容太长，截取前1000个字符（增加长度以适应Markdown格式）
    if (formatted.length > 1000) {
      formatted = '${formatted.substring(0, 1000)}...';
    }

    return formatted;
  }

  /// 从完整的发布说明中提取实际的更新内容
  static String _extractActualReleaseNotes(String fullReleaseNotes) {
    // 查找"### 更新内容"和"### 安装说明"之间的内容
    final updateContentStart = fullReleaseNotes.indexOf('### 更新内容');
    final installInstructionsStart = fullReleaseNotes.indexOf('### 安装说明');

    if (updateContentStart != -1) {
      int endIndex;
      if (installInstructionsStart != -1 &&
          installInstructionsStart > updateContentStart) {
        endIndex = installInstructionsStart;
      } else {
        endIndex = fullReleaseNotes.length;
      }

      // 提取更新内容部分
      String updateContent = fullReleaseNotes
          .substring(updateContentStart + '### 更新内容'.length, endIndex)
          .trim();

      return updateContent;
    }

    // 如果没有找到标准格式，尝试其他可能的分隔符
    final lines = fullReleaseNotes.split('\n');
    final List<String> contentLines = [];
    bool inUpdateSection = false;

    for (String line in lines) {
      line = line.trim();

      // 跳过版本标题行
      if (line.startsWith('## WordFlow v') || line.startsWith('# WordFlow v')) {
        continue;
      }

      // 检测更新内容开始
      if (line.contains('更新内容') ||
          line.contains('What\'s New') ||
          line.contains('Changes')) {
        inUpdateSection = true;
        continue;
      }

      // 检测安装说明开始，结束更新内容提取
      if (line.contains('安装说明') ||
          line.contains('Installation') ||
          line.contains('Download')) {
        break;
      }

      // 如果在更新内容区域，收集非空行
      if (inUpdateSection && line.isNotEmpty) {
        contentLines.add(line);
      }
    }

    // 如果找到了更新内容，返回；否则返回原始内容的前几行
    if (contentLines.isNotEmpty) {
      return contentLines.join('\n');
    }

    // 最后的备选方案：返回原始内容的前几行（排除标题）
    final filteredLines = lines
        .where((line) =>
            line.trim().isNotEmpty &&
            !line.trim().startsWith('##') &&
            !line.trim().startsWith('#'))
        .take(10)
        .toList();

    return filteredLines.join('\n');
  }

  /// 提取更新内容的关键信息
  static Map<String, List<String>> extractUpdateCategories(
      String releaseNotes) {
    final Map<String, List<String>> categories = {
      '新增功能': <String>[],
      '改进优化': <String>[],
      'Bug修复': <String>[],
      '其他更新': <String>[],
    };

    // 首先提取实际的更新内容
    String actualNotes = _extractActualReleaseNotes(releaseNotes);
    if (actualNotes.isEmpty) {
      categories['其他更新']!.add('版本更新');
      categories['其他更新']!.add('性能优化');
      categories['其他更新']!.add('Bug修复');
      return categories;
    }

    final lines = actualNotes.split('\n');
    String currentCategory = '其他更新';

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // 检测分类标题
      if (line.contains('新增') ||
          line.contains('新功能') ||
          line.contains('Features')) {
        currentCategory = '新增功能';
        continue;
      } else if (line.contains('改进') ||
          line.contains('优化') ||
          line.contains('Improvements')) {
        currentCategory = '改进优化';
        continue;
      } else if (line.contains('修复') ||
          line.contains('Bug') ||
          line.contains('Fix')) {
        currentCategory = 'Bug修复';
        continue;
      }

      // 提取列表项
      if (line.startsWith('-') ||
          line.startsWith('•') ||
          line.startsWith('*')) {
        String item = line.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim();
        if (item.isNotEmpty) {
          categories[currentCategory]!.add(item);
        }
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        // 非标题行也加入当前分类
        categories[currentCategory]!.add(line);
      }
    }

    // 移除空分类
    categories.removeWhere((key, value) => value.isEmpty);

    // 如果所有分类都为空，添加默认内容
    if (categories.isEmpty) {
      categories['其他更新'] = ['版本更新', '性能优化', 'Bug修复'];
    }

    return categories;
  }

  /// 获取发音类型设置
  static Future<PronunciationType> getPronunciationType() async {
    final prefs = await SharedPreferences.getInstance();
    final pronunciationTypeStr = prefs.getString('pronunciation_type') ?? 'uk';
    return pronunciationTypeStr == 'us'
        ? PronunciationType.us
        : PronunciationType.uk;
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

  /// 获取智能同步设置
  static Future<bool> getSmartSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('smart_sync_enabled') ?? true;
  }

  /// 保存智能同步设置
  static Future<void> setSmartSyncEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_sync_enabled', value);
  }

  /// 获取 AI 自动解析导入设置
  static Future<bool> getAiAutoParseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_aiAutoParseEnabledKey) ?? true;
  }

  /// 保存 AI 自动解析导入设置
  static Future<void> setAiAutoParseEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiAutoParseEnabledKey, value);
  }
}
