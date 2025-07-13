import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/word_learning_record.dart';
import '../utils/learning_data_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/spaced_repetition_service.dart';
import '../utils/cache_service.dart';

/// 单词回溯页面
/// 显示用户背过的单词记录和掌握程度
class WordReviewPage extends StatefulWidget {
  const WordReviewPage({super.key});

  @override
  State<WordReviewPage> createState() => _WordReviewPageState();
}

class _WordReviewPageState extends State<WordReviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // 数据状态
  List<WordLearningRecord> _allRecords = [];
  List<WordLearningRecord> _filteredRecords = [];
  LearningStats? _stats;
  bool _isLoading = true;
  
  // 筛选状态
  MemoryLevel? _selectedLevel;
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
        final stats = await LearningDataService.instance.getLearningStats(selectedWordBook);
        
        setState(() {
          _allRecords = records;
          _stats = stats;
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
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              '单词回溯',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                onPressed: _exportData,
                tooltip: '导出数据',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: '刷新',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
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
                    _buildStatsTab(),
                  ],
                ),
        );
      },
    );
  }

  /// 构建单词列表标签页
  Widget _buildWordListTab() {
    return Column(
      children: [
        // 搜索和筛选栏
        _buildSearchAndFilter(),
        
        // 单词列表
        Expanded(
          child: _filteredRecords.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _filteredRecords.length,
                  itemBuilder: (context, index) {
                    return _buildWordCard(_filteredRecords[index]);
                  },
                ),
        ),
      ],
    );
  }

  /// 构建搜索和筛选栏
  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索单词或翻译...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 筛选选项
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 记忆程度筛选
                _buildFilterChip(
                  label: '全部程度',
                  isSelected: _selectedLevel == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLevel = selected ? null : _selectedLevel;
                      _filterRecords();
                    });
                  },
                ),
                
                const SizedBox(width: 8),
                
                ...MemoryLevel.values.map((level) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    label: level.displayName,
                    isSelected: _selectedLevel == level,
                    color: level.color,
                    onSelected: (selected) {
                      setState(() {
                        _selectedLevel = selected ? level : null;
                        _filterRecords();
                      });
                    },
                  ),
                )),
                
                const SizedBox(width: 8),
                
                // 到期单词筛选
                _buildFilterChip(
                  label: '需要复习',
                  isSelected: _showOnlyDueWords,
                  color: Colors.orange,
                  onSelected: (selected) {
                    setState(() {
                      _showOnlyDueWords = selected;
                      _filterRecords();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建筛选芯片
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    Color? color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: color?.withOpacity(0.1),
      selectedColor: color?.withOpacity(0.3) ?? Theme.of(context).primaryColor.withOpacity(0.3),
      checkmarkColor: color ?? Theme.of(context).primaryColor,
    );
  }

  /// 构建单词卡片
  Widget _buildWordCard(WordLearningRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: record.memoryLevel.color,
          child: Text(
            record.memoryLevel.displayName[0],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          record.word,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.translation),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  record.needsReview ? Icons.warning : Icons.check_circle,
                  size: 16,
                  color: record.needsReview ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  record.needsReview ? '需要复习' : '已复习',
                  style: TextStyle(
                    color: record.needsReview ? Colors.orange : Colors.green,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '掌握度: ${(record.masteryPercentage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showWordDetails(record),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedLevel != null || _showOnlyDueWords
                ? '没有找到匹配的单词'
                : '还没有学习记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedLevel != null || _showOnlyDueWords
                ? '尝试调整搜索条件或筛选器'
                : '开始学习单词后，这里会显示你的学习记录',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计标签页
  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(child: Text('暂无统计数据'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总体统计
          _buildStatsCard(
            title: '总体统计',
            children: [
              _buildStatItem('总单词数', _stats!.totalWords.toString()),
              _buildStatItem('今日复习', _stats!.todayReviews.toString()),
              _buildStatItem('待复习', _stats!.dueWords.toString()),
              _buildStatItem('学习天数', _stats!.learningDays.toString()),
              _buildStatItem('总体掌握度', '${(_stats!.overallMastery * 100).toStringAsFixed(1)}%'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 记忆程度分布
          _buildStatsCard(
            title: '记忆程度分布',
            children: MemoryLevel.values.map((level) {
              final count = _stats!.levelStats[level] ?? 0;
              final percentage = _stats!.totalWords > 0 
                  ? (count / _stats!.totalWords * 100).toStringAsFixed(1)
                  : '0.0';
              
              return _buildStatItem(
                level.displayName,
                '$count 个 ($percentage%)',
                color: level.color,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // 学习进度图表
          _buildProgressChart(),
        ],
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (color != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// 构建进度图表
  Widget _buildProgressChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '掌握程度分布',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 简单的条形图
            ...MemoryLevel.values.map((level) {
              final count = _stats!.levelStats[level] ?? 0;
              final percentage = _stats!.totalWords > 0 
                  ? count / _stats!.totalWords
                  : 0.0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(level.displayName),
                        Text('$count'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(level.color),
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 显示单词详情
  void _showWordDetails(WordLearningRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.word),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('翻译: ${record.translation}'),
              const SizedBox(height: 8),
              Text('记忆程度: ${record.memoryLevel.displayName}'),
              const SizedBox(height: 8),
              Text('学习次数: ${record.learningCount}'),
              const SizedBox(height: 8),
              Text('正确次数: ${record.correctCount}'),
              const SizedBox(height: 8),
              Text('错误次数: ${record.incorrectCount}'),
              const SizedBox(height: 8),
              Text('掌握程度: ${(record.masteryPercentage * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              Text('首次学习: ${DateFormat('yyyy-MM-dd HH:mm').format(record.firstLearningTime)}'),
              const SizedBox(height: 8),
              Text('最后学习: ${DateFormat('yyyy-MM-dd HH:mm').format(record.lastLearningTime)}'),
              const SizedBox(height: 8),
              Text('下次复习: ${DateFormat('yyyy-MM-dd HH:mm').format(record.nextReviewTime)}'),
              const SizedBox(height: 8),
              Text('复习间隔: ${record.reviewInterval.toStringAsFixed(1)} 天'),
              const SizedBox(height: 8),
              Text('难度系数: ${record.easeFactor.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('学习天数: ${record.learningDays}'),
              
              if (record.reviewHistory.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '复习历史:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...record.reviewHistory.take(5).map((review) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${DateFormat('MM-dd HH:mm').format(review.reviewTime)} - ${review.reviewResult.displayName}',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
                if (record.reviewHistory.length > 5)
                  Text(
                    '... 还有 ${record.reviewHistory.length - 5} 条记录',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 导出数据
  Future<void> _exportData() async {
    if (_currentWordBook.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有选择词书')),
      );
      return;
    }

    try {
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

      final filePath = await LearningDataService.instance.exportLearningDataToCsv(_currentWordBook);
      
      Navigator.of(context).pop(); // 关闭加载对话框
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('数据已导出到: $filePath'),
          duration: const Duration(seconds: 5),
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
} 