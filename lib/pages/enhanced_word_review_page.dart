// ignore_for_file: deprecated_member_use, duplicate_ignore, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/detailed_learning_record.dart';
import '../models/word_learning_record.dart';
import '../utils/learning_data_service.dart';
import '../utils/algorithm_manager.dart';
import '../utils/responsive_helper.dart';
import '../utils/app_theme.dart';
import '../utils/cache_service.dart';
import '../utils/sound_service.dart';
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

/// 自定义折线图绘制器
class _LineChartPainter extends CustomPainter {
  final List<MapEntry<DateTime, DailyLearningData>> entries;
  final double minMastery;
  final double maxMastery;
  final double maxBarHeight;
  final BuildContext context;

  _LineChartPainter({
    required this.entries,
    required this.minMastery,
    required this.maxMastery,
    required this.maxBarHeight,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final paint = Paint()
      ..color = AppTheme.accentTeal
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = AppTheme.accentTeal
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 使用完整的绘制区域（外层容器已经处理了边距）
    final drawWidth = size.width;
    final drawHeight = size.height;

    // 计算每个柱子的宽度和间距
    final barSpacing = 8.0; // 与柱状图的horizontal padding保持一致
    final totalSpacing = (entries.length - 1) * barSpacing;
    final barWidth = (drawWidth - totalSpacing) / entries.length;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < entries.length; i++) {
      final data = entries[i].value;
      
      // 计算X坐标（柱子中心位置）
      final x = (i * (barWidth + barSpacing)) + (barWidth / 2);
      
      // 计算Y坐标（直接将掌握度0-100%映射到柱状图的完整高度范围）
      // 掌握度0%对应柱状图底部，100%对应柱状图顶部
      final normalizedMastery = data.averageMastery / 100.0; // 将掌握度转换为0-1的比例
      // 计算柱状图区域的底部位置（考虑到底部有日期标签的空间）
      final chartBottomY = drawHeight - 32; // 32px是底部日期标签的空间（与容器padding保持一致）
      final y = chartBottomY - (normalizedMastery * maxBarHeight); // 从柱状图底部向上映射

      final point = Offset(x, y);
      points.add(point);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // 使用二次贝塞尔曲线创建平滑曲线
        final prevPoint = points[i - 1];
        final controlPoint1 = Offset(
          prevPoint.dx + (x - prevPoint.dx) * 0.5,
          prevPoint.dy,
        );
        final controlPoint2 = Offset(
          prevPoint.dx + (x - prevPoint.dx) * 0.5,
          y,
        );
        path.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          x, y,
        );
      }
    }

    // 绘制折线
    canvas.drawPath(path, paint);

    // 绘制数据点
    for (final point in points) {
      // 绘制白色边框
      canvas.drawCircle(point, 6, dotBorderPaint);
      // 绘制主色点
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
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
  final PageController _datePageController = PageController(initialPage: 1000); // 设置一个较大的初始页面以支持前后滑动
  
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
          onPressed: () {
            SoundService.playTapOffSound();
            Navigator.pop(context);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.primaryGray),
          unselectedLabelColor: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray500),
          indicatorColor: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.primaryGray),
          indicatorWeight: 3,
          onTap: (index) {
            SoundService.playTapSound();
          },
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
      return '$difference天前';
    } else {
      return DateFormat('yyyy年MM月dd日').format(date);
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
            onPressed: () {
              SoundService.playTapSound();
              _changeDate(-1);
            },
            icon: const Icon(Icons.chevron_left),
            iconSize: 24,
          ),
          
          // 日期显示和选择
          Expanded(
            child: GestureDetector(
              onTap: () {
                SoundService.playTapSound();
                _showDatePicker();
              },
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
                      color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getDateDisplayText(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 下一天按钮
          IconButton(
            onPressed: _canGoToNextDay() ? () {
              SoundService.playTapSound();
              _changeDate(1);
            } : null,
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
      physics: const ClampingScrollPhysics(),
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
                  color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
                ),
                const SizedBox(width: 8),
                Text(
                  '${recordsForDate.length}个单词',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
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
    return Card(
      elevation: 0,
      color: AppTheme.getCardColor(context),
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.coolGray200.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
         child: InkWell(
           onTap: () {
             SoundService.playTapSound();
             _showWordDetails(record);
           },
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
                        color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
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
                  color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
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
                        color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray400),
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
                    color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        record.lastSession!.learningMode.icon,
                        size: 16,
                        color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray500),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.lastSession!.learningMode.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray500),
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
                          color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray400),
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
    ));
  }

  /// 构建统计芯片
  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCardColor
                : AppTheme.cardColor,

          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.coolGray200.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: Theme.of(context).brightness == Brightness.dark
                        ? null
                        : [
                      BoxShadow(
                        color: AppTheme.coolGray200.withOpacity(0.15),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
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
                          color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray800),
                        ),
                      ),
                      Text(
                        '总词书：$_currentWordBook',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.mediumGray
                              : AppTheme.coolGray500,
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
        // ignore: deprecated_member_use
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
              color: AppTheme.getPrimaryTitleColor(context, lightColor: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
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
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkCardColor 
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.coolGray200.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_small_outlined, size: 20, color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.mediumGray
                    : AppTheme.coolGray500),
                const SizedBox(width: 8),
                Text(
                  '掌握情况分布',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
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
    ));
  }

  /// 构建记忆级别分布卡片
  Widget _buildMemoryLevelDistributionCard() {
    final levelCounts = <MemoryLevel, int>{};
    for (final level in MemoryLevel.values) {
      levelCounts[level] = _allRecords.where((r) => r.memoryLevel == level).length;
    }
    final total = _allRecords.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkCardColor 
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.coolGray200.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.layers_outlined, size: 20, color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.mediumGray
                    : AppTheme.coolGray500),
                const SizedBox(width: 8),
                Text(
                  '记忆级别分布',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
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
    ));
  }

  /// 构建每日学习量趋势卡片
  Widget _buildDailyLearningTrendCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkCardColor 
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.coolGray200.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_outlined, size: 20, color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.mediumGray
                    : AppTheme.coolGray500),
                const SizedBox(width: 8),
                Text(
                  '每日学习量',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
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
    ));
  }

  /// 构建每日学习量图表
  Widget _buildDailyLearningChart() {
    final now = DateTime.now();
    final dailyData = <DateTime, DailyLearningData>{};
    
    // 找到第一天使用的日期
    DateTime? firstUseDate;
    if (_allRecords.isNotEmpty) {
      for (final record in _allRecords) {
        if (record.reviewHistory.isNotEmpty) {
          for (final review in record.reviewHistory) {
            final reviewDate = DateTime(
              review.reviewTime.year,
              review.reviewTime.month,
              review.reviewTime.day,
            );
            if (firstUseDate == null || reviewDate.isBefore(firstUseDate)) {
              firstUseDate = reviewDate;
            }
          }
        }
      }
    }
    
    // 如果没有使用记录，显示最近7天
    if (firstUseDate == null) {
      for (int i = 6; i >= 0; i--) {
        final date = DateTime(now.year, now.month, now.day - i);
        dailyData[date] = DailyLearningData();
      }
    } else {
      // 计算从第一天使用到现在的天数
      final daysSinceFirst = now.difference(firstUseDate).inDays;
      
      if (daysSinceFirst < 7) {
        // 不满一周，从第一天开始显示到今天
        for (int i = 0; i <= daysSinceFirst; i++) {
          final date = DateTime(
            firstUseDate.year,
            firstUseDate.month,
            firstUseDate.day + i,
          );
          dailyData[date] = DailyLearningData();
        }
      } else {
        // 满一周后，显示最近7天（滑动窗口）
        for (int i = 6; i >= 0; i--) {
          final date = DateTime(now.year, now.month, now.day - i);
          dailyData[date] = DailyLearningData();
        }
      }
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
    
    // 计算每日平均掌握度 - 基于当天所有单词的掌握度
    double lastValidMastery = 0.0; // 记录上一个有效的掌握度值
    
    for (final entry in dailyData.entries) {
      final date = entry.key;
      final data = entry.value;
      
      // 获取当天有学习记录的所有单词
      final wordsLearnedOnDate = <EnhancedWordLearningRecord>[];
      for (final record in _allRecords) {
        // 检查该单词在当天是否有复习记录
        final hasReviewOnDate = record.reviewHistory.any((review) {
          final reviewDate = DateTime(
            review.reviewTime.year,
            review.reviewTime.month,
            review.reviewTime.day,
          );
          return reviewDate == date;
        });
        
        if (hasReviewOnDate) {
          wordsLearnedOnDate.add(record);
        }
      }
      
      // 计算当天所有学习单词的平均掌握度
      if (wordsLearnedOnDate.isNotEmpty) {
        final totalMastery = wordsLearnedOnDate.map((r) => r.masteryPercentage).reduce((a, b) => a + b);
        data.averageMastery = (totalMastery / wordsLearnedOnDate.length) * 100; // 转换为0-100范围用于显示
        lastValidMastery = data.averageMastery; // 更新最后有效值
      } else {
        // 如果当天没有学习记录，延续前一天的掌握度
        data.averageMastery = lastValidMastery;
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
    
    return Column(
      children: [
        // 混合图表：柱状图 + 折线图
        Container(
          height: 180,
          padding: const EdgeInsets.only(left: 32, bottom: 32, right: 16, top: 16), // 调整padding使图表更居中
          child: Stack(
            children: [
              // 柱状图层
              _buildBarChartLayer(dailyData, maxCount),
              // 折线图层
              _buildLineChartLayer(dailyData),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
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

  /// 构建柱状图层
  Widget _buildBarChartLayer(Map<DateTime, DailyLearningData> dailyData, int maxCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: dailyData.entries.map((entry) {
          final date = entry.key;
          final data = entry.value;
          
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 堆叠柱状图
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 2),
                    child: maxCount > 0 ? _buildStackedBar(data, maxCount, 100) : Container(height: 2, color: AppTheme.coolGray200),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 日期
                  Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.mediumGray
                          : AppTheme.coolGray500,
                    ),
                  ),
                  
                  // 学习次数
                  Text(
                    '${data.totalLearningCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.mediumGray
                          : AppTheme.coolGray500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
    );
  }

  /// 构建折线图层
  Widget _buildLineChartLayer(Map<DateTime, DailyLearningData> dailyData) {
    final entries = dailyData.entries.toList();
    
    // 计算最大柱状图高度，用于正确映射折线图位置
    final maxCount = dailyData.values.map((d) => d.totalLearningCount).fold(0, (a, b) => a > b ? a : b);
    const maxBarHeight = 100.0; // 与_buildStackedBar中的totalHeight保持一致（容器180-上下padding32*2=116，减去日期标签空间约100）
    
    // 如果没有学习记录，返回空的折线图
    if (maxCount == 0 || entries.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Positioned.fill(
      child: CustomPaint(
        painter: _LineChartPainter(
          entries: entries,
          minMastery: 0.0,  // 固定使用0%作为最小值
          maxMastery: 100.0, // 固定使用100%作为最大值
          maxBarHeight: maxBarHeight,
          context: context,
        ),
      ),
    );
  }

  /// 构建堆叠柱状图
  Widget _buildStackedBar(DailyLearningData data, int maxCount, [double totalHeight = 100.0]) {
    final barHeight = (data.totalLearningCount / maxCount * totalHeight);
    
    if (data.totalLearningCount == 0) {
      return Container(height: 2, color: AppTheme.coolGray200);
    }
    
    final total = data.totalLearningCount;
    final easyHeight = (data.easyCount / total) * barHeight;
    final goodHeight = (data.goodCount / total) * barHeight;
    final hardHeight = (data.hardCount / total) * barHeight;
    final forgotHeight = (data.forgotCount / total) * barHeight;
    
    return SizedBox(
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
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.mediumGray
                : AppTheme.coolGray500,
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
                Icon(Icons.psychology_outlined, size: 20, color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.mediumGray
                    : AppTheme.coolGray500),
                const SizedBox(width: 8),
                Text(
                  '学习表现统计',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
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
              color: AppTheme.getPrimaryTitleColor(context, lightColor: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.mediumGray
                    : AppTheme.coolGray500,
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







}