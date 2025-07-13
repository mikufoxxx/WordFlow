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
    final correctSessions = widget.record.sessions.where((s) => s.result.isCorrect).length;
    final successRate = totalSessions > 0 ? (correctSessions / totalSessions * 100) : 0;
    
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
            
            // 统计信息网格
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '总学习次数',
                    totalSessions.toString(),
                    Icons.school_outlined,
                    AppTheme.accentBlue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '正确次数',
                    correctSessions.toString(),
                    Icons.check_circle_outline,
                    AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '成功率',
                    '${successRate.toStringAsFixed(1)}%',
                    Icons.trending_up_outlined,
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
    if (widget.record.sessions.isEmpty) {
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

    // 按时间排序学习记录
    final sortedSessions = [...widget.record.sessions];
    sortedSessions.sort((a, b) => a.sessionTime.compareTo(b.sessionTime));

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
              itemCount: sortedSessions.length,
              itemBuilder: (context, index) {
                final session = sortedSessions[index];
                final isLast = index == sortedSessions.length - 1;
                
                return _buildTimelineItem(session, isLast);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建时间轴项目
  Widget _buildTimelineItem(DetailedLearningSession session, bool isLast) {
    final color = session.result.isCorrect ? AppTheme.accentGreen : AppTheme.accentRed;
    
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
                height: 60,
                color: AppTheme.coolGray200,
              ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        // 内容
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 时间和模式
                Row(
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(session.sessionTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.coolGray600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getLearningModeColor(session.learningMode).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.learningMode.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: _getLearningModeColor(session.learningMode),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // 结果和分数
                Row(
                  children: [
                    Icon(
                      session.result.isCorrect ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.result.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    if (session.score > 0) ...[
                      Icon(
                        Icons.star,
                        size: 14,
                        color: AppTheme.accentYellow,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${session.score}/10',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.coolGray600,
                        ),
                      ),
                    ],
                  ],
                ),
                
                // 用户输入（如果有）
                if (session.userInput != null && session.userInput!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.coolGray50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '造句：${session.userInput}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.coolGray700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                
                // 反馈信息（如果有）
                if (session.feedback != null && session.feedback!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.feedback!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.coolGray500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 获取学习模式颜色
  Color _getLearningModeColor(LearningMode mode) {
    switch (mode) {
      case LearningMode.quickMemory:
        return AppTheme.accentBlue;
      case LearningMode.deepLearning:
        return AppTheme.accentGreen;
      case LearningMode.review:
        return AppTheme.accentYellow;
      case LearningMode.test:
        return AppTheme.accentPurple;
      default:
        return AppTheme.accentBlue;
    }
  }
} 