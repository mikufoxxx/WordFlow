// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/word_book.dart';
import '../utils/deepseek_api_service.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../utils/performance_optimizer.dart';

/// 造句测试页面
/// 用户需要用给定的单词造句，由 AI 接口判断句子的正确性
class SentenceTestPage extends StatefulWidget {
  final WordData wordData;
  final VoidCallback onNext;

  const SentenceTestPage({
    super.key,
    required this.wordData,
    required this.onNext,
  });

  @override
  State<SentenceTestPage> createState() => _SentenceTestPageState();
}

class _SentenceTestPageState extends State<SentenceTestPage> {
  final TextEditingController _sentenceController = TextEditingController();
  SentenceJudgmentResult? _judgmentResult;
  bool _isLoading = false;
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _sentenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkBackgroundColor
              : AppTheme.backgroundColor,
          appBar: AppBar(
            title: OptimizedText(
              '造句测试',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkPrimaryTextColor
                    : AppTheme.primaryTextColor,
              ),
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkBackgroundColor
                : AppTheme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkPrimaryGray
                    : AppTheme.primaryGray,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveHelper.getMaxContentWidth(context),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Container(
                  padding: ResponsiveHelper.getResponsivePadding(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWordCard(),
                      const SizedBox(height: 24),
                      _buildInstructionCard(),
                      const SizedBox(height: 24),
                      _buildSentenceInput(),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                      if (_judgmentResult != null) ...[
                        const SizedBox(height: 24),
                        _buildJudgmentResult(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建单词卡片
  Widget _buildWordCard() {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: AppTheme.primaryGray,
                  size: 24,
                ),
                const SizedBox(width: 12),
                OptimizedText(
                  '目标单词',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coolGray600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OptimizedText(
              widget.wordData.word,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGray,
              ),
            ),
            const SizedBox(height: 8),
            OptimizedText(
              widget.wordData.translation,
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.coolGray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建说明卡片
  Widget _buildInstructionCard() {
    return Card(
      color: AppTheme.coolGray50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.accentGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                OptimizedText(
                  '造句要求',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coolGray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OptimizedText(
              '• 请用上面的单词造一个英语句子\n• 语法正确，用法恰当\n• 句子意思清晰，符合英语表达习惯',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.coolGray600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建句子输入框
  Widget _buildSentenceInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OptimizedText(
          '您的造句',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.coolGray700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sentenceController,
          maxLines: 4,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: '请输入您的英语句子...',
            hintStyle: TextStyle(
              color: AppTheme.coolGray400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.coolGray300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGray, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
            filled: true,
            fillColor: AppTheme.cardColor,
          ),
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// 构建提交按钮
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitSentence,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGray,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : OptimizedText(
                _hasSubmitted ? '重新测试' : '提交判断',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// 构建判断结果
  Widget _buildJudgmentResult() {
    if (_judgmentResult == null) return const SizedBox();

    final result = _judgmentResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 判断结果卡片
        Card(
          color: result.isCorrect
              ? (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkAccentGreen.withOpacity(0.1)
                  : AppTheme.accentGreen.withOpacity(0.1))
              : (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkAccentRed.withOpacity(0.1)
                  : AppTheme.accentRed.withOpacity(0.1)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      result.isCorrect ? Icons.check_circle : Icons.error,
                      color: result.isCorrect
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkAccentGreen
                              : AppTheme.accentGreen)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkAccentRed
                              : AppTheme.accentRed),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    OptimizedText(
                      result.isCorrect ? '句子正确！' : '需要改进',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: result.isCorrect
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkAccentGreen
                                : AppTheme.accentGreen)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkAccentRed
                                : AppTheme.accentRed),
                      ),
                    ),
                    if (result.score > 0) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: result.isCorrect
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.darkAccentGreen
                                  : AppTheme.accentGreen)
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.darkAccentOrange
                                  : AppTheme.accentOrange),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: OptimizedText(
                          '${result.score}分',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (result.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  OptimizedText(
                    result.errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkAccentRed
                          : AppTheme.accentRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 错误信息
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      OptimizedText(
                        '发现问题',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...result.errors.map((error) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: OptimizedText(
                          '• $error',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],

        // 建议
        if (result.suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      OptimizedText(
                        '修改建议',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...result.suggestions.map((suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: OptimizedText(
                          '• $suggestion',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],

        // 更好的句子示例
        if (result.betterSentences.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: AppTheme.coolGray50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: AppTheme.accentGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      OptimizedText(
                        '参考句子',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.coolGray700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...result.betterSentences.map((sentence) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.coolGray200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OptimizedText(
                                sentence,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.coolGray700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: sentence));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OptimizedText(
                                            '已复制到剪贴板',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppTheme.darkCardColor
                                            : AppTheme.cardColor,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              color: AppTheme.coolGray500,
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],

        // 操作按钮
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppTheme.coolGray300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const OptimizedText('返回'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const OptimizedText('下一个单词'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 提交句子进行判断
  Future<void> _submitSentence() async {
    final sentence = _sentenceController.text.trim();
    if (sentence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.warning_outlined,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OptimizedText(
                  '请输入您的句子',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
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

    setState(() {
      _isLoading = true;
      _judgmentResult = null;
    });

    try {
      final result = await DeepSeekApiService.judgeSentence(
        word: widget.wordData.word,
        sentence: sentence,
        translation: widget.wordData.translation,
      );

      setState(() {
        _judgmentResult = result;
        _hasSubmitted = true;
      });

      // 触觉反馈
      if (result?.isCorrect == true) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OptimizedText(
                  'AI 分析失败: $e',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
