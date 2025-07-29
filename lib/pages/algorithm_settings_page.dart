// ignore_for_file: deprecated_member_use, duplicate_ignore, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/algorithm_config.dart';
import '../utils/algorithm_manager.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/acrylic_app_bar.dart';

/// 算法设置页面
class AlgorithmSettingsPage extends StatefulWidget {
  const AlgorithmSettingsPage({super.key});

  @override
  State<AlgorithmSettingsPage> createState() => _AlgorithmSettingsPageState();
}

class _AlgorithmSettingsPageState extends State<AlgorithmSettingsPage> {
  AlgorithmType _selectedAlgorithm = AlgorithmType.adaptive;
  final Map<AlgorithmType, AlgorithmConfig> _configs = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final manager = AlgorithmManager.instance;
      await manager.initialize();
      
      setState(() {
        _configs.addAll(manager.allConfigs);
        _selectedAlgorithm = manager.currentConfig?.type ?? AlgorithmType.adaptive;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkBackgroundColor 
          : AppTheme.backgroundColor,
      appBar: AcrylicAppBar(
        title: '算法设置',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: ResponsiveHelper.getResponsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAlgorithmSelector(),
                  const SizedBox(height: 24),
                  _buildAlgorithmDescription(),
                  const SizedBox(height: 24),
                  _buildParameterSettings(),
                  const SizedBox(height: 24),
                  _buildPresetButtons(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  /// 构建算法选择器
  Widget _buildAlgorithmSelector() {
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkCardColor
          : AppTheme.cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.dark 
              ? null 
              : [
                  BoxShadow(
                    color: AppTheme.coolGray200.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),

      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: AppTheme.primaryGray,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '学习算法选择',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryTextColor 
                        : AppTheme.primaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...AlgorithmType.values.map((type) => _buildAlgorithmOption(type)),
          ],
        ),
      ),
    ));
  }

