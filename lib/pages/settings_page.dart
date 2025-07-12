import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置页面 - 用于配置应用的基本设置
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 设置项状态
  bool _autoPlayPronunciation = true;
  bool _showWordAnimation = true;
  bool _enableDarkMode = false;
  int _dailyWordGoal = 20;
  String _selectedDifficulty = 'medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12), // 从16减少到12
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
            _buildSwitchTile(
              title: '文字动画效果',
              subtitle: '开启单词的流式浮现动画',
              value: _showWordAnimation,
              onChanged: (value) {
                setState(() {
                  _showWordAnimation = value;
                });
                _saveSettings();
              },
            ),
            _buildSliderTile(
              title: '每日单词目标',
              subtitle: '设置每天要学习的单词数量',
              value: _dailyWordGoal.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              onChanged: (value) {
                setState(() {
                  _dailyWordGoal = value.round();
                });
                _saveSettings();
              },
            ),
          ]),

          const SizedBox(height: 16), // 从20减少到16

          // 难度设置部分
          _buildSectionHeader('难度设置'),
          _buildSettingsCard([
            _buildRadioListTile(
              title: '简单',
              subtitle: '常用基础词汇',
              value: 'easy',
              groupValue: _selectedDifficulty,
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value!;
                });
                _saveSettings();
              },
            ),
            _buildRadioListTile(
              title: '中等',
              subtitle: '四六级词汇',
              value: 'medium',
              groupValue: _selectedDifficulty,
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value!;
                });
                _saveSettings();
              },
            ),
            _buildRadioListTile(
              title: '困难',
              subtitle: '托福雅思词汇',
              value: 'hard',
              groupValue: _selectedDifficulty,
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value!;
                });
                _saveSettings();
              },
            ),
          ]),

          const SizedBox(height: 16), // 从20减少到16

          // 外观设置部分
          _buildSectionHeader('外观设置'),
          _buildSettingsCard([
            _buildSwitchTile(
              title: '深色模式',
              subtitle: '启用深色主题（开发中）',
              value: _enableDarkMode,
              onChanged: (value) {
                setState(() {
                  _enableDarkMode = value;
                });
                _saveSettings();
                // TODO: 实现深色模式切换
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('深色模式功能开发中...')),
                );
              },
            ),
          ]),

          const SizedBox(height: 16), // 从20减少到16

          // 数据管理部分
          _buildSectionHeader('数据管理'),
          _buildSettingsCard([
            _buildCompactListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: '重置学习进度',
              subtitle: '清除所有学习记录',
              onTap: _showResetDialog,
            ),
            _buildCompactListTile(
              leading: const Icon(Icons.download_outlined),
              title: '导出学习数据',
              subtitle: '备份学习记录到文件',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('导出功能开发中...')),
                );
              },
            ),
          ]),

          const SizedBox(height: 16), // 从20减少到16

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
    );
  }

  /// 构建节标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6, top: 6), // 减少间距
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  /// 构建设置卡片
  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8), // 减少底部间距
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
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      dense: true, // 启用紧凑模式
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // 减少内边距
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
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
      dense: true, // 启用紧凑模式
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // 减少内边距
    );
  }

  /// 构建单选按钮设置项
  Widget _buildRadioListTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return RadioListTile<String>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
      dense: true, // 启用紧凑模式
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // 减少内边距
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
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 4), // 从8减少到4
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8), // 减少间距
              Container(
                width: 32, // 减少宽度
                alignment: Alignment.center,
                child: Text(
                  value.round().toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      dense: true, // 启用紧凑模式
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // 减少内边距
    );
  }

  /// 加载设置
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoPlayPronunciation = prefs.getBool('auto_play_pronunciation') ?? true;
      _showWordAnimation = prefs.getBool('show_word_animation') ?? true;
      _enableDarkMode = prefs.getBool('enable_dark_mode') ?? false;
      _dailyWordGoal = prefs.getInt('daily_word_goal') ?? 20;
      _selectedDifficulty = prefs.getString('selected_difficulty') ?? 'medium';
    });
  }

  /// 保存设置
  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play_pronunciation', _autoPlayPronunciation);
    await prefs.setBool('show_word_animation', _showWordAnimation);
    await prefs.setBool('enable_dark_mode', _enableDarkMode);
    await prefs.setInt('daily_word_goal', _dailyWordGoal);
    await prefs.setString('selected_difficulty', _selectedDifficulty);
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
    final prefs = await SharedPreferences.getInstance();
    // 清除学习相关的数据，但保留设置
    await prefs.remove('learning_progress');
    await prefs.remove('learned_words');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('学习进度已重置')),
    );
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'WordFlow',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
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
        const Text('• 智能学习算法'),
        const Text('• 简约优雅的界面设计'),
        const Text('• 个性化学习设置'),
      ],
    );
  }
}
