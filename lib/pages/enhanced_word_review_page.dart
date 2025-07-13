import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/detailed_learning_record.dart';
import '../models/word_learning_record.dart';
import '../utils/learning_data_service.dart';
import '../utils/algorithm_manager.dart';
import '../utils/responsive_helper.dart';
import '../utils/app_theme.dart';
import '../utils/cache_service.dart';
import '../utils/chart_helper.dart';
import 'word_detail_page.dart';

/// 个性化推荐数据模型
class PersonalizedRecommendation {
  final String title;
  final String description;
  final Color color;
  final IconData icon;

  const PersonalizedRecommendation({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
  });
}

/// 增强的单词回溯页面
class EnhancedWordReviewPage extends StatefulWidget {
  const EnhancedWordReviewPage({super.key});

  @override
  State<EnhancedWordReviewPage> createState() => _EnhancedWordReviewPageState();
}

class _EnhancedWordReviewPageState extends State<EnhancedWordReviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // 数据状态
  List<EnhancedWordLearningRecord> _allRecords = [];
  List<EnhancedWordLearningRecord> _filteredRecords = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  
  // 筛选状态
  MemoryLevel? _selectedLevel;
  WordDifficulty? _selectedDifficulty;
  LearningMode? _selectedMode;
  String _searchQuery = '';
  bool _showOnlyDueWords = false;
  
  // 当前选中的词书
  String _currentWordBook = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterRecords();
    });
  }

  /// 加载数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取当前选中的词书
      final selectedWordBook = await CacheService.getSelectedWordBook();
      if (selectedWordBook != null) {
        _currentWordBook = selectedWordBook;
        
        // 加载学习记录
        final records = await LearningDataService.instance.getWordBookRecords(selectedWordBook);
        
        // 转换为增强记录
        final enhancedRecords = records.map((record) {
          return EnhancedWordLearningRecord.fromWordLearningRecord(record);
        }).toList();
        
        // 获取统计信息
        final manager = AlgorithmManager.instance;
        final stats = manager.getAlgorithmStats(enhancedRecords);
        
        setState(() {
          _allRecords = enhancedRecords;
          _statistics = stats;
          _filterRecords();
        });
      }
    } catch (e) {
      print('❌ 加载数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 筛选记录
  void _filterRecords() {
    _filteredRecords = _allRecords.where((record) {
      // 搜索过滤
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = record.word.toLowerCase().contains(_searchQuery) ||
            record.translation.toLowerCase().contains(_searchQuery);
        if (!matchesSearch) return false;
      }
      
      // 记忆程度过滤
      if (_selectedLevel != null && record.memoryLevel != _selectedLevel) {
        return false;
      }
      
      // 难度过滤
      if (_selectedDifficulty != null && record.difficulty != _selectedDifficulty) {
        return false;
      }
      
      // 学习模式过滤
      if (_selectedMode != null) {
        final hasMode = record.sessions.any((s) => s.learningMode == _selectedMode);
        if (!hasMode) return false;
      }
      
      // 到期单词过滤
      if (_showOnlyDueWords && !record.needsReview) {
        return false;
      }
      
      return true;
    }).toList();
    
    // 按掌握程度排序
    _filteredRecords.sort((a, b) {
      if (a.memoryLevel != b.memoryLevel) {
        return a.memoryLevel.index.compareTo(b.memoryLevel.index);
      }
      return a.word.compareTo(b.word);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('学习分析'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primaryGray),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGray),
            onPressed: _loadData,
            tooltip: '刷新数据',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGray,
          unselectedLabelColor: AppTheme.coolGray500,
          indicatorColor: AppTheme.primaryGray,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '单词列表'),
            Tab(text: '学习统计'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWordListTab(),
                _buildStatisticsTab(),
              ],
            ),
    );
  }

  /// 构建单词列表标签页
  Widget _buildWordListTab() {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: _filteredRecords.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: ResponsiveHelper.getResponsivePadding(context),
                  itemCount: _filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record = _filteredRecords[index];
                    return _buildEnhancedWordCard(record);
                  },
                ),
        ),
      ],
    );
  }

  /// 构建搜索和筛选
  Widget _buildSearchAndFilter() {
    return Container(
      padding: ResponsiveHelper.getResponsivePadding(context),
      child: Column(
        children: [
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索单词或释义...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.coolGray300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryGray, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // 筛选选项
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('记忆程度', _selectedLevel?.displayName, () => _showLevelFilter()),
                _buildFilterChip('难度', _selectedDifficulty?.displayName, () => _showDifficultyFilter()),
                _buildFilterChip('学习模式', _selectedMode?.displayName, () => _showModeFilter()),
                _buildFilterChip('到期单词', _showOnlyDueWords ? '是' : null, () => _toggleDueWordsFilter()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建筛选芯片
  Widget _buildFilterChip(String label, String? value, VoidCallback onTap) {
    final isSelected = value != null;
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(isSelected ? '$label: $value' : label),
        onPressed: onTap,
        backgroundColor: isSelected ? AppTheme.primaryGray.withOpacity(0.1) : null,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryGray : AppTheme.coolGray300,
        ),
      ),
    );
  }

  /// 构建增强的单词卡片
  Widget _buildEnhancedWordCard(EnhancedWordLearningRecord record) {
    return Card(
      color: AppTheme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showWordDetails(record),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 单词和难度
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.word,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.coolGray700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: record.difficulty.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: record.difficulty.color),
                    ),
                    child: Text(
                      record.difficulty.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        color: record.difficulty.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // 翻译
              Text(
                record.translation,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.coolGray600,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 学习统计
              Row(
                children: [
                  _buildStatChip(record.memoryLevel.displayName, record.memoryLevel.color),
                  const SizedBox(width: 8),
                  _buildStatChip('${record.learningCount}次', AppTheme.coolGray500),
                  const SizedBox(width: 8),
                  _buildStatChip('${(record.masteryPercentage * 100).toStringAsFixed(0)}%', AppTheme.accentGreen),
                  const Spacer(),
                  if (record.needsReview)
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.orange,
                    ),
                ],
              ),
              
              // 最近学习会话
              if (record.lastSession != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.coolGray50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        record.lastSession!.learningMode.icon,
                        size: 16,
                        color: AppTheme.coolGray500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.lastSession!.learningMode.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.coolGray500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: record.lastSession!.result.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.lastSession!.result.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: record.lastSession!.result.color,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MM/dd HH:mm').format(record.lastSession!.sessionTime),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.coolGray400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建统计芯片
  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建统计标签页
  Widget _buildStatisticsTab() {
    if (_statistics.isEmpty) {
      return _buildEmptyState('暂无统计数据');
    }

    return SingleChildScrollView(
      padding: ResponsiveHelper.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 整体学习情况
          _buildOverallStatsCard(),
          
          const SizedBox(height: 16),
          
          // 掌握情况分布
          _buildMasteryDistributionCard(),
          
          const SizedBox(height: 16),
          
          // 记忆级别分布
          _buildMemoryLevelDistributionCard(),
          
          const SizedBox(height: 16),
          
          // 每日学习量趋势
          _buildDailyLearningTrendCard(),
          
          const SizedBox(height: 16),
          
          // 记忆效果分析
          _buildMemoryEffectivenessCard(),
          
          const SizedBox(height: 16),
          
          // 个性化建议
          _buildPersonalizedRecommendationsCard(),
        ],
      ),
    );
  }

  /// 构建整体学习情况卡片
  Widget _buildOverallStatsCard() {
    final totalWords = _allRecords.length;
    final masteredWords = _allRecords.where((r) => r.masteryPercentage >= 0.8).length;
    final studyingWords = _allRecords.where((r) => r.masteryPercentage >= 0.3 && r.masteryPercentage < 0.8).length;
    final newWords = _allRecords.where((r) => r.masteryPercentage < 0.3).length;
    final masteryRate = totalWords > 0 ? (masteredWords / totalWords) : 0.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accentBlue.withOpacity(0.05),
              AppTheme.accentTeal.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    size: 24,
                    color: AppTheme.accentBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '学习概况',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.coolGray800,
                        ),
                      ),
                      Text(
                        '总词书：$_currentWordBook',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.coolGray600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 学习统计网格
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '总单词数',
                    totalWords.toString(),
                    AppTheme.accentBlue,
                    Icons.book_outlined,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '已掌握',
                    masteredWords.toString(),
                    AppTheme.accentGreen,
                    Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '学习中',
                    studyingWords.toString(),
                    AppTheme.accentYellow,
                    Icons.school_outlined,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '新单词',
                    newWords.toString(),
                    AppTheme.accentRed,
                    Icons.add_circle_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.coolGray600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建掌握情况分布卡片
  Widget _buildMasteryDistributionCard() {
    final excellent = _allRecords.where((r) => r.masteryPercentage >= 0.8).length;
    final good = _allRecords.where((r) => r.masteryPercentage >= 0.6 && r.masteryPercentage < 0.8).length;
    final average = _allRecords.where((r) => r.masteryPercentage >= 0.4 && r.masteryPercentage < 0.6).length;
    final poor = _allRecords.where((r) => r.masteryPercentage < 0.4).length;
    final total = _allRecords.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_small_outlined, size: 20, color: AppTheme.coolGray600),
                const SizedBox(width: 8),
                Text(
                  '掌握情况分布',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coolGray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (total > 0) ...[
              _buildProgressBar('优秀 (80%+)', excellent, excellent / total, AppTheme.accentGreen),
              _buildProgressBar('良好 (60-80%)', good, good / total, AppTheme.accentBlue),
              _buildProgressBar('一般 (40-60%)', average, average / total, AppTheme.accentYellow),
              _buildProgressBar('较弱 (<40%)', poor, poor / total, AppTheme.accentRed),
            ] else ...[
              Text(
                '暂无数据',
                style: TextStyle(
                  color: AppTheme.coolGray500,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建记忆级别分布卡片
  Widget _buildMemoryLevelDistributionCard() {
    final levelCounts = <MemoryLevel, int>{};
    for (final level in MemoryLevel.values) {
      levelCounts[level] = _allRecords.where((r) => r.memoryLevel == level).length;
    }
    final total = _allRecords.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.layers_outlined, size: 20, color: AppTheme.coolGray600),
                const SizedBox(width: 8),
                Text(
                  '记忆级别分布',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coolGray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (total > 0) ...[
              ...levelCounts.entries.map((entry) {
                final level = entry.key;
                final count = entry.value;
                final percentage = count / total;
                
                return _buildProgressBar(
                  level.displayName,
                  count,
                  percentage,
                  level.color,
                );
              }).toList(),
            ] else ...[
              Text(
                '暂无数据',
                style: TextStyle(
                  color: AppTheme.coolGray500,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建每日学习量趋势卡片
  Widget _buildDailyLearningTrendCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_outlined, size: 20, color: AppTheme.coolGray600),
                const SizedBox(width: 8),
                Text(
                  '每日学习量',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coolGray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 计算最近7天的学习量
            _buildDailyLearningChart(),
          ],
        ),
      ),
    );
  }

  /// 构建每日学习量图表
  Widget _buildDailyLearningChart() {
    final now = DateTime.now();
    final dailyStats = <DateTime, int>{};
    
    // 初始化最近7天的数据
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      dailyStats[date] = 0;
    }
    
    // 统计每日学习量 - 基于学习记录的最后学习时间
    for (final record in _allRecords) {
      final lastLearningDate = DateTime(
        record.lastLearningTime.year,
        record.lastLearningTime.month,
        record.lastLearningTime.day,
      );
      if (dailyStats.containsKey(lastLearningDate)) {
        dailyStats[lastLearningDate] = dailyStats[lastLearningDate]! + 1;
      }
    }
    
    if (dailyStats.values.every((count) => count == 0)) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            '暂无最近7天的学习记录',
            style: TextStyle(
              color: AppTheme.coolGray500,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    
    final maxCount = dailyStats.values.reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dailyStats.entries.map((entry) {
            final date = entry.key;
            final count = entry.value;
            final height = maxCount > 0 ? (count / maxCount * 80) : 0.0;
            
            return Column(
              children: [
                Container(
                  width: 24,
                  height: 80,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 24,
                    height: height,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${date.month}/${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.coolGray600,
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.coolGray700,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          '最近7天平均每日学习 ${(dailyStats.values.reduce((a, b) => a + b) / 7).toStringAsFixed(1)} 个单词',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.coolGray600,
          ),
        ),
      ],
    );
  }

  /// 构建记忆效果分析卡片
  Widget _buildMemoryEffectivenessCard() {
    // 使用已有的指标：学习次数、正确次数、掌握程度
    final totalLearningCount = _allRecords.fold(0, (sum, r) => sum + r.learningCount);
    final totalCorrectCount = _allRecords.fold(0, (sum, r) => sum + r.correctCount);
    final averageMastery = _allRecords.isNotEmpty 
        ? _allRecords.map((r) => r.masteryPercentage).reduce((a, b) => a + b) / _allRecords.length 
        : 0.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_outlined, size: 20, color: AppTheme.coolGray600),
                const SizedBox(width: 8),
                Text(
                  '记忆效果分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coolGray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildEffectivenessItem(
                    '总学习次数',
                    totalLearningCount.toString(),
                    AppTheme.accentBlue,
                    Icons.school_outlined,
                  ),
                ),
                Expanded(
                  child: _buildEffectivenessItem(
                    '总正确次数',
                    totalCorrectCount.toString(),
                    AppTheme.accentGreen,
                    Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildEffectivenessItem(
                    '平均掌握度',
                    '${(averageMastery * 100).toStringAsFixed(1)}%',
                    AppTheme.accentTeal,
                    Icons.trending_up_outlined,
                  ),
                ),
                Expanded(
                  child:                   _buildEffectivenessItem(
                    '正确率',
                    totalLearningCount > 0 ? '${(totalCorrectCount / totalLearningCount * 100).toStringAsFixed(1)}%' : '0%',
                    _getSuccessRateColor(totalLearningCount > 0 ? totalCorrectCount / totalLearningCount : 0.0),
                    Icons.analytics_outlined,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            LinearProgressIndicator(
              value: averageMastery,
              backgroundColor: AppTheme.coolGray200,
              valueColor: AlwaysStoppedAnimation<Color>(_getSuccessRateColor(averageMastery)),
              minHeight: 8,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              _getEffectivenessDescription(averageMastery),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.coolGray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建效果分析项
  Widget _buildEffectivenessItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.coolGray600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建个性化推荐卡片
  Widget _buildPersonalizedRecommendationsCard() {
    final recommendations = _generatePersonalizedRecommendations();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: AppTheme.coolGray600),
                const SizedBox(width: 8),
                Text(
                  '个性化建议',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coolGray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ...recommendations.map((recommendation) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: recommendation.color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: recommendation.color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    recommendation.icon,
                    size: 20,
                    color: recommendation.color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recommendation.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.coolGray700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recommendation.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.coolGray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  /// 生成个性化推荐
  List<PersonalizedRecommendation> _generatePersonalizedRecommendations() {
    final recommendations = <PersonalizedRecommendation>[];
    
    // 分析学习数据
    final totalSessions = _allRecords.expand((r) => r.sessions).length;
    final correctSessions = _allRecords.expand((r) => r.sessions).where((s) => s.result.isCorrect).length;
    final successRate = totalSessions > 0 ? (correctSessions / totalSessions) : 0.0;
    final masteredWords = _allRecords.where((r) => r.masteryPercentage >= 0.8).length;
    final totalWords = _allRecords.length;
    
    // 正确率低的建议
    if (successRate < 0.6) {
      recommendations.add(PersonalizedRecommendation(
        title: '加强基础练习',
        description: '当前正确率较低，建议多进行基础记忆练习，降低学习强度',
        color: AppTheme.accentRed,
        icon: Icons.trending_down_outlined,
      ));
    }
    
    // 掌握率低的建议
    if (totalWords > 0 && masteredWords / totalWords < 0.3) {
      recommendations.add(PersonalizedRecommendation(
        title: '增加复习频率',
        description: '已掌握单词较少，建议增加复习频率，巩固学习成果',
        color: AppTheme.accentYellow,
        icon: Icons.repeat_outlined,
      ));
    }
    
    // 学习量建议
    final recentSessions = _allRecords.expand((r) => r.sessions)
        .where((s) => DateTime.now().difference(s.sessionTime).inDays <= 7)
        .length;
    
    if (recentSessions < 10) {
      recommendations.add(PersonalizedRecommendation(
        title: '保持学习节奏',
        description: '最近一周学习量较少，建议每天至少学习10-15个单词',
        color: AppTheme.accentBlue,
        icon: Icons.schedule_outlined,
      ));
    }
    
    // 正面鼓励
    if (successRate >= 0.8) {
      recommendations.add(PersonalizedRecommendation(
        title: '学习效果很好',
        description: '正确率很高，可以适当增加学习难度或新词汇量',
        color: AppTheme.accentGreen,
        icon: Icons.trending_up_outlined,
      ));
    }
    
    // 默认建议
    if (recommendations.isEmpty) {
      recommendations.add(PersonalizedRecommendation(
        title: '继续保持',
        description: '学习状态良好，建议保持当前的学习节奏和习惯',
        color: AppTheme.accentTeal,
        icon: Icons.thumb_up_outlined,
      ));
    }
    
    return recommendations;
  }

  /// 获取正确率颜色
  Color _getSuccessRateColor(double rate) {
    if (rate >= 0.8) return AppTheme.accentGreen;
    if (rate >= 0.6) return AppTheme.accentYellow;
    return AppTheme.accentRed;
  }

  /// 获取效果描述
  String _getEffectivenessDescription(double rate) {
    if (rate >= 0.8) return '记忆效果优秀，继续保持！';
    if (rate >= 0.6) return '记忆效果良好，可以适当提高难度';
    if (rate >= 0.4) return '记忆效果一般，建议加强复习';
    return '记忆效果较差，建议降低学习强度';
  }

  /// 构建进度条
  Widget _buildProgressBar(String label, int count, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.coolGray600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppTheme.coolGray200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count (${(percentage * 100).toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.coolGray500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图表部分
  Widget _buildChartsSection() {
    return Column(
      children: [
        // 难度分布饼图
        _buildChartCard(
          title: '难度分布',
          icon: Icons.pie_chart,
          chart: ChartHelper.buildDifficultyPieChart(_allRecords),
          description: '认识/不认识单词分布',
        ),
        
        const SizedBox(height: 16),
        
        // 记忆程度柱状图
        _buildChartCard(
          title: '记忆程度分布',
          icon: Icons.bar_chart,
          chart: ChartHelper.buildMemoryLevelChart(_allRecords),
          description: '单词记忆程度统计',
        ),
        
        const SizedBox(height: 16),
        
        // 学习成绩趋势图
        _buildChartCard(
          title: '学习成绩趋势',
          icon: Icons.grade,
          chart: ChartHelper.buildScoreTrendChart(_allRecords),
          description: '学习成绩变化情况',
        ),
      ],
    );
  }

  /// 构建图表卡片
  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Widget chart,
    required String description,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardColor,
              AppTheme.coolGray50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: AppTheme.accentBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.coolGray800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.coolGray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              chart,
            ],
          ),
        ),
      ),
    );
  }

  /// 构建记忆程度图表
  Widget _buildMemoryLevelChart() {
    final levelCounts = <MemoryLevel, int>{};
    for (final level in MemoryLevel.values) {
      levelCounts[level] = _allRecords.where((r) => r.memoryLevel == level).length;
    }

    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '记忆程度分布',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.coolGray700,
              ),
            ),
            const SizedBox(height: 16),
            ...levelCounts.entries.map((entry) {
              final percentage = _allRecords.isEmpty ? 0.0 : entry.value / _allRecords.length;
              return _buildProgressBar(entry.key.displayName, entry.value, percentage, entry.key.color);
            }),
          ],
        ),
      ),
    );
  }

  /// 构建难度图表
  Widget _buildDifficultyChart() {
    final difficultyCounts = <WordDifficulty, int>{};
    for (final difficulty in WordDifficulty.values) {
      difficultyCounts[difficulty] = _allRecords.where((r) => r.difficulty == difficulty).length;
    }

    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '难度分布',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.coolGray700,
              ),
            ),
            const SizedBox(height: 16),
            ...difficultyCounts.entries.map((entry) {
              final percentage = _allRecords.isEmpty ? 0.0 : entry.value / _allRecords.length;
              return _buildProgressBar(entry.key.displayName, entry.value, percentage, entry.key.color);
            }),
          ],
        ),
      ),
    );
  }

  /// 构建学习模式统计
  Widget _buildLearningModeStats() {
    final modeStats = <LearningMode, int>{};
    for (final record in _allRecords) {
      for (final entry in record.modeStats.entries) {
        modeStats[entry.key] = (modeStats[entry.key] ?? 0) + entry.value;
      }
    }

    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '学习模式统计',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.coolGray700,
              ),
            ),
            const SizedBox(height: 16),
            ...modeStats.entries.map((entry) {
              final total = modeStats.values.fold(0, (sum, count) => sum + count);
              final percentage = total == 0 ? 0.0 : entry.value / total;
              return _buildProgressBar(entry.key.displayName, entry.value, percentage, AppTheme.primaryGray);
            }),
          ],
        ),
      ),
    );
  }

  /// 构建算法统计
  Widget _buildAlgorithmStats() {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前算法',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.coolGray700,
              ),
            ),
            const SizedBox(height: 16),
            if (_statistics.isNotEmpty) ...[
              Text(
                '算法类型: ${_statistics['algorithmType'] ?? '未知'}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.coolGray600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '配置名称: ${_statistics['configName'] ?? '未知'}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.coolGray600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState([String message = '暂无数据']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppTheme.coolGray400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.coolGray500,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示单词详情
  void _showWordDetails(EnhancedWordLearningRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordDetailPage(record: record),
      ),
    );
  }

  /// 构建详情统计项
  Widget _buildDetailStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.coolGray600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 显示记忆程度筛选
  void _showLevelFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择记忆程度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('全部'),
              onTap: () {
                setState(() {
                  _selectedLevel = null;
                  _filterRecords();
                });
                Navigator.pop(context);
              },
            ),
            ...MemoryLevel.values.map((level) => ListTile(
              title: Text(level.displayName),
              leading: CircleAvatar(
                backgroundColor: level.color,
                radius: 8,
              ),
              onTap: () {
                setState(() {
                  _selectedLevel = level;
                  _filterRecords();
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  /// 显示难度筛选
  void _showDifficultyFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择难度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('全部'),
              onTap: () {
                setState(() {
                  _selectedDifficulty = null;
                  _filterRecords();
                });
                Navigator.pop(context);
              },
            ),
            ...WordDifficulty.values.map((difficulty) => ListTile(
              title: Text(difficulty.displayName),
              leading: CircleAvatar(
                backgroundColor: difficulty.color,
                radius: 8,
              ),
              onTap: () {
                setState(() {
                  _selectedDifficulty = difficulty;
                  _filterRecords();
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  /// 显示学习模式筛选
  void _showModeFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择学习模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('全部'),
              onTap: () {
                setState(() {
                  _selectedMode = null;
                  _filterRecords();
                });
                Navigator.pop(context);
              },
            ),
            ...LearningMode.values.map((mode) => ListTile(
              title: Text(mode.displayName),
              leading: Icon(mode.icon),
              onTap: () {
                setState(() {
                  _selectedMode = mode;
                  _filterRecords();
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  /// 切换到期单词筛选
  void _toggleDueWordsFilter() {
    setState(() {
      _showOnlyDueWords = !_showOnlyDueWords;
      _filterRecords();
    });
  }

  /// 清除筛选
  void _clearFilter(String filterType) {
    setState(() {
      switch (filterType) {
        case '记忆程度':
          _selectedLevel = null;
          break;
        case '难度':
          _selectedDifficulty = null;
          break;
        case '学习模式':
          _selectedMode = null;
          break;
        case '到期单词':
          _showOnlyDueWords = false;
          break;
      }
      _filterRecords();
    });
  }

  /// 导出学习数据
  void _exportLearningData() async {
    try {
      final csvData = await LearningDataService.instance.exportLearningDataToCsv(_currentWordBook);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('学习数据已导出: $csvData')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  /// 格式化时长
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}秒';
    } else if (seconds < 3600) {
      return '${(seconds / 60).toStringAsFixed(1)}分钟';
    } else {
      return '${(seconds / 3600).toStringAsFixed(1)}小时';
    }
  }
} 