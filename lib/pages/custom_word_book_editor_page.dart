import 'package:flutter/material.dart';

import '../models/word_book.dart';
import '../utils/app_theme.dart';
import '../utils/cache_service.dart';
import '../widgets/acrylic_app_bar.dart';

class CustomWordBookEditorPage extends StatefulWidget {
  const CustomWordBookEditorPage({
    super.key,
    required this.wordBookName,
  });

  final String wordBookName;

  @override
  State<CustomWordBookEditorPage> createState() =>
      _CustomWordBookEditorPageState();
}

class _CustomWordBookEditorPageState extends State<CustomWordBookEditorPage> {
  final TextEditingController _searchController = TextEditingController();

  List<WordData> _allWords = <WordData>[];
  List<WordData> _filteredWords = <WordData>[];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadWords();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _applyFilter(_searchController.text);
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
    });

    final cachedWords =
        await CacheService.getCachedWordData(widget.wordBookName) ??
            <WordData>[];

    if (!mounted) {
      return;
    }

    setState(() {
      _allWords = List<WordData>.from(cachedWords);
      _isLoading = false;
    });
    _applyFilter(_searchController.text);
  }

  void _applyFilter(String keyword) {
    final query = keyword.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<WordData>.from(_allWords)
        : _allWords.where((item) {
            return item.word.toLowerCase().contains(query) ||
                item.translation.toLowerCase().contains(query);
          }).toList(growable: false);

    if (!mounted) {
      return;
    }

    setState(() {
      _filteredWords = filtered;
    });
  }

  Future<void> _commitWords(List<WordData> nextWords) async {
    if (_isSaving) {
      return;
    }

    final previousWords = List<WordData>.from(_allWords);

    setState(() {
      _allWords = List<WordData>.from(nextWords);
      _isSaving = true;
    });
    _applyFilter(_searchController.text);

    try {
      await CacheService.updateCustomWordBookWords(
        widget.wordBookName,
        _allWords,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hasChanged = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _allWords = previousWords;
      });
      _applyFilter(_searchController.text);
      _showSnackBar(
        message: '保存失败：${error.toString().replaceFirst('Exception: ', '')}',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showWordEditorSheet({
    WordData? initialWord,
    int? index,
  }) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final wordController = TextEditingController(text: initialWord?.word ?? '');
    final translationController =
        TextEditingController(text: initialWord?.translation ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              String? errorText;

              Future<void> submit() async {
                final word = wordController.text.trim();
                final translation = translationController.text.trim();

                if (word.isEmpty || translation.isEmpty) {
                  setSheetState(() {
                    errorText = '单词和释义都不能为空';
                  });
                  return;
                }

                final duplicateIndex = _allWords.indexWhere(
                  (item) => item.word.toLowerCase() == word.toLowerCase(),
                );
                final isDuplicate =
                    duplicateIndex >= 0 && duplicateIndex != index;
                if (isDuplicate) {
                  setSheetState(() {
                    errorText = '已存在相同单词，请直接编辑原词条';
                  });
                  return;
                }

                final nextWords = List<WordData>.from(_allWords);
                final nextWord = WordData(word: word, translation: translation);
                if (index != null && index >= 0 && index < nextWords.length) {
                  nextWords[index] = nextWord;
                } else {
                  nextWords.insert(0, nextWord);
                }

                Navigator.of(context).pop();
                await _commitWords(nextWords);
                if (mounted) {
                  _showSnackBar(
                    message: index == null ? '已新增单词' : '已更新单词内容',
                    icon: index == null
                        ? Icons.add_task_rounded
                        : Icons.edit_note_rounded,
                  );
                }
              }

              return Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppTheme.darkCardColor
                      : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            index == null
                                ? Icons.add_circle_outline_rounded
                                : Icons.edit_outlined,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            index == null ? '新增单词' : '编辑单词',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      key: const Key('customWordEditorWordField'),
                      controller: wordController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '单词',
                        hintText: '例如：abandon',
                        prefixIcon: Icon(Icons.translate_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('customWordEditorTranslationField'),
                      controller: translationController,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '释义',
                        hintText: '例如：放弃；抛弃',
                        prefixIcon: Icon(Icons.notes_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('customWordEditorCancelButton'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            key: const Key('customWordEditorSubmitButton'),
                            onPressed: submit,
                            child: Text(index == null ? '新增' : '保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    wordController.dispose();
    translationController.dispose();
  }

  Future<void> _deleteWord(int index) async {
    final item = _allWords[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除单词'),
          content: Text('确定要删除“${item.word}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final nextWords = List<WordData>.from(_allWords)..removeAt(index);
    await _commitWords(nextWords);
    if (mounted) {
      _showSnackBar(
        message: '已删除单词',
        icon: Icons.delete_outline_rounded,
      );
    }
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

  Future<bool> _handleBack() async {
    Navigator.of(context).pop(_hasChanged);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: isDarkMode
            ? AppTheme.darkBackgroundColor
            : AppTheme.backgroundColor,
        appBar: AcrylicAppBar(
          title: '编辑词书',
          leading: IconButton(
            key: const Key('customWordBookEditorBackButton'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _handleBack,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('customWordBookEditorAddButton'),
          onPressed: _isSaving ? null : () => _showWordEditorSheet(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('新增单词'),
        ),
        body: Column(
          children: [
            if (_isSaving) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth >= 900 ? 24.0 : 16.0;

                  return RefreshIndicator(
                    onRefresh: _loadWords,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        120,
                      ),
                      children: [
                        Container(
                          key: const Key('customWordBookEditorHeaderCard'),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppTheme.darkCardColor
                                : AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.wordBookName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '支持搜索、新增、修改、删除单词内容，所有操作会实时保存到当前自定义词书。',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _EditorMetricChip(
                                    key: const Key(
                                        'customWordBookEditorCountChip'),
                                    icon: Icons.layers_rounded,
                                    label: '总词数',
                                    value: '${_allWords.length}',
                                  ),
                                  _EditorMetricChip(
                                    key: const Key(
                                        'customWordBookEditorSearchChip'),
                                    icon: Icons.search_rounded,
                                    label: '当前结果',
                                    value: '${_filteredWords.length}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          key: const Key('customWordBookEditorSearchCard'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppTheme.darkCardColor
                                : AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            key: const Key('customWordBookEditorSearchField'),
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: '搜索单词或释义',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      key: const Key(
                                          'customWordBookEditorSearchClearButton'),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_filteredWords.isEmpty)
                          _EditorEmptyState(
                            key: const Key('customWordBookEditorEmptyState'),
                            icon: _allWords.isEmpty
                                ? Icons.menu_book_outlined
                                : Icons.search_off_rounded,
                            title: _allWords.isEmpty ? '当前词书还没有单词' : '没有找到匹配内容',
                            subtitle: _allWords.isEmpty
                                ? '点击右下角按钮添加第一条单词。'
                                : '换个关键词试试，或者直接新增新的单词。',
                          )
                        else
                          ...List<Widget>.generate(_filteredWords.length,
                              (index) {
                            final item = _filteredWords[index];
                            final actualIndex = _allWords.indexOf(item);
                            return _EditorWordCard(
                              key: Key(
                                  'customWordBookEditorWordCard_${item.word}_$index'),
                              wordData: item,
                              onEdit: _isSaving
                                  ? null
                                  : () => _showWordEditorSheet(
                                        initialWord: item,
                                        index: actualIndex,
                                      ),
                              onDelete: _isSaving
                                  ? null
                                  : () => _deleteWord(actualIndex),
                            );
                          }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorMetricChip extends StatelessWidget {
  const _EditorMetricChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppTheme.accentGreen,
          ),
          const SizedBox(width: 8),
          Text(
            '$label：$value',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _EditorEmptyState extends StatelessWidget {
  const _EditorEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: AppTheme.coolGray400,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}

class _EditorWordCard extends StatelessWidget {
  const _EditorWordCard({
    super.key,
    required this.wordData,
    required this.onEdit,
    required this.onDelete,
  });

  final WordData wordData;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode
              ? AppTheme.coolGray700.withValues(alpha: 0.42)
              : AppTheme.coolGray200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wordData.word,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  wordData.translation,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              IconButton(
                key: Key('customWordBookEditorEditButton_${wordData.word}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑单词',
              ),
              IconButton(
                key: Key('customWordBookEditorDeleteButton_${wordData.word}'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: '删除单词',
                color: AppTheme.accentRed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
