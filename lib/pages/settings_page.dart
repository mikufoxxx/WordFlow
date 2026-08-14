// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../utils/english_word_api_service.dart';
import '../utils/llm_api_service.dart';
import '../utils/settings_helper.dart';
import '../utils/learning_data_service.dart';
import '../utils/cache_service.dart';
import '../utils/file_helper.dart';
import '../utils/sound_service.dart';
import '../widgets/acrylic_app_bar.dart';
import '../utils/performance_optimizer.dart';
import '../utils/auto_update_service.dart';
import '../utils/render_compatibility_helper.dart';
import '../utils/compatible_page_route.dart';
import '../widgets/ai_provider_settings_card.dart';
import '../main.dart';

/// 导入模式枚举
enum ImportMode {
  update, // 数据更新：只更新学习进度更好的记录
  overwrite, // 全部覆盖：清空现有数据，完全替换
}

/// 设置页面 - 用于配置应用的基本设置
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 设置项状态
  bool _autoPlayPronunciation = true;
  bool _enableDarkMode = false;
  bool _smartSyncEnabled = true; // 智能同步开关状态
  PronunciationType _pronunciationType = PronunciationType.uk;
  LearningMode? _learningMode; // 改为可空类型，避免默认值闪烁
  int _dailyLearningGoal = LearningDataService.defaultDailyLearningGoal;

  // 版本信息
  String _appVersion = '加载中...';