  /// 构建算法选项
  Widget _buildAlgorithmOption(AlgorithmType type) {
    final isSelected = _selectedAlgorithm == type;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectAlgorithm(type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: isSelected ? AppTheme.primaryGray.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppTheme.primaryGray : AppTheme.coolGray300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Radio<AlgorithmType>(
                value: type,
                groupValue: _selectedAlgorithm,
                onChanged: (value) => _selectAlgorithm(value!),
                activeColor: AppTheme.primaryGray,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkPrimaryTextColor 
                            : AppTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkSecondaryTextColor 
                            : AppTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建算法描述
  Widget _buildAlgorithmDescription() {
    final config = _configs[_selectedAlgorithm];
    if (config == null) return const SizedBox();

    return Card(
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.dark 
              ? null 
              : [
                  BoxShadow(
                    color: AppTheme.coolGray200.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.accentGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '算法说明',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryTextColor 
                        : AppTheme.primaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getAlgorithmDetailedDescription(_selectedAlgorithm),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkSecondaryTextColor 
                    : AppTheme.primaryTextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ));
  }

  /// 构建参数设置
  Widget _buildParameterSettings() {
    switch (_selectedAlgorithm) {
      case AlgorithmType.superMemo:
        return _buildSuperMemoSettings();
      case AlgorithmType.anki:
        return _buildAnkiSettings();
      case AlgorithmType.adaptive:
        return _buildAdaptiveSettings();
    }
  }

  /// 构建SuperMemo设置
  Widget _buildSuperMemoSettings() {
    final config = _configs[AlgorithmType.superMemo] as SuperMemoConfig?;
    if (config == null) return const SizedBox();

    return Card(
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.dark 
              ? null 
              : [
                  BoxShadow(
                    color: AppTheme.coolGray200.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SuperMemo (SM-2) 参数设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkPrimaryTextColor 
                    : AppTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // 基础间隔设置
            _buildSectionTitle('基础间隔设置'),
            _buildParameterSlider(
              '初始间隔',
              '新单词学习完成后的首次复习间隔。较短会增加复习频率，较长会减少复习次数。推荐1-3天。',
              config.initialInterval,
              0.5,
              7.0,
              (value) => _updateSuperMemoConfig(config.copyWith(newParameters: {'initialInterval': value})),
              unit: '天',
            ),
            _buildParameterSlider(
              '最小间隔',
              '单词复习的最短间隔限制。即使答错多次，复习间隔也不会小于此值。推荐0.5-2天。',
              config.minInterval,
              0.1,
              3.0,
              (value) => _updateSuperMemoConfig(config.copyWith(newParameters: {'minInterval': value})),
              unit: '天',
            ),
            _buildParameterSlider(
              '最大间隔',
              '单词复习的最长间隔限制。即使掌握得很好，复习间隔也不会超过此值。推荐60-180天。',
              config.maxInterval,
              30.0,
              180.0,
              (value) => _updateSuperMemoConfig(config.copyWith(newParameters: {'maxInterval': value})),
              unit: '天',
            ),
            
            const SizedBox(height: 16),
            
            // 反馈调整倍数
            _buildSectionTitle('学习反馈调整'),
            _buildParameterSlider(
              '忘记惩罚',
              '当答错单词时，下次复习间隔缩短的幅度。数值越小惩罚越重，复习越频繁。推荐0.2-0.5。',
              config.forgotPenalty,
              0.1,
              1.0,
              (value) => _updateSuperMemoConfig(config.copyWith(newParameters: {'forgotPenalty': value})),
            ),
            _buildParameterSlider(
              '简单奖励',
              '当单词答对且感觉很简单时，下次复习间隔延长的倍数。数值越大间隔延长越多。推荐1.2-1.5。',
              config.easyBonus,
              1.1,
              2.0,
              (value) => _updateSuperMemoConfig(config.copyWith(newParameters: {'easyBonus': value})),
            ),
          ],
        ),
      ),
    ));
  }

  /// 构建Anki设置
  Widget _buildAnkiSettings() {
    final config = _configs[AlgorithmType.anki] as AnkiConfig?;
    if (config == null) return const SizedBox();

    return Card(
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.dark 
              ? null 
              : [
                  BoxShadow(
                    color: AppTheme.coolGray200.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anki 算法参数设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkPrimaryTextColor 
                    : AppTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // 基础设置
            _buildSectionTitle('基础设置'),
            _buildParameterSlider(
              '首次复习间隔',
              '新单词完成学习阶段后进入复习阶段的首次间隔。这是从"学习"转为"复习"的重要节点。推荐1-4天。',
              config.graduatingInterval.toDouble(),
              1.0,
              7.0,
              (value) => _updateAnkiConfig(config.copyWith(newParameters: {'graduatingInterval': value.round()})),
              unit: '天',
            ),
            _buildParameterSlider(
              '最大间隔',
              '复习间隔的上限。即使单词掌握得非常好，间隔也不会超过此值。较大值适合长期记忆。推荐180-365天。',
              config.maxInterval.toDouble(),
              90.0,
              365.0,
              (value) => _updateAnkiConfig(config.copyWith(newParameters: {'maxInterval': value.round()})),
              unit: '天',
            ),
            _buildParameterSlider(
              '间隔修正',
              '全局间隔调整系数。>1.0 延长间隔（学习节奏放慢），<1.0 缩短间隔（学习节奏加快）。推荐0.8-1.2。',
              config.intervalModifier,
              0.8,
              1.3,
              (value) => _updateAnkiConfig(config.copyWith(newParameters: {'intervalModifier': value})),
            ),
          ],
        ),
      ),
    ));
  }

