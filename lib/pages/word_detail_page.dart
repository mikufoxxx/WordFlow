import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/word_learning_record.dart';
import '../models/detailed_learning_record.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';

/// 单词详情页面
/// 显示单词的完整学习历史和时间轴
class WordDetailPage extends StatefulWidget {
  final EnhancedWordLearningRecord record;
  
  const WordDetailPage({
    super.key,
    required this.record,
  });

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.record.word),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primaryGray),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 单词基本信息卡片
            _buildWordInfoCard(),
            
            const SizedBox(height: 20),
            
            // 学习状态概览
            _buildLearningOverview(),
            
            const SizedBox(height: 20),
            
            // 学习时间轴
            _buildLearningTimeline(),
          ],
        ),
      ),
    );
  }

  /// 构建单词基本信息卡片
  Widget _buildWordInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 单词和翻译
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.record.word,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.record.translation,
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.coolGray600,
                        ),
                      ),
                    ],
                  ),
                ),
                // 记忆程度标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.record.memoryLevel.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.record.memoryLevel.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.record.memoryLevel.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.record.memoryLevel.color,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 词书信息
            if (widget.record.wordBookName != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 16,
                    color: AppTheme.coolGray500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '来自词书：${widget.record.wordBookName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.coolGray600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建学习状态概览
  Widget _buildLearningOverview() {
    final totalSessions = widget.record.sessions.length;
    
    // 统计4分类
    final forgotCount = widget.record.forgotCount;
    final hardCount = widget.record.hardCount;
    final goodCount = widget.record.goodCount;
    final easyCount = widget.record.easyCount;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '学习概览',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 统计信息网格 - 第一行
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '总学习次数',
                    widget.record.learningCount.toString(),
                    Icons.school_outlined,
                    AppTheme.accentBlue,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showMasteryExplanation(),
                    child: _buildStatItem(
                      '掌握程度 ⓘ',
                      '${(widget.record.masteryPercentage * 100).toStringAsFixed(1)}%',
                      Icons.trending_up_outlined,
                      AppTheme.accentTeal,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 4分类统计 - 第二行
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '简单',
                    easyCount.toString(),
                    Icons.sentiment_very_satisfied_outlined,
                    AppTheme.accentGreen,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '良好',
                    goodCount.toString(),
                    Icons.sentiment_satisfied_outlined,
                    AppTheme.accentBlue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 4分类统计 - 第三行
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '困难',
                    hardCount.toString(),
                    Icons.sentiment_neutral_outlined,
                    AppTheme.accentYellow,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '忘记',
                    forgotCount.toString(),
                    Icons.sentiment_dissatisfied_outlined,
                    AppTheme.accentRed,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 学习时间信息
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '复习间隔',
                    '${widget.record.reviewInterval.toStringAsFixed(1)}天',
                    Icons.schedule_outlined,
                    AppTheme.accentTeal,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '学习天数',
                    widget.record.learningDays.toString(),
                    Icons.calendar_today_outlined,
                    AppTheme.accentYellow,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 掌握程度进度条
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '掌握程度',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.coolGray700,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: widget.record.masteryPercentage,
                  backgroundColor: AppTheme.coolGray200,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
                  minHeight: 8,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(widget.record.masteryPercentage * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.coolGray600,
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
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
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

  /// 构建学习时间轴
  Widget _buildLearningTimeline() {
    if (widget.record.reviewHistory.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.timeline_outlined,
                size: 48,
                color: AppTheme.coolGray400,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无学习记录',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.coolGray500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 按时间排序学习记录（最新的在上面）
    final sortedReviews = [...widget.record.reviewHistory];
    sortedReviews.sort((a, b) => b.reviewTime.compareTo(a.reviewTime));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '学习时间轴',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGray,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 时间轴列表
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedReviews.length,
              itemBuilder: (context, index) {
                final review = sortedReviews[index];
                final isLast = index == sortedReviews.length - 1;
                
                return _buildTimelineItem(review, isLast);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建时间轴项目
  Widget _buildTimelineItem(ReviewRecord review, bool isLast) {
    final color = _getReviewResultColor(review.reviewResult);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间轴线
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                color: AppTheme.coolGray200,
                child: const SizedBox(height: 50),
              ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        // 内容
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 时间
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(review.reviewTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.coolGray600,
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // 学习结果
                Row(
                  children: [
                    Icon(
                      _getReviewResultIcon(review.reviewResult),
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      review.reviewResult.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '复习间隔: ${review.reviewInterval.toStringAsFixed(1)}天',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.coolGray500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 获取复习结果颜色
  Color _getReviewResultColor(ReviewResult result) {
    switch (result) {
      case ReviewResult.easy:
        return AppTheme.accentGreen;
      case ReviewResult.good:
        return AppTheme.accentBlue;
      case ReviewResult.hard:
        return AppTheme.accentYellow;
      case ReviewResult.forgot:
        return AppTheme.accentRed;
    }
  }

  /// 获取复习结果图标
  IconData _getReviewResultIcon(ReviewResult result) {
    switch (result) {
      case ReviewResult.easy:
        return Icons.sentiment_very_satisfied_outlined;
      case ReviewResult.good:
        return Icons.sentiment_satisfied_outlined;
      case ReviewResult.hard:
        return Icons.sentiment_neutral_outlined;
      case ReviewResult.forgot:
        return Icons.sentiment_dissatisfied_outlined;
    }
  }

  /// 显示掌握程度计算说明
  void _showMasteryExplanation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('掌握程度计算说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('掌握程度基于你的学习表现综合计算：'),
            SizedBox(height: 12),
            Text('📊 基础分数（70%权重）：'),
            Text('  • 简单：3分'),
            Text('  • 良好：2分'),
            Text('  • 困难：1分'),
            Text('  • 忘记：0分'),
            SizedBox(height: 8),
            Text('🎯 记忆级别奖励（每级+5%）'),
            Text('⚡ 连续3次以上正确额外+15%'),
            SizedBox(height: 12),
            Text('掌握程度会随着学习表现实时更新，帮助你了解单词的熟练程度。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }
}