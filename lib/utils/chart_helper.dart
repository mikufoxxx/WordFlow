import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/detailed_learning_record.dart';
import '../models/word_learning_record.dart';
import 'app_theme.dart';

/// 图表工具类
/// 用于生成各种学习数据的可视化图表
class ChartHelper {
  /// 生成学习进度折线图
  static Widget buildProgressChart(List<EnhancedWordLearningRecord> records) {
    if (records.isEmpty) return const SizedBox();
    
    // 按日期分组统计
    final progressData = _getProgressData(records);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.coolGray200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: AppTheme.coolGray600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < progressData.length) {
                    return Text(
                      DateFormat('MM/dd').format(progressData[value.toInt()].date),
                      style: TextStyle(
                        color: AppTheme.coolGray600,
                        fontSize: 12,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: AppTheme.coolGray200),
          ),
          minX: 0,
          maxX: (progressData.length - 1).toDouble(),
          minY: 0,
          maxY: progressData.isNotEmpty 
              ? progressData.map((e) => e.count).reduce((a, b) => a > b ? a : b).toDouble() * 1.2
              : 100,
          lineBarsData: [
            LineChartBarData(
              spots: progressData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentBlue.withOpacity(0.8),
                  AppTheme.accentBlue,
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.accentBlue,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentBlue.withOpacity(0.3),
                    AppTheme.accentBlue.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 生成难度分布饼图
  static Widget buildDifficultyPieChart(List<EnhancedWordLearningRecord> records) {
    if (records.isEmpty) return const SizedBox();
    
    final difficultyStats = _getDifficultyStats(records);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: PieChart(
        PieChartData(
          sections: difficultyStats.entries.map((entry) {
            final percentage = entry.value / records.length;
            return PieChartSectionData(
              color: _getDifficultyColor(entry.key),
              value: entry.value.toDouble(),
              title: '${(percentage * 100).toStringAsFixed(1)}%',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  /// 生成记忆程度柱状图
  static Widget buildMemoryLevelChart(List<EnhancedWordLearningRecord> records) {
    if (records.isEmpty) return const SizedBox();
    
    final memoryStats = _getMemoryStats(records);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: memoryStats.values.isNotEmpty 
              ? memoryStats.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2
              : 10,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.black87,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()}个',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final levels = MemoryLevel.values;
                  if (value.toInt() >= 0 && value.toInt() < levels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        levels[value.toInt()].displayName,
                        style: TextStyle(
                          color: AppTheme.coolGray600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: AppTheme.coolGray600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: AppTheme.coolGray200),
          ),
          barGroups: MemoryLevel.values.asMap().entries.map((entry) {
            final level = entry.value;
            final count = memoryStats[level] ?? 0;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: level.color,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 生成学习模式分布图
  static Widget buildLearningModeChart(List<EnhancedWordLearningRecord> records) {
    if (records.isEmpty) return const SizedBox();
    
    final modeStats = _getLearningModeStats(records);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: PieChart(
        PieChartData(
          sections: modeStats.entries.map((entry) {
            final percentage = entry.value / records.length;
            return PieChartSectionData(
              color: _getLearningModeColor(entry.key),
              value: entry.value.toDouble(),
              title: '${(percentage * 100).toStringAsFixed(1)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          centerSpaceRadius: 50,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  /// 生成学习成绩趋势图
  static Widget buildScoreTrendChart(List<EnhancedWordLearningRecord> records) {
    if (records.isEmpty) return const SizedBox();
    
    final scoreData = _getScoreTrendData(records);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.coolGray200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: AppTheme.coolGray600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < scoreData.length) {
                    return Text(
                      DateFormat('MM/dd').format(scoreData[value.toInt()].date),
                      style: TextStyle(
                        color: AppTheme.coolGray600,
                        fontSize: 12,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: AppTheme.coolGray200),
          ),
          minX: 0,
          maxX: (scoreData.length - 1).toDouble(),
          minY: 0,
          maxY: 10,
          lineBarsData: [
            LineChartBarData(
              spots: scoreData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.score);
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentGreen.withOpacity(0.8),
                  AppTheme.accentGreen,
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.accentGreen,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentGreen.withOpacity(0.3),
                    AppTheme.accentGreen.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取学习进度数据
  static List<_ProgressData> _getProgressData(List<EnhancedWordLearningRecord> records) {
    final Map<String, int> dailyProgress = {};
    
    for (final record in records) {
      final dateKey = DateFormat('yyyy-MM-dd').format(record.lastLearningTime);
      dailyProgress[dateKey] = (dailyProgress[dateKey] ?? 0) + 1;
    }
    
    final sortedEntries = dailyProgress.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    return sortedEntries.map((entry) {
      return _ProgressData(
        date: DateTime.parse(entry.key),
        count: entry.value,
      );
    }).toList();
  }

  /// 获取难度统计数据
  static Map<WordDifficulty, int> _getDifficultyStats(List<EnhancedWordLearningRecord> records) {
    final Map<WordDifficulty, int> stats = {};
    
    for (final record in records) {
      stats[record.difficulty] = (stats[record.difficulty] ?? 0) + 1;
    }
    
    return stats;
  }

  /// 获取记忆程度统计数据
  static Map<MemoryLevel, int> _getMemoryStats(List<EnhancedWordLearningRecord> records) {
    final Map<MemoryLevel, int> stats = {};
    
    for (final record in records) {
      stats[record.memoryLevel] = (stats[record.memoryLevel] ?? 0) + 1;
    }
    
    return stats;
  }

  /// 获取学习模式统计数据
  static Map<LearningMode, int> _getLearningModeStats(List<EnhancedWordLearningRecord> records) {
    final Map<LearningMode, int> stats = {};
    
    for (final record in records) {
      for (final session in record.sessions) {
        stats[session.learningMode] = (stats[session.learningMode] ?? 0) + 1;
      }
    }
    
    return stats;
  }

  /// 获取分数趋势数据
  static List<_ScoreData> _getScoreTrendData(List<EnhancedWordLearningRecord> records) {
    final Map<String, List<double>> dailyScores = {};
    
    for (final record in records) {
      for (final session in record.sessions) {
        final dateKey = DateFormat('yyyy-MM-dd').format(session.sessionTime);
        if (!dailyScores.containsKey(dateKey)) {
          dailyScores[dateKey] = [];
        }
        dailyScores[dateKey]!.add(session.score.toDouble());
      }
    }
    
    final sortedEntries = dailyScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    return sortedEntries.map((entry) {
      final avgScore = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return _ScoreData(
        date: DateTime.parse(entry.key),
        score: avgScore,
      );
    }).toList();
  }

  /// 获取难度对应颜色
  static Color _getDifficultyColor(WordDifficulty difficulty) {
    switch (difficulty) {
      case WordDifficulty.known:
        return AppTheme.accentGreen;
      case WordDifficulty.unknown:
        return AppTheme.accentRed;
    }
  }

  /// 获取学习模式对应颜色
  static Color _getLearningModeColor(LearningMode mode) {
    switch (mode) {
      case LearningMode.quickMemory:
        return AppTheme.accentYellow;
      case LearningMode.deepLearning:
        return AppTheme.accentBlue;
      case LearningMode.review:
        return AppTheme.accentGreen;
      case LearningMode.test:
        return AppTheme.accentPurple;
    }
  }
}

/// 进度数据
class _ProgressData {
  final DateTime date;
  final int count;

  _ProgressData({required this.date, required this.count});
}

/// 分数数据
class _ScoreData {
  final DateTime date;
  final double score;

  _ScoreData({required this.date, required this.score});
} 