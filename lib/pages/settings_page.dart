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
import '../utils/spaced_repetition_service.dart';
import '../utils/cache_service.dart';
import '../utils/file_helper.dart';
import '../widgets/acrylic_app_bar.dart';
import '../main.dart';

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
  PronunciationType _pronunciationType = PronunciationType.uk;
  LearningMode? _learningMode; // 改为可空类型，避免默认值闪烁
  
  // DeepSeek API设置
  final TextEditingController _deepSeekApiKeyController = TextEditingController();
  bool _isApiKeyValid = false;
  bool _showApiKey = false;
  
  // 学习算法设置
  SpacedRepetitionConfig? _algorithmConfig;

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
          const SnackBar(
            content: Text('API Key无效，已自动切换到快速学习模式'),
            duration: Duration(seconds: 3),
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
                            const SnackBar(
                              content: Text('请先配置有效的DeepSeek API Key'),
                              duration: Duration(seconds: 2),
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
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: '智能同步',
                      subtitle: '切换词书时自动继承学习记录',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('智能同步已自动开启，切换词书时会自动继承相同单词的学习进度'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
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
                      onTap: _showAboutDialog,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.feedback_outlined),
                      title: '意见反馈',
                      subtitle: '帮助我们改进应用',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('反馈功能开发中...')),
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
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkPrimaryTextColor 
              : AppTheme.primaryTextColor,
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
      child: Column(
        children: children,
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
              : AppTheme.primaryTextColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkSecondaryTextColor 
              : AppTheme.secondaryTextColor,
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
              ? AppTheme.darkAccentGreen 
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
      activeColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkPrimaryGray 
          : AppTheme.primaryGray,
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
              ? AppTheme.darkAccentGreen 
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

  /// 构建滑块设置项
  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Text(
                value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
  
  /// 构建信息展示项
  Widget _buildInfoTile(String title, String description) {
    return ListTile(
      leading: Icon(
        Icons.info_outline, 
        color: Theme.of(context).brightness == Brightness.dark 
            ? AppTheme.mediumGray 
            : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkAccentGreen 
              : AppTheme.darkGray,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          fontSize: 14, 
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.mediumGray 
              : Colors.grey,
        ),
      ),
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
    final algorithmConfig = await LearningDataService.instance.getAlgorithmConfig();
    
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
        final pronunciationTypeStr = prefs.getString('pronunciation_type') ?? 'uk';
        _pronunciationType = pronunciationTypeStr == 'us' ? PronunciationType.us : PronunciationType.uk;
        _learningMode = finalLearningMode;
        
        // 加载DeepSeek API key
        _deepSeekApiKeyController.text = apiKey ?? '';
        _isApiKeyValid = isApiKeyValid;
        
        // 加载算法配置
        _algorithmConfig = algorithmConfig;
      });
      
      // 如果自动切换了学习模式，显示提示信息
      if (!isApiKeyValid && learningMode == LearningMode.deepLearning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('检测到无效的API Key，已自动切换到快速学习模式'),
            duration: Duration(seconds: 3),
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
          const SnackBar(
            content: Text('API Key无效，无法使用深入学习模式'),
            duration: Duration(seconds: 2),
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
        const SnackBar(content: Text('学习进度已重置')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重置失败: ${e.toString()}')),
      );
    }
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'WordFlow',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.auto_stories_outlined,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text('智能背单词应用，让学习如流水般自然。'),
        const SizedBox(height: 16),
        const Text('特性：'),
        const Text('• 流式文字动画效果'),
        const Text('• AI智能造句判断'),
        const Text('• 简约优雅的界面设计'),
        const Text('• 个性化学习设置'),
      ],
    );
  }
  
  /// 测试API连接
  void _testApiConnection() async {
    if (!_isApiKeyValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入有效的API Key')),
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
          const SnackBar(
            content: Text('✅ API连接成功！'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ API连接失败，请检查API Key是否正确'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 测试失败: $e'),
          backgroundColor: Colors.red,
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
          const SnackBar(
            content: Text('✅ API Key已粘贴'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 剪贴板为空'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 粘贴失败: $e'),
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
      final selectedWordBook = await CacheService.getSelectedWordBook();
      if (selectedWordBook == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择一个词书')),
        );
        return;
      }

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

      // 获取CSV数据
      final csvData = await LearningDataService.instance.getLearningDataCsv(selectedWordBook);
      
      // 生成文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'WordFlow_${selectedWordBook}_$timestamp.csv';
      
      // 保存文件到选择的目录
      final filePath = await FileHelper.saveFile(selectedDirectory, fileName, csvData);
      
      Navigator.of(context).pop(); // 关闭加载对话框
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('数据已导出到:\n$filePath'),
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
        SnackBar(content: Text('导出失败: ${e.toString()}')),
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
          const SnackBar(content: Text('未选择文件')),
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
        SnackBar(content: Text('读取文件失败: ${e.toString()}')),
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
            const SizedBox(height: 12),
            const Text('确定要导入这些数据吗？'),
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
              await _performImport(csvData);
            },
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
  }

  /// 执行导入
  Future<void> _performImport(String csvData) async {
    if (csvData.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的CSV数据')),
      );
      return;
    }

    try {
      final selectedWordBook = await CacheService.getSelectedWordBook();
      if (selectedWordBook == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择一个词书')),
        );
        return;
      }

      final result = await LearningDataService.instance.importLearningDataFromCsv(csvData, selectedWordBook);
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: ${e.toString()}')),
      );
    }
  }

  /// 显示同步对话框
  void _showSyncDialog() async {
    final wordBooks = await CacheService.getCachedWordBooks();
    final currentWordBook = await CacheService.getSelectedWordBook();
    
    if (wordBooks.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要至少两个词书才能进行同步')),
      );
      return;
    }

    String? fromWordBook;
    String? toWordBook;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('词书数据同步'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('将学习数据从一个词书同步到另一个词书'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '从词书',
                  border: OutlineInputBorder(),
                ),
                value: fromWordBook,
                onChanged: (value) {
                  setState(() {
                    fromWordBook = value;
                  });
                },
                items: wordBooks.map((book) => DropdownMenuItem(
                  value: book.name,
                  child: Text(book.name),
                )).toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '到词书',
                  border: OutlineInputBorder(),
                ),
                value: toWordBook,
                onChanged: (value) {
                  setState(() {
                    toWordBook = value;
                  });
                },
                items: wordBooks.map((book) => DropdownMenuItem(
                  value: book.name,
                  child: Text(book.name),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: fromWordBook != null && toWordBook != null && fromWordBook != toWordBook
                  ? () async {
                      Navigator.of(context).pop();
                      await _performSync(fromWordBook!, toWordBook!);
                    }
                  : null,
              child: const Text('同步'),
            ),
          ],
        ),
      ),
    );
  }

  /// 执行同步
  Future<void> _performSync(String fromWordBook, String toWordBook) async {
    try {
      await LearningDataService.instance.syncWordBookData(fromWordBook, toWordBook);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 $fromWordBook 的数据同步到 $toWordBook')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败: ${e.toString()}')),
      );
    }
  }

  /// 打开单词回溯页面
  void _openWordReviewPage() async {
    final selectedWordBook = await CacheService.getSelectedWordBook();
    if (selectedWordBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个词书')),
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
