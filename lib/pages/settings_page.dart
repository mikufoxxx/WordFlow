import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../utils/english_word_api_service.dart';
import '../utils/deepseek_api_service.dart';
import '../utils/settings_helper.dart';
import '../utils/learning_data_service.dart';
import '../utils/cache_service.dart';
import '../utils/file_helper.dart';
import '../widgets/acrylic_app_bar.dart';
import '../main.dart';

/// 导入模式枚举
enum ImportMode {
  update,    // 数据更新：只更新学习进度更好的记录
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
  
  // DeepSeek API设置
  final TextEditingController _deepSeekApiKeyController = TextEditingController();
  bool _isApiKeyValid = false;
  bool _showApiKey = false;
  
  // 学习算法设置

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _deepSeekApiKeyController.addListener(_onApiKeyChanged);
  }
  
  @override
  void dispose() {
    _deepSeekApiKeyController.dispose();
    super.dispose();
  }
  
  /// API Key 变化监听
  void _onApiKeyChanged() {
    final apiKey = _deepSeekApiKeyController.text.trim();
    final isValid = apiKey.isNotEmpty && apiKey.length >= 10;
    
    if (isValid != _isApiKeyValid) {
      setState(() {
        _isApiKeyValid = isValid;
      });
      
      // 如果API Key变为无效且当前是深入学习模式，自动切换到快速学习模式
      if (!isValid && _learningMode == LearningMode.deepLearning) {
        setState(() {
          _learningMode = LearningMode.quickMemory;
        });
        _saveSettings();
        
        // 显示提示信息
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
                    'API Key无效，已自动切换到快速学习模式',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
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
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveHelper.getMaxContentWidth(context),
              ),
              child: ListView(
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
                        subtitle: _isApiKeyValid 
                          ? '包含造句练习和AI评估功能'
                          : '需要配置DeepSeek API Key才能使用此功能',
                        value: LearningMode.deepLearning,
                        groupValue: _learningMode!,
                        onChanged: _isApiKeyValid ? (LearningMode? value) {
                          if (value != null) {
                            setState(() {
                              _learningMode = value;
                            });
                            _saveSettings();
                          }
                        } : (LearningMode? value) {
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
                                    child: Text(
                                      '请先配置有效的DeepSeek API Key',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.black87
                                      ),
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
                        title: Text('正在加载学习模式设置...'),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    value ? '智能同步已开启' : '智能同步已关闭',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black87
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
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
                      leading: const Icon(Icons.info_outline),
                      title: '关于WordFlow',
                      subtitle: '版本 1.0.0',
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
                                    '你知道吗，已经改了好几版了，但是版本号没有变。。',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black87
                                    ),
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
                      },
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
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black87
                                    ),
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
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.primaryTextColor),
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
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: Offset(0, 2),
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
      onTap: onTap,
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
      value: value,
      onChanged: onChanged,
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
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkPrimaryGray 
          : AppTheme.primaryGray,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }



  /// 构建API Key设置项
  Widget _buildApiKeyTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.vpn_key_outlined,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'DeepSeek API Key',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryTextColor 
                      : AppTheme.primaryTextColor,
                ),
              ),
              if (_isApiKeyValid)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: Theme.of(context).brightness == Brightness.dark 
                        ? null 
                        : [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.15),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Text(
                    '已配置',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deepSeekApiKeyController,
            decoration: InputDecoration(
              hintText: '请输入DeepSeek API Key',
              hintStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkSecondaryTextColor 
                    : AppTheme.secondaryTextColor,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isApiKeyValid)
                    Icon(
                      Icons.check_circle_outlined,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.paste,
                      size: 20,
                    ),
                    onPressed: _pasteApiKey,
                    tooltip: '粘贴API Key',
                  ),
                  IconButton(
                    icon: Icon(
                      _showApiKey ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkSecondaryTextColor 
                          : AppTheme.secondaryTextColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _showApiKey = !_showApiKey;
                      });
                    },
                    tooltip: _showApiKey ? '隐藏API Key' : '显示API Key',
                  ),
                ],
              ),
            ),
            style: const TextStyle(fontSize: 14),
            obscureText: !_showApiKey,
            onChanged: (_) => _saveSettings(),
          ),
          const SizedBox(height: 6),
          Text(
            '用于AI造句判断功能，请在DeepSeek官网获取API Key',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkSecondaryTextColor 
                  : AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _testApiConnection,
                icon: Icon(
                  Icons.network_check, 
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryGray 
                      : AppTheme.primaryGray,
                ),
                label: Text(
                  '测试连接',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryGray 
                        : AppTheme.primaryGray,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showApiKeyHelp(),
                icon: Icon(
                  Icons.help_outline, 
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryGray 
                      : AppTheme.primaryGray,
                ),
                label: Text(
                  '获取帮助',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryGray 
                        : AppTheme.primaryGray,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  /// 加载设置
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = await DeepSeekApiService.getApiKey();
    final learningMode = await SettingsHelper.getLearningMode();
    
    // 加载算法配置

    if (mounted) {
      final isApiKeyValid = apiKey != null && apiKey.isNotEmpty && apiKey.length >= 10;
      
      // 如果API Key无效且当前是深入学习模式，自动切换到快速学习模式
      LearningMode finalLearningMode = learningMode;
      if (!isApiKeyValid && learningMode == LearningMode.deepLearning) {
        finalLearningMode = LearningMode.quickMemory;
        // 保存切换后的模式
        await SettingsHelper.setLearningMode(finalLearningMode);
      }
      
      setState(() {
        _autoPlayPronunciation = prefs.getBool('auto_play_pronunciation') ?? true;
        _enableDarkMode = prefs.getBool('enable_dark_mode') ?? false;
        _smartSyncEnabled = prefs.getBool('smart_sync_enabled') ?? true;
        final pronunciationTypeStr = prefs.getString('pronunciation_type') ?? 'uk';
        _pronunciationType = pronunciationTypeStr == 'us' ? PronunciationType.us : PronunciationType.uk;
        _learningMode = finalLearningMode;
        
        // 加载DeepSeek API key
        _deepSeekApiKeyController.text = apiKey ?? '';
        _isApiKeyValid = isApiKeyValid;
        
        // 加载算法配置
      });
      
      // 如果自动切换了学习模式，显示提示信息
      if (!isApiKeyValid && learningMode == LearningMode.deepLearning) {
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
                    '检测到无效的API Key，已自动切换到快速学习模式',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
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
  }

  /// 保存设置
  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play_pronunciation', _autoPlayPronunciation);
    await prefs.setBool('enable_dark_mode', _enableDarkMode);
    await prefs.setBool('smart_sync_enabled', _smartSyncEnabled);
    await prefs.setString('pronunciation_type', _pronunciationType.code);
    
    // 只在学习模式不为null时保存，且确保API Key有效时才能保存深入学习模式
    if (_learningMode != null) {
      // 如果API Key无效且尝试保存深入学习模式，强制切换到快速学习模式
      if (!_isApiKeyValid && _learningMode == LearningMode.deepLearning) {
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
                    'API Key无效，无法使用深入学习模式',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
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
    
    // 保存DeepSeek API key
    final apiKey = _deepSeekApiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      await DeepSeekApiService.setApiKey(apiKey);
    }
  }

  /// 显示重置对话框
  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置学习进度'),
        content: const Text('确定要清除所有学习记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetProgress();
            },
            child: Text(
              '确定',
              style: TextStyle(color: Colors.red.shade600),
            ),
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
                          : Colors.black87
                  ),
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
                          : Colors.black87
                  ),
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
  
  /// 测试API连接
  void _testApiConnection() async {
    if (!_isApiKeyValid) {
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
                  '请先输入有效的API Key',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
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
    
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在测试连接...'),
          ],
        ),
      ),
    );
    
    try {
      final isConnected = await DeepSeekApiService.testApiConnection();
      Navigator.pop(context); // 关闭加载对话框
      
      if (isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.gpp_good_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API连接成功！',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
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
                    'API连接失败，请检查API Key是否正确',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
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
      Navigator.pop(context); // 关闭加载对话框
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
                  '测试失败: $e',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
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
  
  /// 粘贴API Key
  void _pasteApiKey() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        setState(() {
          _deepSeekApiKeyController.text = data.text!;
        });
        _saveSettings();
        
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
                    '✅ API Key已粘贴',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
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
                    '❌ 剪贴板为空',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
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
                  '❌ 粘贴失败: $e',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
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

  /// 显示API Key帮助
  void _showApiKeyHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('如何获取DeepSeek API Key'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. 访问DeepSeek官网：'),
              SelectableText(
                'https://platform.deepseek.com',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
              SizedBox(height: 8),
              Text('2. 注册并登录账户'),
              SizedBox(height: 8),
              Text('3. 进入API Keys页面'),
              SizedBox(height: 8),
              Text('4. 创建新的API Key'),
              SizedBox(height: 8),
              Text('5. 复制API Key并粘贴到此处'),
              SizedBox(height: 16),
              Text(
                '注意：请妥善保管您的API Key，不要分享给他人',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }



  /// 导出学习数据
  void _exportLearningData() async {
    try {
      // 直接选择导出目录
      final selectedDirectory = await FileHelper.selectExportDirectory();
      if (selectedDirectory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选择导出位置')),
        );
        return;
      }

      // 显示导出中的提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
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
      final filePath = await FileHelper.saveFile(selectedDirectory, fileName, csvData);
      
      Navigator.of(context).pop(); // 关闭加载对话框
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('公共单词本数据已导出到:\n$filePath'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '复制路径',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: filePath));
            },
          ),
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
                          : Colors.black87
                  ),
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
                            : Colors.black87
                    ),
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
        builder: (context) => const AlertDialog(
          content: Row(
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
                          : Colors.black87
                  ),
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
    final lines = csvData.split('\n').where((line) => line.trim().isNotEmpty).length;
    final fileSize = file.bytes?.length ?? 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                      Icon(Icons.update, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '数据更新',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
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
                      Icon(Icons.refresh, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        '全部覆盖',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performImport(csvData, ImportMode.update);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('数据更新'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performImport(csvData, ImportMode.overwrite);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('全部覆盖'),
          ),
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
                          : Colors.black87
                  ),
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
      final result = await LearningDataService.instance.importLearningDataFromCsv(csvData, null, importMode);
      
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
                    '已通过${modeText}模式导入到公共单词本：${result.message}',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
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
                            : Colors.black87
                    ),
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
                          : Colors.black87
                  ),
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
                          : Colors.black87
                  ),
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

    Navigator.of(context).pushNamed('/enhanced_word_review');
  }

  /// 打开算法设置页面
  void _openAlgorithmSettings() {
    Navigator.of(context).pushNamed('/algorithm_settings');
  }
}
