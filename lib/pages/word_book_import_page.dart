import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/word_book.dart';
import '../utils/ai_word_book_import_service.dart';
import '../utils/app_theme.dart';
import '../utils/cache_service.dart';
import '../utils/file_helper.dart';
import '../utils/llm_api_service.dart';
import '../utils/settings_helper.dart';
import '../widgets/acrylic_app_bar.dart';

class WordBookImportPage extends StatefulWidget {
  const WordBookImportPage({super.key});

  @override
  State<WordBookImportPage> createState() => _WordBookImportPageState();
}

class _WordBookImportPageState extends State<WordBookImportPage> {
  final TextEditingController _bookNameController = TextEditingController();

  PlatformFile? _selectedFile;
  _WordBookImportPreview? _preview;
  bool _isParsing = false;
  bool _isAiAnalyzing = false;
  bool _isImporting = false;
  bool _hasUsableAiConfig = false;
  bool _aiAutoParseEnabled = true;

  @override
  void initState() {
    super.initState();
    _bookNameController.addListener(_handleBookNameChanged);
    _loadAiAvailability();
  }

  @override
  void dispose() {
    _bookNameController
      ..removeListener(_handleBookNameChanged)
      ..dispose();
    super.dispose();
  }

  void _handleBookNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAiAvailability() async {
    final hasUsableAiConfig = await LlmApiService.hasUsableConfig();
    final aiAutoParseEnabled = await SettingsHelper.getAiAutoParseEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasUsableAiConfig = hasUsableAiConfig;
      _aiAutoParseEnabled = aiAutoParseEnabled;
    });
  }

  bool get _canUseAiAutoParse {
    return _hasUsableAiConfig && _aiAutoParseEnabled;
  }

  Future<void> _pickFileAndParse() async {
    if (_isParsing || _isAiAnalyzing || _isImporting) {
      return;
    }

    try {
      setState(() {
        _isParsing = true;
        _isAiAnalyzing = false;
      });

      final selectedFile = await FileHelper.selectImportFile();
      if (selectedFile == null) {
        if (!mounted) {
          return;
        }
        _showSnackBar(
          message: '未选择文件',
          icon: Icons.info_outline_rounded,
        );
        return;
      }

      final rawContent = await _readSelectedFile(selectedFile);
      _WordBookImportPreview preview;
      String suggestedBookName = _suggestWordBookName(selectedFile.name);

      try {
        preview = _parseWordBookContent(rawContent);
      } catch (localError) {
        if (!_canUseAiAutoParse) {
          rethrow;
        }

        if (mounted) {
          setState(() {
            _isAiAnalyzing = true;
          });
        }

        final aiResult = await AiWordBookImportService.analyzeAndTransform(
          rawContent: rawContent,
          fileName: selectedFile.name,
        );
        preview = _buildAiPreview(aiResult);
        suggestedBookName = aiResult.bookNameSuggestion;

        if (mounted) {
          _showSnackBar(
            message: '标准解析失败，已通过 AI 自动生成兼容转换脚本',
            icon: Icons.auto_awesome_rounded,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedFile = selectedFile;
        _preview = preview;
        if (_bookNameController.text.trim().isEmpty) {
          _bookNameController.text = suggestedBookName;
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        message: e.toString().replaceFirst('Exception: ', ''),
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isParsing = false;
          _isAiAnalyzing = false;
        });
      }
    }
  }

  Future<String> _readSelectedFile(PlatformFile selectedFile) async {
    if (selectedFile.bytes != null) {
      return utf8.decode(selectedFile.bytes!);
    }
    if (selectedFile.path != null) {
      return FileHelper.readFile(selectedFile.path!);
    }
    throw Exception('无法读取所选文件内容');
  }

  _WordBookImportPreview _parseWordBookContent(String rawContent) {
    final rawLines = const LineSplitter().convert(rawContent);
    final words = <WordData>[];
    final samples = <WordData>[];
    final seenWords = <String>{};
    int duplicateCount = 0;

    for (int index = 0; index < rawLines.length; index++) {
      final line = rawLines[index].trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }

      if (words.isEmpty && _looksLikeHeader(line)) {
        continue;
      }

      final separatorIndex = _resolveSeparatorIndex(line);
      if (separatorIndex < 0) {
        throw Exception('第 ${index + 1} 行格式不正确，请使用“单词,释义”格式');
      }

      final word = line.substring(0, separatorIndex).trim();
      final translation = line.substring(separatorIndex + 1).trim();

      if (word.isEmpty || translation.isEmpty) {
        throw Exception('第 ${index + 1} 行存在空白字段，请检查内容');
      }

      final normalizedWord = word.toLowerCase();
      if (!seenWords.add(normalizedWord)) {
        duplicateCount++;
        continue;
      }

      final item = WordData(word: word, translation: translation);
      words.add(item);
      if (samples.length < 6) {
        samples.add(item);
      }
    }

    if (words.isEmpty) {
      throw Exception('没有解析到有效单词，请确认文件为 UTF-8 编码且内容符合格式');
    }

    return _WordBookImportPreview(
      words: words,
      sampleWords: samples,
      duplicateCount: duplicateCount,
      lineCount: rawLines.where((line) => line.trim().isNotEmpty).length,
    );
  }

  _WordBookImportPreview _buildAiPreview(AiWordBookImportResult result) {
    return _WordBookImportPreview(
      words: result.words,
      sampleWords: result.sampleWords,
      duplicateCount: result.duplicateCount,
      lineCount: result.lineCount,
      usedAi: true,
      aiSummary: result.summary,
      scriptPreview: AiWordBookImportService.prettyPrintScript(result.script),
    );
  }

  bool _looksLikeHeader(String line) {
    final normalized = line.toLowerCase();
    return (normalized.contains('word') || normalized.contains('单词')) &&
        (normalized.contains('translation') ||
            normalized.contains('释义') ||
            normalized.contains('中文') ||
            normalized.contains('含义'));
  }

  int _resolveSeparatorIndex(String line) {
    final commaIndex = line.indexOf(',');
    final tabIndex = line.indexOf('\t');

    if (commaIndex == -1 && tabIndex == -1) {
      return -1;
    }
    if (commaIndex == -1) {
      return tabIndex;
    }
    if (tabIndex == -1) {
      return commaIndex;
    }
    return commaIndex < tabIndex ? commaIndex : tabIndex;
  }

  String _suggestWordBookName(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, lastDotIndex);
  }

  Future<void> _importWordBook() async {
    final preview = _preview;
    if (preview == null) {
      _showSnackBar(
        message: '请先选择符合格式的词库文件',
        icon: Icons.warning_amber_rounded,
        isError: true,
      );
      return;
    }

    final bookName = _bookNameController.text.trim();
    if (bookName.isEmpty) {
      _showSnackBar(
        message: '请先填写单词本名称',
        icon: Icons.edit_note_rounded,
        isError: true,
      );
      return;
    }

    final shouldContinue = await _confirmDuplicateImport(bookName);
    if (!shouldContinue) {
      return;
    }

    try {
      setState(() {
        _isImporting = true;
      });

      _showImportingDialog();

      final importedBook = WordBook(
        name: bookName,
        translationUrl: 'import://$bookName',
        wordCount: preview.words.length,
      );

      await CacheService.saveCustomWordBook(importedBook, preview.words);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      _showSnackBar(
        message: '已导入《$bookName》，共 ${preview.words.length} 个单词',
        icon: Icons.library_add_check_rounded,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      _showSnackBar(
        message: '导入失败：${e.toString().replaceFirst('Exception: ', '')}',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<bool> _confirmDuplicateImport(String bookName) async {
    final remoteBooks = await CacheService.getCachedWordBooks();
    final customBooks = await CacheService.getCustomWordBooks();
    final hasDuplicate = [...remoteBooks, ...customBooks].any(
      (book) => book.name == bookName,
    );

    if (!hasDuplicate || !mounted) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现同名单词本'),
        content: Text('《$bookName》已存在，继续导入后会使用你本次导入的数据覆盖展示，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续导入'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showImportingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在导入单词本...'),
          ],
        ),
      ),
    );
  }

  void _showSnackBar({
    required String message,
    required IconData icon,
    bool isError = false,
  }) {
    final brightness = Theme.of(context).brightness;
    final foregroundColor =
        brightness == Brightness.dark ? Colors.white : Colors.black87;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          content: Row(
            children: [
              Icon(
                icon,
                color: isError ? Colors.redAccent : foregroundColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.darkAccentGreen : AppTheme.accentGreen;
    final secondaryColor =
        isDarkMode ? AppTheme.darkAccentBlue : AppTheme.accentBlue;
    final tertiaryColor =
        isDarkMode ? AppTheme.darkAccentOrange : AppTheme.accentTeal;
    final isPickingFile = _isParsing || _isAiAnalyzing;
    final isImportEnabled = !_isImporting &&
        !isPickingFile &&
        _preview != null &&
        _bookNameController.text.trim().isNotEmpty;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AcrylicAppBar(
        title: '导入单词本',
        leading: IconButton(
          key: const Key('wordBookImportBackButton'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primaryGray,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 900 ? 24.0 : 16.0;
          final bottomInset = MediaQuery.of(context).padding.bottom;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              24 + bottomInset,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      key: const Key('wordBookImportIntroCard'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.upload_file_rounded,
                                  color: primaryColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '导入你自己的单词本',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _canUseAiAutoParse
                                          ? '支持按当前词库格式导入本地 .csv / .txt 文件；若格式复杂或不兼容，将自动调用 AI 生成转换脚本并完成适配。'
                                          : _hasUsableAiConfig
                                              ? '当前已配置 AI，但自动解析开关已关闭，将仅按标准格式进行本地解析。'
                                              : '支持按当前词库格式导入本地 .csv / .txt 文件。导入后会直接出现在词库页，并作为已下载词库可立即使用。',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.8),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              const _FormatHintChip(
                                icon: Icons.table_rows_rounded,
                                label: '两列结构',
                              ),
                              const _FormatHintChip(
                                icon: Icons.translate_rounded,
                                label: '单词 + 释义',
                              ),
                              const _FormatHintChip(
                                icon: Icons.verified_rounded,
                                label: 'UTF-8 编码推荐',
                              ),
                              if (_canUseAiAutoParse)
                                const _FormatHintChip(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'AI 智能适配',
                                ),
                              if (_canUseAiAutoParse)
                                const _FormatHintChip(
                                  icon: Icons.toll_rounded,
                                  label: '可能产生 token',
                                ),
                            ],
                          ),
                          if (_hasUsableAiConfig) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: tertiaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: tertiaryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _aiAutoParseEnabled
                                        ? Icons.info_outline_rounded
                                        : Icons.toggle_off_rounded,
                                    color: tertiaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _aiAutoParseEnabled
                                          ? '已开启 AI 自动解析：仅当标准格式解析失败时才会触发，可能产生 token 消耗。你可以在设置页的 AI 设置中随时关闭。'
                                          : 'AI 自动解析当前已关闭：本页只会执行本地标准格式解析，不会自动触发 AI，也不会产生额外 token 消耗。',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.textTheme.bodySmall?.color
                                            ?.withValues(alpha: 0.86),
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionCard(
                      key: Key('wordBookImportFormatCard'),
                      child: _ImportFormatContent(),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      key: const Key('wordBookImportNameCard'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '单词本名称',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('wordBookImportNameField'),
                            controller: _bookNameController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: '例如：我的考研高频词',
                              prefixIcon: Icon(Icons.menu_book_rounded),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '默认会使用文件名作为名称，你也可以手动修改。若与已有词库同名，导入时会进行确认。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.75),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      key: const Key('wordBookImportFileCard'),
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
                                      '选择导入文件',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _selectedFile == null
                                          ? '请先选择一个符合标准格式的文件'
                                          : '${_selectedFile!.name} · ${FileHelper.getFileSizeString(_selectedFile!.size)}',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.78),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              FilledButton.tonalIcon(
                                key: const Key('wordBookImportPickFileButton'),
                                onPressed:
                                    isPickingFile ? null : _pickFileAndParse,
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDarkMode
                                      ? AppTheme.accentGreen
                                          .withValues(alpha: 0.16)
                                      : AppTheme.accentGreen
                                          .withValues(alpha: 0.1),
                                  foregroundColor: isDarkMode
                                      ? AppTheme.darkPrimaryTextColor
                                      : AppTheme.primaryTextColor,
                                  disabledBackgroundColor: isDarkMode
                                      ? AppTheme.coolGray800
                                      : AppTheme.coolGray100,
                                  disabledForegroundColor: isDarkMode
                                      ? AppTheme.coolGray500
                                      : AppTheme.coolGray500,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                      color: isDarkMode
                                          ? AppTheme.accentGreen
                                              .withValues(alpha: 0.24)
                                          : AppTheme.accentGreen
                                              .withValues(alpha: 0.18),
                                    ),
                                  ),
                                ),
                                icon: isPickingFile
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.attach_file_rounded),
                                label: Text(
                                  _isAiAnalyzing
                                      ? 'AI 适配中'
                                      : (_isParsing ? '解析中' : '选择文件'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _canUseAiAutoParse
                                ? '标准格式会优先本地解析；遇到复杂格式时会自动使用 AI 生成兼容转换脚本，可能产生 token 消耗。'
                                : _hasUsableAiConfig
                                    ? '当前 AI 自动解析已关闭，将仅按标准格式进行本地解析。'
                                    : '当前未检测到可用 AI 配置，将仅按标准格式进行本地解析。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.75),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_preview != null) ...[
                      const SizedBox(height: 16),
                      _SectionCard(
                        key: const Key('wordBookImportPreviewCard'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '导入预览',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_preview!.usedAi) ...[
                              _AiInsightCard(
                                summary: _preview!.aiSummary,
                                scriptPreview: _preview!.scriptPreview,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _PreviewMetricChip(
                                  label: '有效单词',
                                  value: '${_preview!.words.length}',
                                  color: primaryColor,
                                ),
                                _PreviewMetricChip(
                                  label: '非空行数',
                                  value: '${_preview!.lineCount}',
                                  color: secondaryColor,
                                ),
                                _PreviewMetricChip(
                                  label: '重复已跳过',
                                  value: '${_preview!.duplicateCount}',
                                  color: tertiaryColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: isDarkMode
                                    ? AppTheme.coolGray800
                                        .withValues(alpha: 0.72)
                                    : AppTheme.coolGray50,
                                border: Border.all(
                                  color: isDarkMode
                                      ? AppTheme.coolGray700
                                      : AppTheme.coolGray200,
                                ),
                              ),
                              child: Column(
                                children: _preview!.sampleWords
                                    .map(
                                      (item) => ListTile(
                                        key: ValueKey<String>(
                                            'preview_${item.word}'),
                                        leading: CircleAvatar(
                                          backgroundColor: primaryColor
                                              .withValues(alpha: 0.12),
                                          foregroundColor: primaryColor,
                                          child: Text(
                                            item.word.characters.first
                                                .toUpperCase(),
                                          ),
                                        ),
                                        title: Text(
                                          item.word,
                                          style: TextStyle(
                                            color: AppTheme.getPrimaryTextColor(
                                                context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          item.translation,
                                          style: TextStyle(
                                            color:
                                                AppTheme.getSecondaryTextColor(
                                                    context),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            if (_preview!.words.length >
                                _preview!.sampleWords.length)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  '仅展示前 ${_preview!.sampleWords.length} 条，实际将导入 ${_preview!.words.length} 个单词。',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('wordBookImportSubmitButton'),
                      onPressed: isImportEnabled ? _importWordBook : null,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.file_upload_rounded),
                      label: const Text('导入到词库'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDarkMode
                            ? AppTheme.coolGray700
                            : AppTheme.coolGray300,
                        disabledForegroundColor: isDarkMode
                            ? AppTheme.coolGray400
                            : AppTheme.coolGray500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImportFormatContent extends StatelessWidget {
  const _ImportFormatContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标准格式说明',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '推荐与当前词库保持一致：每行一条数据，第一列是英文单词，第二列是中文释义。首行表头可选。',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isDarkMode
                ? AppTheme.coolGray800.withValues(alpha: 0.72)
                : AppTheme.coolGray50,
            border: Border.all(
              color: isDarkMode ? AppTheme.coolGray700 : AppTheme.coolGray200,
            ),
          ),
          child: const SelectableText(
            'word,translation\nabandon,放弃\nability,能力\nachieve,实现',
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Column(
          children: [
            _FormatBullet(text: '支持 .csv 与 .txt 文件'),
            _FormatBullet(text: '允许首行使用 word,translation 作为表头'),
            _FormatBullet(text: '支持使用英文逗号或 Tab 分隔两列'),
            _FormatBullet(text: '重复单词会自动跳过，仅保留第一条'),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? AppTheme.coolGray700.withValues(alpha: 0.45)
              : AppTheme.coolGray200.withValues(alpha: 0.8),
        ),
        boxShadow: theme.brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class _FormatHintChip extends StatelessWidget {
  const _FormatHintChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Chip(
      backgroundColor: isDarkMode ? AppTheme.coolGray800 : AppTheme.lightGray,
      side: BorderSide(
        color: isDarkMode ? AppTheme.coolGray700 : AppTheme.coolGray200,
      ),
      avatar: Icon(
        icon,
        size: 18,
        color: AppTheme.accentGreen,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: AppTheme.getPrimaryTextColor(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _PreviewMetricChip extends StatelessWidget {
  const _PreviewMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _FormatBullet extends StatelessWidget {
  const _FormatBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppTheme.accentGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.summary,
    required this.scriptPreview,
  });

  final String summary;
  final String scriptPreview;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.darkAccentBlue.withValues(alpha: 0.14)
            : AppTheme.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode
              ? AppTheme.darkAccentBlue.withValues(alpha: 0.28)
              : AppTheme.accentBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color:
                    isDarkMode ? AppTheme.darkAccentBlue : AppTheme.accentBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'AI 智能适配已生效',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppTheme.coolGray800.withValues(alpha: 0.72)
                  : AppTheme.coolGray50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? AppTheme.coolGray700 : AppTheme.coolGray200,
              ),
            ),
            child: SelectableText(
              scriptPreview,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordBookImportPreview {
  const _WordBookImportPreview({
    required this.words,
    required this.sampleWords,
    required this.duplicateCount,
    required this.lineCount,
    this.usedAi = false,
    this.aiSummary = '',
    this.scriptPreview = '',
  });

  final List<WordData> words;
  final List<WordData> sampleWords;
  final int duplicateCount;
  final int lineCount;
  final bool usedAi;
  final String aiSummary;
  final String scriptPreview;
}