  /// 构建自适应设置
  Widget _buildAdaptiveSettings() {
    final config = _configs[AlgorithmType.adaptive] as AdaptiveConfig?;
    if (config == null) return const SizedBox();

    return Card(
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.dark 
              ? null 
              : [
                  BoxShadow(
                    color: AppTheme.coolGray200.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '智能自适应算法参数设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkPrimaryTextColor 
                    : AppTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              '自适应算法会根据您的学习表现自动调整复习间隔。以下参数影响算法的调整方向和强度。',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkSecondaryTextColor 
                    : AppTheme.coolGray600,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 基础设置
            _buildSectionTitle('核心参数'),
            _buildParameterSlider(
              '学习强度',
              '控制整体学习节奏的快慢。数值越高学习节奏越快（新词推送更频繁，间隔调整更激进），越低则越保守。推荐0.6-1.0。',
              config.learningAbility,
              0.5,
              1.5,
              (value) => _updateAdaptiveConfig(config.copyWith(newParameters: {'learningAbility': value})),
            ),
            _buildParameterSlider(
              '复习密度',
              '调节复习频率的高低。数值越高复习越频繁（间隔相对较短），越低复习越稀疏（间隔相对较长）。推荐0.4-0.7。',
              config.reviewDensity,
              0.3,
              0.8,
              (value) => _updateAdaptiveConfig(config.copyWith(newParameters: {'reviewDensity': value})),
            ),
            
            const SizedBox(height: 16),
            
            // 个性化设置
            _buildSectionTitle('智能化功能'),
            _buildParameterSwitch(
              '实时调整',
              '根据最近的学习表现实时微调算法参数，让复习计划更贴合当前学习状态',
              config.realTimeAdjustment,
              (value) => _updateAdaptiveConfig(config.copyWith(newParameters: {'realTimeAdjustment': value})),
            ),
          ],
        ),
      ),
    ));
  }



  /// 构建参数滑块（带输入框）
  Widget _buildParameterSlider(
    String title,
    String description,
    double value,
    double min,
    double max,
    Function(double) onChanged, {
    String unit = '',
    int divisions = 100,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark 
                        ? AppTheme.darkPrimaryTextColor 
                        : AppTheme.coolGray700,
                  ),
                ),
                    const SizedBox(height: 2),
                    Text(
                      // ignore: unnecessary_brace_in_string_interps
                      '范围: ${min.toStringAsFixed(min < 1 ? 1 : 0)}-${max.toStringAsFixed(max < 10 ? 1 : 0)}${unit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark 
                            ? AppTheme.darkSecondaryTextColor 
                            : AppTheme.coolGray400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              // 数值显示框
              Container(
                width: 90,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray50),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        value.toStringAsFixed(value < 1 ? 2 : value < 10 ? 1 : 0),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark 
                        ? AppTheme.darkPrimaryTextColor 
                        : AppTheme.coolGray700,
                  ),
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        unit,
                        style: TextStyle(
                      fontSize: 10,
                      color: isDark 
                          ? AppTheme.darkSecondaryTextColor 
                          : AppTheme.coolGray500,
                    ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: isDark 
                  ? AppTheme.darkSecondaryTextColor 
                  : AppTheme.coolGray500,
            ),
          ),
          const SizedBox(height: 8),
          // 范围标签
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                // ignore: unnecessary_string_interpolations
                '${min.toStringAsFixed(min < 1 ? 1 : 0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark 
                      ? AppTheme.darkSecondaryTextColor 
                      : AppTheme.coolGray400,
                ),
              ),
              Text(
                // ignore: unnecessary_brace_in_string_interps
                '当前: ${value.toStringAsFixed(value < 1 ? 2 : value < 10 ? 1 : 0)}${unit}',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.primaryGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                // ignore: unnecessary_string_interpolations
                '${max.toStringAsFixed(max < 10 ? 1 : 0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark 
                      ? AppTheme.darkSecondaryTextColor 
                      : AppTheme.coolGray400,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryGray,
              inactiveTrackColor: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray200),
              thumbColor: AppTheme.primaryGray,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建参数开关
  Widget _buildParameterSwitch(
    String title,
    String description,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkAccentGreen 
                        : AppTheme.coolGray700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.mediumGray 
                        : AppTheme.coolGray500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.darkPrimaryGray 
                : AppTheme.primaryGray,
          ),
        ],
      ),
    );
  }

  /// 构建节标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
        ),
      ),
    );
  }

  /// 构建预设按钮
  Widget _buildPresetButtons() {
    return Card(
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.dark 
              ? null 
              : [
                  BoxShadow(
                    color: AppTheme.coolGray200.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkAccentBlue 
                      : AppTheme.accentBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
            Text(
              '预设配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkAccentGreen 
                    : AppTheme.coolGray700,
              ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '根据您的学习习惯选择合适的预设配置',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.mediumGray 
                    : AppTheme.coolGray500,
              ),
            ),
            const SizedBox(height: 16),
            
            // 预设说明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    // ignore: deprecated_member_use
                    ? AppTheme.darkGray.withOpacity(0.3)
                    : AppTheme.coolGray50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark 
                      // ignore: deprecated_member_use
                      ? AppTheme.darkPrimaryGray.withOpacity(0.3)
                      : AppTheme.coolGray200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPresetDescription('保守模式', '复习频率高，间隔增长慢，适合记忆力较弱或希望稳固掌握的用户'),
                  const SizedBox(height: 8),
                  _buildPresetDescription('平衡模式', '适中的复习频率和间隔增长，适合大多数用户的日常学习'),
                  const SizedBox(height: 8),
                  _buildPresetDescription('激进模式', '复习频率低，间隔增长快，适合记忆力较好或时间紧张的用户'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _applyPreset('conservative'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkPrimaryGray 
                            : AppTheme.coolGray300,
                      ),
                      foregroundColor: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkAccentGreen 
                          : AppTheme.darkGray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('保守'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _applyPreset('balanced'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkPrimaryGray 
                            : AppTheme.coolGray300,
                      ),
                      foregroundColor: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkAccentGreen 
                          : AppTheme.darkGray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('平衡'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _applyPreset('aggressive'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkPrimaryGray 
                            : AppTheme.coolGray300,
                      ),
                      foregroundColor: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkAccentGreen 
                          : AppTheme.darkGray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('激进'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  /// 构建预设描述
  Widget _buildPresetDescription(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.darkAccentGreen 
                : AppTheme.coolGray700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.mediumGray 
                : AppTheme.coolGray600,
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetToDefaults,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryGray 
                        : AppTheme.coolGray300,
                  ),
                  foregroundColor: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkAccentGreen 
                      : AppTheme.darkGray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('重置默认'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _exportConfig,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryGray 
                        : AppTheme.coolGray300,
                  ),
                  foregroundColor: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkAccentGreen 
                      : AppTheme.darkGray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('导出配置'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _importConfig,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryGray 
                        : AppTheme.coolGray300,
                  ),
                  foregroundColor: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkAccentGreen 
                      : AppTheme.darkGray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('导入配置'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _applyChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkPrimaryGray 
                  : AppTheme.primaryGray,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('应用设置'),
          ),
        ),
      ],
    );
  }

  /// 选择算法
  void _selectAlgorithm(AlgorithmType type) {
    setState(() {
      _selectedAlgorithm = type;
    });
  }

  /// 更新SuperMemo配置
  void _updateSuperMemoConfig(SuperMemoConfig config) {
    setState(() {
      _configs[AlgorithmType.superMemo] = config;
    });
  }

  /// 更新Anki配置
  void _updateAnkiConfig(AnkiConfig config) {
    setState(() {
      _configs[AlgorithmType.anki] = config;
    });
  }

  /// 更新自适应配置
  void _updateAdaptiveConfig(AdaptiveConfig config) {
    setState(() {
      _configs[AlgorithmType.adaptive] = config;
    });
  }

  /// 应用预设
  void _applyPreset(String presetName) {
    AlgorithmConfig? preset;
    String presetDisplayName = '';
    
    switch (presetName) {
      case 'conservative':
        presetDisplayName = '保守模式';
        break;
      case 'balanced':
        presetDisplayName = '平衡模式';
        break;
      case 'aggressive':
        presetDisplayName = '激进模式';
        break;
    }
    
    switch (_selectedAlgorithm) {
      case AlgorithmType.superMemo:
        switch (presetName) {
          case 'conservative':
            preset = SuperMemoConfig.conservative();
            break;
          case 'balanced':
            preset = SuperMemoConfig.balanced();
            break;
          case 'aggressive':
            preset = SuperMemoConfig.aggressive();
            break;
        }
        break;
      case AlgorithmType.anki:
        switch (presetName) {
          case 'conservative':
            preset = AnkiConfig.conservative();
            break;
          case 'balanced':
            preset = AnkiConfig.balanced();
            break;
          case 'aggressive':
            preset = AnkiConfig.aggressive();
            break;
        }
        break;
      case AlgorithmType.adaptive:
        // 自适应算法的预设配置
        switch (presetName) {
          case 'conservative':
            preset = const AdaptiveConfig(
              learningAbility: 0.6,
              reviewDensity: 0.6,
              realTimeAdjustment: true,
            );
            break;
          case 'balanced':
        preset = const AdaptiveConfig();
            break;
          case 'aggressive':
            preset = const AdaptiveConfig(
              learningAbility: 1.0,
              reviewDensity: 0.4,
              realTimeAdjustment: true,
            );
            break;
        }
        break;
    }

    if (preset != null) {
      setState(() {
        _configs[_selectedAlgorithm] = preset!;
      });
      
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
                  '已应用$presetDisplayName',
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



  /// 重置为默认值
  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置配置'),
        content: const Text('确定要重置为默认配置吗？这将清除所有自定义设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _configs[_selectedAlgorithm] = _selectedAlgorithm.defaultConfig;
              });
              Navigator.pop(context);
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
                          '已重置为默认配置',
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
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 导出配置
  void _exportConfig() {
    try {
      final manager = AlgorithmManager.instance;
      final configJson = manager.exportConfig(_selectedAlgorithm);
      
      Clipboard.setData(ClipboardData(text: configJson));
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
                  '配置已复制到剪贴板',
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
                  '导出失败: $e',
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

  /// 导入配置
  void _importConfig() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          title: const Text('导入配置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  maxLines: 5,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkPrimaryTextColor
                            : AppTheme.primaryTextColor,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    hintText: '粘贴配置JSON...',
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkSecondaryTextColor
                      : AppTheme.secondaryTextColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final manager = AlgorithmManager.instance;
                  await manager.importConfig(controller.text);
                  
                  await _loadConfigs();
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outlined,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkPrimaryTextColor
                                : AppTheme.primaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '配置导入成功',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.darkPrimaryTextColor
                                      : AppTheme.primaryTextColor
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
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkPrimaryTextColor
                                : AppTheme.primaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '导入失败: $e',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.darkPrimaryTextColor
                                      : AppTheme.primaryTextColor
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
              },
              child: Text(
                '导入',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkPrimaryTextColor
                      : AppTheme.primaryTextColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 应用更改
  void _applyChanges() async {
    try {
      final manager = AlgorithmManager.instance;
      
      // 验证配置
      final currentConfig = _configs[_selectedAlgorithm];
      if (currentConfig != null) {
        final validation = manager.validateConfig(currentConfig);
        if (!validation.isValid) {
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
                      '配置错误: ${validation.errors.join(', ')}',
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
      }
      
      // 应用配置
      await manager.switchAlgorithm(_selectedAlgorithm);
      if (currentConfig != null) {
        await manager.updateConfig(currentConfig);
      }
      
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
                  '设置已应用',
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
      
      Navigator.pop(context);
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
                  '应用失败: $e',
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



  /// 获取算法详细描述
  String _getAlgorithmDetailedDescription(AlgorithmType type) {
    switch (type) {
      case AlgorithmType.superMemo:
        return 'SuperMemo (SM-2) 算法是基于艾宾浩斯遗忘曲线的科学记忆算法。它通过分析你的学习表现，动态调整每个单词的复习间隔，确保在即将遗忘的时候进行复习，从而达到最佳的学习效率。\n\n核心特点：\n• 精确的间隔计算\n• 难度系数自适应\n• 高效的记忆保持\n• 适合系统性学习';
      case AlgorithmType.anki:
        return 'Anki 算法是注重长期记忆保持的稳定算法。它采用更保守的间隔策略，确保单词不会被遗忘。特别适合希望稳定学习、循序渐进的用户。\n\n核心特点：\n• 保守的间隔策略\n• 强调长期记忆\n• 水蛭卡片识别\n• 适合稳定学习';
      case AlgorithmType.adaptive:
        return '智能自适应算法结合了机器学习和AI技术，能够根据你的学习习惯、记忆能力和学习表现自动调整所有参数。无需手动配置，系统会持续优化以提供最适合你的学习体验。\n\n核心特点：\n• 自动参数优化\n• 个性化学习分析\n• AI辅助决策\n• 适合所有用户';
    }
  }
}