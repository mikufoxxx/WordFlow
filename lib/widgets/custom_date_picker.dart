import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';

/// 自定义日期选择器，显示每日单词数
class CustomDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Map<DateTime, int> dailyWordCounts;
  final Function(DateTime) onDateSelected;

  const CustomDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.dailyWordCounts,
    required this.onDateSelected,
  });

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selectedDate = widget.initialDate;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  bool _isDateSelectable(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    return widget.dailyWordCounts.containsKey(dateKey) || 
           dateKey.isAtSameMomentAs(todayKey);
  }

  int _getWordCount(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return widget.dailyWordCounts[dateKey] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardColor : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部 - 月份选择
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat('yyyy年MM月').format(_currentMonth),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.coolGray200 : AppTheme.coolGray700,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 星期标题
            Row(
              children: ['日', '一', '二', '三', '四', '五', '六']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppTheme.coolGray400 : AppTheme.coolGray500,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            
            const SizedBox(height: 8),
            
            // 日期网格
            _buildDateGrid(isDark),
            
            const SizedBox(height: 16),
            
            // 说明文字
            Text(
              '数字表示当日学习的单词数',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.coolGray400 : AppTheme.coolGray500,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark ? AppTheme.coolGray400 : AppTheme.coolGray600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDateSelected(_selectedDate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGray,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateGrid(bool isDark) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0=Sunday, 1=Monday, ...
    
    final days = <Widget>[];
    
    // 添加空白日期（上个月的日期）
    for (int i = 0; i < firstWeekday; i++) {
      days.add(const SizedBox());
    }
    
    // 添加当月日期
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isSelectable = _isDateSelectable(date);
      final wordCount = _getWordCount(date);
      final isSelected = date.day == _selectedDate.day && 
                         date.month == _selectedDate.month && 
                         date.year == _selectedDate.year;
      final isToday = _isToday(date);
      
      days.add(
        GestureDetector(
          onTap: isSelectable ? () {
            setState(() {
              _selectedDate = date;
            });
          } : null,
          child: Container(
            height: 50,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppTheme.primaryGray 
                  : isToday 
                      ? AppTheme.primaryGray.withOpacity(0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primaryGray, width: 1)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: !isSelectable 
                        ? (isDark ? AppTheme.coolGray600 : AppTheme.coolGray400)
                        : isSelected
                            ? Colors.white
                            : isToday
                                ? AppTheme.primaryGray
                                : (isDark ? AppTheme.coolGray200 : AppTheme.coolGray700),
                  ),
                ),
                if (wordCount > 0)
                  Text(
                    '$wordCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : AppTheme.accentGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 7,
      physics: const NeverScrollableScrollPhysics(),
      children: days,
    );
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year && 
           date.month == today.month && 
           date.day == today.day;
  }
} 