// 当前应用版本

  // AI 接口设置
  bool _isAiConfigValid = false;
  bool _aiAutoParseEnabled = true;

  // 学习算法设置

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkBackgroundColor
              : AppTheme.backgroundColor,
          appBar: AcrylicAppBar(
            title: '设置',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                SoundService.playTapOffSound();
                Navigator.pop(context);
              },
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveHelper.getMaxContentWidth(context),
              ),
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: ResponsiveHelper.getResponsivePadding(context),
                children: [
                  // 学习设置部分
                  _buildSectionHeader('学习设置'),
                  _buildSettingsCard([
                    _buildSwitchTile(
                      title: '自动播放发音',
                      subtitle: '显示单词时自动播放发音',
                      value: _autoPlayPronunciation,
                      onChanged: (value) {
                        setState(() {
                          _autoPlayPronunciation = value;
                        });
                        _saveSettings();
                      },
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: '每日学习目标',
                      subtitle: '每天学习 $_dailyLearningGoal 个单词',
                      onTap: _showDailyLearningGoalDialog,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 学习模式设置部分
                  _buildSectionHeader('学习模式'),
                  if (_learningMode != null)
                    _buildSettingsCard([
                      _buildRadioListTile<LearningMode>(
                        title: '快速记忆',
                        subtitle: '不显示造句，点击认识就进入下一个单词',
                        value: LearningMode.quickMemory,
                        groupValue: _learningMode!,
                        onChanged: (LearningMode? value) {
                          if (value != null) {
                            setState(() {
                              _learningMode = value;
                            });
                            _saveSettings();
                          }
                        },
                      ),
                      _buildRadioListTile<LearningMode>(
                        title: '深入学习',
                        subtitle: _isAiConfigValid
                            ? '包含造句练习和 AI 评估功能'
                            : '需要先完成 AI 接口配置才能使用此功能',
                        value: LearningMode.deepLearning,
                        groupValue: _learningMode!,
                        onChanged: _isAiConfigValid
                            ? (LearningMode? value) {
                                if (value != null) {
                                  setState(() {
                                    _learningMode = value;
                                  });
                                  _saveSettings();
                                }
                              }
                            : (LearningMode? value) {
                                // API Key无效时，显示提示但不执行任何操作
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_outlined,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: RenderCompatibilityHelper
                                              .createCompatibleText(
                                            '请先完成有效的 AI 接口配置',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppTheme.coolGray600
                                            : AppTheme.coolGray300,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                      ),
                    ])
                  else
                    _buildSettingsCard([
                      ListTile(
                        leading: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        title: RenderCompatibilityHelper.createCompatibleText(
                            '正在加载学习模式设置...'),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ]),

                  const SizedBox(height: 16),

                  // 发音设置部分
                  _buildSectionHeader('发音设置'),
                  _buildSettingsCard([
                    _buildRadioListTile<PronunciationType>(
                      title: '英音',
                      subtitle: '使用英式发音和音标',
                      value: PronunciationType.uk,
                      groupValue: _pronunciationType,
                      onChanged: (PronunciationType? value) {
                        setState(() {
                          _pronunciationType = value!;
                        });
                        _saveSettings();
                      },
                    ),
                    _buildRadioListTile<PronunciationType>(
                      title: '美音',
                      subtitle: '使用美式发音和音标',
                      value: PronunciationType.us,
                      groupValue: _pronunciationType,
                      onChanged: (PronunciationType? value) {
                        setState(() {
                          _pronunciationType = value!;
                        });
                        _saveSettings();
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // AI设置部分
                  _buildSectionHeader('AI设置'),
                  _buildSettingsCard([
                    _buildApiKeyTile(),
                    _buildSwitchTile(
                      title: '导入时自动使用 AI 解析',
                      subtitle: _isAiConfigValid
                          ? (_aiAutoParseEnabled
                              ? '遇到复杂格式时自动调用 AI 适配，可能产生 token 消耗'
                              : '关闭后仅按标准格式本地解析，不会自动触发 AI 适配')
                          : '需要先完成 AI 接口配置；开启后在导入复杂格式时可能产生 token 消耗',
                      value: _aiAutoParseEnabled,
                      onChanged: (value) {
                        setState(() {
                          _aiAutoParseEnabled = value;
                        });
                        _saveSettings();
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 界面设置部分
                  _buildSectionHeader('界面设置'),
                  _buildSettingsCard([
                    _buildSwitchTile(
                      title: '深色模式',
                      subtitle: '切换到深色主题',
                      value: _enableDarkMode,
                      onChanged: (value) {
                        setState(() {
                          _enableDarkMode = value;
                        });
                        _saveSettings();
                        // 调用主题切换函数
                        final themeProvider = ThemeProvider.of(context);
                        if (themeProvider != null) {
                          themeProvider.toggleTheme();
                        }
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 学习算法设置部分
                  _buildSectionHeader('学习算法'),
                  _buildSettingsCard([
                    _buildCompactListTile(
                      leading: const Icon(Icons.psychology_outlined),
                      title: '高级算法设置',
                      subtitle: '配置SuperMemo、Anki、自适应算法参数',
                      onTap: _openAlgorithmSettings,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 数据管理部分
                  _buildSectionHeader('数据管理'),
                  _buildSettingsCard([
                    _buildSwitchTile(
                      title: '智能同步',
                      subtitle: '切换词书时自动继承学习记录',
                      value: _smartSyncEnabled,
                      onChanged: (value) {
                        setState(() {
                          _smartSyncEnabled = value;
                        });
                        _saveSettings();

                        // 显示状态变化提示
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  value ? Icons.sync : Icons.sync_disabled,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RenderCompatibilityHelper
                                      .createCompatibleText(
                                    value ? '智能同步已开启' : '智能同步已关闭',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.darkCardColor
                                    : AppTheme.cardColor,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: '导出学习数据',
                      subtitle: '选择目录导出当前词书的学习记录',
                      onTap: _exportLearningData,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.file_upload_outlined),
                      title: '导入学习数据',
                      subtitle: '选择CSV文件导入学习记录',
                      onTap: _importLearningData,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.analytics_outlined),
                      title: '增强学习分析',
                      subtitle: '详细的学习历史、统计图表、算法效果分析',
                      onTap: _openWordReviewPage,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.refresh_outlined),
                      title: '重置学习进度',
                      subtitle: '清除所有学习记录',
                      onTap: _showResetDialog,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 关于部分
                  _buildSectionHeader('关于'),
                  _buildSettingsCard([
                    _buildCompactListTile(
                      leading: const Icon(Icons.system_update_outlined),
                      title: _appVersion,
                      subtitle: '点击检查更新',
                      onTap: _checkForUpdates,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.feedback_outlined),
                      title: '意见反馈',
                      subtitle: '请前往 Github 提 issue',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  Icons.catching_pokemon_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '这是一个彩蛋...',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.coolGray600
                                    : AppTheme.coolGray300,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建节标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6, top: 6),
      child: OptimizedText(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.getPrimaryTitleColor(context,
                  lightColor: AppTheme.primaryTextColor),
            ),
      ),
    );
  }

  /// 构建设置卡片
  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkCardColor
          : AppTheme.cardColor,
      elevation: 0, // 移除默认阴影，使用自定义阴影
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.coolGray200.withOpacity(0.25),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  /// 构建紧凑的列表项
  Widget _buildCompactListTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkPrimaryTextColor
              : AppTheme.darkGray,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.mediumGray
              : AppTheme.coolGray500,
        ),
      ),
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  /// 构建开关设置项
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: OptimizedText(
        title,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkPrimaryTextColor
              : AppTheme.darkGray,
        ),
      ),
      subtitle: OptimizedText(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.mediumGray
              : AppTheme.coolGray500,
        ),
      ),
      value: value,
      onChanged: (bool newValue) {
        if (newValue) {
          SoundService.playSwitchOnSound();
        } else {
          SoundService.playSwitchOffSound();
        }
        onChanged(newValue);
      },
      inactiveThumbColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkPrimaryGray
          : AppTheme.darkAccentGreen,
      inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSecondaryTextColor
          : AppTheme.darkPrimaryTextColor,
      activeTrackColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSecondaryTextColor
          : AppTheme.darkAccentGreen,
      activeColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.secondaryTextColor
          : AppTheme.secondaryTextColor,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  /// 构建单选按钮设置项
  Widget _buildRadioListTile<T>({
    required String title,
    required String subtitle,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return RadioListTile<T>(
      title: OptimizedText(
        title,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkPrimaryTextColor
              : AppTheme.darkGray,
        ),
      ),
      subtitle: OptimizedText(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.mediumGray
              : AppTheme.coolGray500,
        ),
      ),
      value: value,
      groupValue: groupValue,
      onChanged: (T? newValue) {
        if (newValue != null) {
          SoundService.playChooseButtonSound();
        }
        onChanged(newValue);
      },
      activeColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkPrimaryGray
          : AppTheme.primaryGray,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  /// 构建 AI 接口设置项
  Widget _buildApiKeyTile() {
    return AiProviderSettingsCard(
      key: const ValueKey('ai_provider_settings_card'),
      onAvailabilityChanged: (isAvailable) {
        if (!mounted) {
          return;
        }

        final shouldFallbackToQuickMode =
            !isAvailable && _learningMode == LearningMode.deepLearning;

        setState(() {
          _isAiConfigValid = isAvailable;
          if (shouldFallbackToQuickMode) {
            _learningMode = LearningMode.quickMemory;
          }
        });

        _saveSettings();
      },
    );
  }

  Future<void> _showDailyLearningGoalDialog() async {
    final controller = TextEditingController(text: '$_dailyLearningGoal');
    String? validationMessage;

    final selectedGoal = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('设置每日学习目标'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '每天学习的单词数量',
                  helperText:
                      '可设置 ${LearningDataService.minDailyLearningGoal}–${LearningDataService.maxDailyLearningGoal} 个单词',
                  errorText: validationMessage,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final goal = int.tryParse(controller.text.trim());
                    if (goal == null ||
                        goal < LearningDataService.minDailyLearningGoal ||
                        goal > LearningDataService.maxDailyLearningGoal) {
                      setDialogState(() {
                        validationMessage =
                            '请输入 ${LearningDataService.minDailyLearningGoal}–${LearningDataService.maxDailyLearningGoal} 之间的数字';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(goal);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (selectedGoal == null) return;

    await LearningDataService.instance.setDailyLearningGoal(selectedGoal);
    if (!mounted) return;

    setState(() {
      _dailyLearningGoal = selectedGoal;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('每日学习目标已设置为 $selectedGoal 个单词'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 加载设置
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUsableAiConfig = await LlmApiService.hasUsableConfig();
    final learningMode = await SettingsHelper.getLearningMode();
    final aiAutoParseEnabled = await SettingsHelper.getAiAutoParseEnabled();
    final dailyLearningGoal =
        await LearningDataService.instance.getDailyLearningGoal();

    if (!mounted) {
      return;
    }

    LearningMode finalLearningMode = learningMode;
    if (!hasUsableAiConfig && learningMode == LearningMode.deepLearning) {
      finalLearningMode = LearningMode.quickMemory;
      await SettingsHelper.setLearningMode(finalLearningMode);
    }

    setState(() {
      _autoPlayPronunciation = prefs.getBool('auto_play_pronunciation') ?? true;
      _enableDarkMode = prefs.getBool('enable_dark_mode') ?? false;
      _smartSyncEnabled = prefs.getBool('smart_sync_enabled') ?? true;
      final pronunciationTypeStr =
          prefs.getString('pronunciation_type') ?? 'uk';
      _pronunciationType = pronunciationTypeStr == 'us'
          ? PronunciationType.us
          : PronunciationType.uk;
      _learningMode = finalLearningMode;
      _isAiConfigValid = hasUsableAiConfig;
      _aiAutoParseEnabled = aiAutoParseEnabled;
      _dailyLearningGoal = dailyLearningGoal;
    });

    if (!hasUsableAiConfig && learningMode == LearningMode.deepLearning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '检测到无效的 AI 接口配置，已自动切换到快速学习模式',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 保存设置
  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play_pronunciation', _autoPlayPronunciation);
    await prefs.setBool('enable_dark_mode', _enableDarkMode);
    await prefs.setBool('smart_sync_enabled', _smartSyncEnabled);
    await prefs.setString('pronunciation_type', _pronunciationType.code);
    await SettingsHelper.setAiAutoParseEnabled(_aiAutoParseEnabled);

    if (_learningMode != null) {
      if (!_isAiConfigValid && _learningMode == LearningMode.deepLearning) {
        setState(() {
          _learningMode = LearningMode.quickMemory;
        });
        await SettingsHelper.setLearningMode(LearningMode.quickMemory);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI 接口配置无效，无法使用深入学习模式',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await SettingsHelper.setLearningMode(_learningMode!);
      }
    }
  }

  /// 显示重置对话框
  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCardColor
            : AppTheme.cardColor,
        title: const Text('重置学习进度'),
        content: const Text('确定要清除所有学习记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getSecondaryTextColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetProgress();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkAccentRed
                  : AppTheme.accentRed,
              foregroundColor: Colors.white,
              elevation: 0.5,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 重置学习进度
  void _resetProgress() async {
    try {
      // 使用新的学习数据服务清除所有学习数据
      await LearningDataService.instance.clearLearningData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.refresh_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '学习进度已重置',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '重置失败: ${e.toString()}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 导出学习数据
  void _exportLearningData() async {
    try {
      // 直接选择导出目录
      final selectedDirectory = await FileHelper.selectExportDirectory();
      if (selectedDirectory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '未选择导出位置',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // 显示导出中的提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在导出数据...'),
            ],
          ),
        ),
      );

      // 获取公共单词本的CSV数据（传入null表示导出全局记录）
      final csvData = await LearningDataService.instance.getLearningDataCsv();

      // 生成文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'WordFlow_公共单词本_$timestamp.csv';

      // 保存文件到选择的目录
      final filePath =
          await FileHelper.saveFile(selectedDirectory, fileName, csvData);

      Navigator.of(context).pop(); // 关闭加载对话框

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          action: SnackBarAction(
            label: '复制路径',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: filePath));
            },
          ),
          content: Row(
            children: [
              Icon(
                Icons.catching_pokemon_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '公共单词本数据已导出到:\n$filePath',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '导出失败: ${e.toString()}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 导入学习数据
  void _importLearningData() async {
    try {
      // 直接选择CSV文件
      final selectedFile = await FileHelper.selectImportFile();
      if (selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '未选择文件',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // 显示导入中的提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在读取文件...'),
            ],
          ),
        ),
      );

      // 读取文件内容
      String csvData;
      if (selectedFile.bytes != null) {
        // 从内存读取，使用UTF-8解码
        csvData = utf8.decode(selectedFile.bytes!);
      } else if (selectedFile.path != null) {
        // 从文件路径读取
        csvData = await FileHelper.readFile(selectedFile.path!);
      } else {
        throw Exception('无法读取文件内容');
      }

      Navigator.of(context).pop(); // 关闭加载对话框

      // 显示文件信息并确认导入
      _showImportConfirmation(selectedFile, csvData);
    } catch (e) {
      Navigator.of(context).pop(); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '读取文件失败: ${e.toString()}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 显示导入确认对话框
  void _showImportConfirmation(dynamic file, String csvData) {
    final lines =
        csvData.split('\n').where((line) => line.trim().isNotEmpty).length;
    final fileSize = file.bytes?.length ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCardColor
            : AppTheme.cardColor,
        title: const Text('确认导入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名: ${file.name}'),
            Text('文件大小: ${FileHelper.getFileSizeString(fileSize)}'),
            Text('数据行数: $lines'),
            const SizedBox(height: 16),
            const Text('请选择导入模式：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.coolGray700
                    : AppTheme.coolGray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.update, size: 16, color: AppTheme.darkGray),
                      const SizedBox(width: 8),
                      Text(
                        '数据更新',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '只更新学习进度更好的记录，保留现有数据',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.coolGray700
                    : AppTheme.coolGray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.refresh,
                          size: 16, color: AppTheme.accentGreen),
                      const SizedBox(width: 8),
                      Text(
                        '全部覆盖',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '清空现有数据，完全替换为导入的数据',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.getSecondaryTextColor(context),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('取消'),
                ),
              ),
              SizedBox(
                width: 8,
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _performImport(csvData, ImportMode.update);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkGray,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  child: const Text('数据更新'),
                ),
              ),
              SizedBox(
                width: 8,
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _performImport(csvData, ImportMode.overwrite);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  child: const Text('全部覆盖'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  /// 执行导入
  Future<void> _performImport(String csvData, ImportMode importMode) async {
    if (csvData.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.warning_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请输入有效的CSV数据',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // 导入到公共单词本（传入null表示导入到全局记录）
      final result = await LearningDataService.instance
          .importLearningDataFromCsv(csvData, null, importMode);

      if (result.success) {
        final modeText = importMode == ImportMode.update ? '数据更新' : '全部覆盖';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已通过$modeText模式导入到公共单词本：${result.message}',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.message,
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '导入失败: ${e.toString()}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 打开单词回溯页面
  void _openWordReviewPage() async {
    final selectedWordBook = await CacheService.getSelectedWordBook();
    if (selectedWordBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.warning_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请先选择一个词书',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    CompatibleNavigator.pushNamed(
      context,
      '/enhanced_word_review',
      transitionType: PageTransitionType.slideFromBottom,
    );
  }

  /// 打开算法设置页面
  void _openAlgorithmSettings() {
    CompatibleNavigator.pushNamed(
      context,
      '/algorithm_settings',
      transitionType: PageTransitionType.slideFromBottom,
    );
  }

  /// 加载应用版本信息
  Future<void> _loadAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    } catch (e) {
      setState(() {
        _appVersion = '版本信息获取失败';
      });
    }
  }

  /// 检查应用更新
  Future<void> _checkForUpdates() async {
    // 使用自动更新服务进行手动检查
    await AutoUpdateService.instance.checkManually(context);
  }
}
