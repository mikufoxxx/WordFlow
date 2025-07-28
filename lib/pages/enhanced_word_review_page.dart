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
import '../widgets/custom_date_picker.dart';
import 'word_detail_page.dart';

/// 每日学习数据模型
class DailyLearningData {
  int totalLearningCount = 0;
  int easyCount = 0;
  int goodCount = 0;
  int hardCount = 0;
  int forgotCount = 0;
  double averageMastery = 0.0;
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

  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  
  // 搜索状态
  String _searchQuery = '';
  
  // 日期导航状态
  DateTime _selectedDate = DateTime.now();
  PageController _datePageController = PageController(initialPage: 1000); // 设置一个较大的初始页面以支持前后滑动
  
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
    _datePageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkBackgroundColor 
          : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          '学习分析',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.darkAccentGreen 
                : AppTheme.darkGray,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? AppTheme.darkBackgroundColor 
            : AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new, 
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.darkPrimaryGray 
                : AppTheme.primaryGray,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh, 
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkPrimaryGray 
                  : AppTheme.primaryGray,
            ),
            onPressed: _loadData,
            tooltip: '刷新数据',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkPrimaryGray 
              : AppTheme.primaryGray,
          unselectedLabelColor: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.mediumGray 
              : AppTheme.coolGray500,
          indicatorColor: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkPrimaryGray 
              : AppTheme.primaryGray,
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
              physics: const NeverScrollableScrollPhysics(), // 禁用滑动切换
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
        // 搜索框
        Container(
          padding: ResponsiveHelper.getResponsivePadding(context),
          child: TextField(
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
        ),
        
        // 日期导航
        _buildDateNavigation(),
        
        // 单词列表
        Expanded(
          child: _buildWordListForDate(_selectedDate),
        ),
      ],
    );
  }

  /// 按日期分组学习记录
  Map<String, List<EnhancedWordLearningRecord>> _groupRecordsByDate() {
    final filteredRecords = _allRecords.where((record) {
      if (_searchQuery.isNotEmpty) {
        return record.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               record.translation.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();
    
    final Map<String, List<EnhancedWordLearningRecord>> groupedRecords = {};
    
    for (final record in filteredRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.lastLearningTime);
      final displayDate = _getDateDisplayText(record.lastLearningTime);
      
      if (!groupedRecords.containsKey(displayDate)) {
        groupedRecords[displayDate] = [];
      }
      groupedRecords[displayDate]!.add(record);
    }
    
    // 按日期排序（最新的在前）
    final sortedEntries = groupedRecords.entries.toList()
      ..sort((a, b) => _getDateFromDisplayText(b.key).compareTo(_getDateFromDisplayText(a.key)));
    
    return Map.fromEntries(sortedEntries);
  }

  /// 获取日期显示文本
  String _getDateDisplayText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(recordDate).inDays;
    
    if (difference == 0) {
      return '今天';
    } else if (difference == 1) {
      return '昨天';
    } else if (difference == 2) {
      return '前天';
    } else if (difference <= 7) {
      return '${difference}天前';
    } else {
      return DateFormat('yyyy年MM月dd日').format(date);
    }
  }

  /// 从显示文本获取日期（用于排序）
  DateTime _getDateFromDisplayText(String displayText) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (displayText) {
      case '今天':
        return today;
      case '昨天':
        return today.subtract(const Duration(days: 1));
      case '前天':
        return today.subtract(const Duration(days: 2));
      default:
        if (displayText.contains('天前')) {
          final days = int.parse(displayText.replaceAll('天前', ''));
          return today.subtract(Duration(days: days));
        }
        // 对于具体日期，尝试解析
        try {
          return DateFormat('yyyy年MM月dd日').parse(displayText);
        } catch (e) {
          return DateTime(2000); // 默认返回一个很早的日期
        }
    }
  }

  /// 构建日期导航
  Widget _buildDateNavigation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 上一天按钮
          IconButton(
            onPressed: () => _changeDate(-1),
            icon: const Icon(Icons.chevron_left),
            iconSize: 24,
          ),
          
          // 日期显示和选择
          Expanded(
            child: GestureDetector(
              onTap: _showDatePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardColor : AppTheme.coolGray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: isDark ? AppTheme.coolGray500 : AppTheme.coolGray600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getDateDisplayText(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.coolGray700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 下一天按钮
          IconButton(
            onPressed: _canGoToNextDay() ? () => _changeDate(1) : null,
            icon: const Icon(Icons.chevron_right),
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  /// 构建指定日期的单词列表
  Widget _buildWordListForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final recordsForDate = _getRecordsForDate(dateKey);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (recordsForDate.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: ResponsiveHelper.getResponsivePadding(context),
      itemCount: recordsForDate.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          // 日期标题
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardColor : AppTheme.coolGray100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 16,
                  color: isDark ? AppTheme.coolGray500 : AppTheme.coolGray600,
                ),
                const SizedBox(width: 8),
                Text(
                  '${recordsForDate.length}个单词',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.coolGray700,
                  ),
                ),
              ],
            ),
          );
        }
        
        final record = recordsForDate[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildEnhancedWordCard(record),
        );
      },
    );
  }

  /// 获取指定日期的学习记录
  List<EnhancedWordLearningRecord> _getRecordsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return _allRecords.where((record) {
      final lastLearningDate = record.lastLearningTime;
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = record.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               record.translation.toLowerCase().contains(_searchQuery.toLowerCase());
        if (!matchesSearch) return false;
      }
      return lastLearningDate.isAfter(startOfDay) && lastLearningDate.isBefore(endOfDay);
    }).toList();
  }

  /// 改变日期
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  /// 是否可以前往下一天
  bool _canGoToNextDay() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selectedDate.isBefore(todayDate);
  }

  /// 显示日期选择器
  void _showDatePicker() async {
    // 计算每天的单词数量
    final dailyWordCounts = <DateTime, int>{};
    for (final record in _allRecords) {
      final date = DateTime(
        record.lastLearningTime.year,
        record.lastLearningTime.month,
        record.lastLearningTime.day,
      );
      dailyWordCounts[date] = (dailyWordCounts[date] ?? 0) + 1;
    }

    showDialog(
      context: context,
      builder: (context) => CustomDatePicker(
        initialDate: _selectedDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now(),
        dailyWordCounts: dailyWordCounts,
        onDateSelected: (selectedDate) {
          setState(() {
            _selectedDate = selectedDate;
          });
        },
      ),
    );
  }

  /// 构建增强的单词卡片
  Widget _buildEnhancedWordCard(EnhancedWordLearningRecord record) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? AppTheme.darkCardColor : AppTheme.cardColor,
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
                        color: isDark ? const Color(0xFFDCEFEA) : AppTheme.coolGray700,
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
                  color: isDark ? const Color(0xFFDCEFEA) : AppTheme.coolGray600,
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
              
              // 详细统计
              if (record.learningCount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '简单:${record.easyCount} 良好:${record.goodCount} 困难:${record.hardCount} 忘记:${record.forgotCount}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppTheme.coolGray500 : AppTheme.coolGray400,
                      ),
                    ),
                  ],
                ),
              ],
              
              // 最近学习会话
              if (record.lastSession != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.coolGray700.withOpacity(0.3) : AppTheme.coolGray50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        record.lastSession!.learningMode.icon,
                        size: 16,
                        color: isDark ? AppTheme.coolGray400 : AppTheme.coolGray500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.lastSession!.learningMode.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.coolGray400 : AppTheme.coolGray500,
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
                          color: isDark ? AppTheme.coolGray500 : AppTheme.coolGray400,
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
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
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
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
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
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
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
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
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
    final dailyData = <DateTime, DailyLearningData>{};
    
    // 初始化最近7天的数据
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      dailyData[date] = DailyLearningData();
    }
    
    // 统计每日数据 - 基于reviewHistory
    for (final record in _allRecords) {
      for (final review in record.reviewHistory) {
        final reviewDate = DateTime(
          review.reviewTime.year,
          review.reviewTime.month,
          review.reviewTime.day,
        );
        
        if (dailyData.containsKey(reviewDate)) {
          final data = dailyData[reviewDate]!;
          data.totalLearningCount++;
          
          switch (review.reviewResult) {
            case ReviewResult.easy:
              data.easyCount++;
              break;
            case ReviewResult.good:
              data.goodCount++;
              break;
            case ReviewResult.hard:
              data.hardCount++;
              break;
            case ReviewResult.forgot:
              data.forgotCount++;
              break;
          }
        }
      }
    }
    
    // 计算每日平均掌握度
    for (final entry in dailyData.entries) {
      final date = entry.key;
      final data = entry.value;
      final recordsOnDate = _allRecords.where((r) {
        final lastDate = DateTime(
          r.lastLearningTime.year,
          r.lastLearningTime.month,
          r.lastLearningTime.day,
        );
        return lastDate == date;
      }).toList();
      
      if (recordsOnDate.isNotEmpty) {
        data.averageMastery = recordsOnDate.map((r) => r.masteryPercentage).reduce((a, b) => a + b) / recordsOnDate.length;
      }
    }
    
    if (dailyData.values.every((data) => data.totalLearningCount == 0)) {
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
    
    final maxCount = dailyData.values.map((data) => data.totalLearningCount).reduce((a, b) => a > b ? a : b);
    final maxMastery = 1.0; // 掌握度最大值为100%
    
    return Column(
      children: [
        // 图表
        SizedBox(
          height: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dailyData.entries.map((entry) {
              final date = entry.key;
              final data = entry.value;
              
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      // 堆叠柱状图
                      Expanded(
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // 总高度容器
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 80),
                              alignment: Alignment.bottomCenter,
                              child: maxCount > 0 ? _buildStackedBar(data, maxCount) : Container(height: 2, color: AppTheme.coolGray200),
                            ),
                            // 掌握度折线图点和百分比
                            if (data.averageMastery > 0)
                              Positioned(
                                bottom: (data.averageMastery / maxMastery * 80),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 百分比文本
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentTeal,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${(data.averageMastery * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // 圆点
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentTeal,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // 日期
                      Text(
                        '${date.month}/${date.day}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.coolGray600,
                        ),
                      ),
                      
                      // 学习次数
                      Text(
                        '${data.totalLearningCount}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.coolGray700,
                        ),
                      ),
                      

                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItem('简单', AppTheme.accentGreen),
            _buildLegendItem('良好', AppTheme.accentBlue),
            _buildLegendItem('困难', AppTheme.accentYellow),
            _buildLegendItem('忘记', AppTheme.accentRed),
            _buildLegendItem('掌握度', AppTheme.accentTeal),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // 统计信息
        Text(
          '最近7天总学习次数 ${dailyData.values.map((d) => d.totalLearningCount).reduce((a, b) => a + b)} 次',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.coolGray600,
          ),
        ),
      ],
    );
  }

  /// 构建堆叠柱状图
  Widget _buildStackedBar(DailyLearningData data, int maxCount) {
    final totalHeight = 80.0;
    final barHeight = (data.totalLearningCount / maxCount * totalHeight);
    
    if (data.totalLearningCount == 0) {
      return Container(height: 2, color: AppTheme.coolGray200);
    }
    
    final total = data.totalLearningCount;
    final easyHeight = (data.easyCount / total) * barHeight;
    final goodHeight = (data.goodCount / total) * barHeight;
    final hardHeight = (data.hardCount / total) * barHeight;
    final forgotHeight = (data.forgotCount / total) * barHeight;
    
    return Container(
      width: double.infinity,
      height: barHeight,
      child: Column(
        children: [
          if (data.easyCount > 0)
            Container(
              height: easyHeight,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen,
                borderRadius: data.goodCount + data.hardCount + data.forgotCount == 0 
                    ? BorderRadius.circular(4) 
                    : const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
              ),
            ),
          if (data.goodCount > 0)
            Container(
              height: goodHeight,
              color: AppTheme.accentBlue,
            ),
          if (data.hardCount > 0)
            Container(
              height: hardHeight,
              color: AppTheme.accentYellow,
            ),
          if (data.forgotCount > 0)
            Container(
              height: forgotHeight,
              decoration: BoxDecoration(
                color: AppTheme.accentRed,
                borderRadius: data.easyCount + data.goodCount + data.hardCount == 0 
                    ? BorderRadius.circular(4) 
                    : const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建图例项
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: label == '掌握度' ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: label == '掌握度' ? null : BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.coolGray600,
          ),
        ),
      ],
    );
  }

  /// 构建记忆效果分析卡片
  Widget _buildMemoryEffectivenessCard() {
    // 统计4个分类的学习表现
    final totalLearningCount = _allRecords.fold(0, (sum, r) => sum + r.learningCount);
    final totalForgotCount = _allRecords.fold(0, (sum, r) => sum + r.forgotCount);
    final totalHardCount = _allRecords.fold(0, (sum, r) => sum + r.hardCount);
    final totalGoodCount = _allRecords.fold(0, (sum, r) => sum + r.goodCount);
    final totalEasyCount = _allRecords.fold(0, (sum, r) => sum + r.easyCount);
    final averageMastery = _allRecords.isNotEmpty 
        ? _allRecords.map((r) => r.masteryPercentage).reduce((a, b) => a + b) / _allRecords.length 
        : 0.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
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
                  '学习表现统计',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coolGray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 第一行：总学习次数和平均掌握度
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
                    '平均掌握度',
                    '${(averageMastery * 100).toStringAsFixed(1)}%',
                    AppTheme.accentTeal,
                    Icons.trending_up_outlined,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 第二行：4分类统计
            Row(
              children: [
                Expanded(
                  child: _buildEffectivenessItem(
                    '简单',
                    totalEasyCount.toString(),
                    AppTheme.accentGreen,
                    Icons.sentiment_very_satisfied_outlined,
                  ),
                ),
                Expanded(
                  child: _buildEffectivenessItem(
                    '良好',
                    totalGoodCount.toString(),
                    AppTheme.accentBlue,
                    Icons.sentiment_satisfied_outlined,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildEffectivenessItem(
                    '困难',
                    totalHardCount.toString(),
                    AppTheme.accentYellow,
                    Icons.sentiment_neutral_outlined,
                  ),
                ),
                Expanded(
                  child: _buildEffectivenessItem(
                    '忘记',
                    totalForgotCount.toString(),
                    AppTheme.accentRed,
                    Icons.sentiment_dissatisfied_outlined,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [
                    AppTheme.darkCardColor,
                    AppTheme.coolGray700,
                  ]
                : [
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
                            color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.coolGray800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkSecondaryTextColor : AppTheme.coolGray500,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final levelCounts = <MemoryLevel, int>{};
    for (final level in MemoryLevel.values) {
      levelCounts[level] = _allRecords.where((r) => r.memoryLevel == level).length;
    }
    final total = _allRecords.length;

    return Card(
      color: isDark ? AppTheme.darkCardColor : AppTheme.cardColor,
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
                color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.coolGray700,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final difficultyCounts = <WordDifficulty, int>{};
    for (final difficulty in WordDifficulty.values) {
      difficultyCounts[difficulty] = _allRecords.where((r) => r.difficulty == difficulty).length;
    }

    return Card(
      color: isDark ? AppTheme.darkCardColor : AppTheme.cardColor,
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
                color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.coolGray700,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modeStats = <LearningMode, int>{};
    for (final record in _allRecords) {
      for (final entry in record.modeStats.entries) {
        modeStats[entry.key] = (modeStats[entry.key] ?? 0) + entry.value;
      }
    }

    return Card(
      color: isDark ? AppTheme.darkCardColor : AppTheme.cardColor,
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
                color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.coolGray700,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? AppTheme.darkCardColor : AppTheme.cardColor,
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
                color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.coolGray700,
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