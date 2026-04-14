import 'dart:async';
import 'dart:convert';

import '../models/word_book.dart';
import 'llm_api_service.dart';

class AiWordBookImportResult {
  const AiWordBookImportResult({
    required this.script,
    required this.words,
    required this.sampleWords,
    required this.duplicateCount,
    required this.lineCount,
    required this.bookNameSuggestion,
    required this.summary,
  });

  final AiWordBookImportScript script;
  final List<WordData> words;
  final List<WordData> sampleWords;
  final int duplicateCount;
  final int lineCount;
  final String bookNameSuggestion;
  final String summary;
}

class AiWordBookImportScript {
  const AiWordBookImportScript({
    required this.delimiter,
    required this.hasHeader,
    required this.headerRowIndex,
    required this.skipRows,
    required this.wordColumnIndex,
    required this.translationColumnIndex,
    required this.commentPrefixes,
    required this.replaceRules,
    required this.linePattern,
    required this.stripQuotes,
    required this.trimWhitespace,
    required this.deduplicateByLowercaseWord,
    required this.skipEmptyLines,
  });

  factory AiWordBookImportScript.fromJson(Map<String, dynamic> json) {
    final replaceRules = (json['replaceRules'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
        .map(AiWordBookReplaceRule.fromJson)
        .toList();

    return AiWordBookImportScript(
      delimiter: _normalizeString(json['delimiter'], fallback: 'auto'),
      hasHeader: json['hasHeader'] == true,
      headerRowIndex: _normalizeInt(json['headerRowIndex']),
      skipRows: _normalizeInt(json['skipRows']),
      wordColumnIndex: _normalizeInt(json['wordColumnIndex']),
      translationColumnIndex:
          _normalizeInt(json['translationColumnIndex'], fallback: 1),
      commentPrefixes: (json['commentPrefixes'] as List<dynamic>? ??
              const <dynamic>['#', '//'])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      replaceRules: replaceRules,
      linePattern: (json['linePattern'] ?? '').toString().trim(),
      stripQuotes: json['stripQuotes'] != false,
      trimWhitespace: json['trimWhitespace'] != false,
      deduplicateByLowercaseWord: json['deduplicateByLowercaseWord'] != false,
      skipEmptyLines: json['skipEmptyLines'] != false,
    );
  }

  final String delimiter;
  final bool hasHeader;
  final int headerRowIndex;
  final int skipRows;
  final int wordColumnIndex;
  final int translationColumnIndex;
  final List<String> commentPrefixes;
  final List<AiWordBookReplaceRule> replaceRules;
  final String linePattern;
  final bool stripQuotes;
  final bool trimWhitespace;
  final bool deduplicateByLowercaseWord;
  final bool skipEmptyLines;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'delimiter': delimiter,
      'hasHeader': hasHeader,
      'headerRowIndex': headerRowIndex,
      'skipRows': skipRows,
      'wordColumnIndex': wordColumnIndex,
      'translationColumnIndex': translationColumnIndex,
      'commentPrefixes': commentPrefixes,
      'replaceRules': replaceRules.map((item) => item.toJson()).toList(),
      'linePattern': linePattern,
      'stripQuotes': stripQuotes,
      'trimWhitespace': trimWhitespace,
      'deduplicateByLowercaseWord': deduplicateByLowercaseWord,
      'skipEmptyLines': skipEmptyLines,
    };
  }

  static int _normalizeInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value < 0 ? fallback : value;
    }
    final parsed = int.tryParse((value ?? '').toString().trim());
    if (parsed == null || parsed < 0) {
      return fallback;
    }
    return parsed;
  }

  static String _normalizeString(dynamic value, {required String fallback}) {
    final normalized = (value ?? '').toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}

class AiWordBookReplaceRule {
  const AiWordBookReplaceRule({
    required this.target,
    required this.replacement,
    required this.useRegex,
  });

  factory AiWordBookReplaceRule.fromJson(Map<String, dynamic> json) {
    return AiWordBookReplaceRule(
      target: (json['target'] ?? '').toString(),
      replacement: (json['replacement'] ?? '').toString(),
      useRegex: json['useRegex'] == true,
    );
  }

  final String target;
  final String replacement;
  final bool useRegex;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'target': target,
      'replacement': replacement,
      'useRegex': useRegex,
    };
  }
}

class AiWordBookImportService {
  static const int _sampleHeadLineCount = 24;
  static const int _sampleMiddleLineCount = 8;
  static const int _sampleTailLineCount = 8;
  static const int _sampleLineMaxLength = 140;
  static const int _sampleMaxCharacters = 3600;
  static const int _primaryMaxTokens = 900;
  static const int _repairMaxTokens = 700;
  static const int _repairWordThreshold = 2;

  static const String _systemPrompt = '''你是英语单词本导入格式适配器，只能返回合法 JSON。
目标：生成一个可直接执行在完整文件上的标准化脚本，把原始内容转换为两列：word、translation。

仅允许返回：
{
  "bookNameSuggestion": "字符串",
  "summary": "一句中文总结",
  "script": {
    "delimiter": "auto|comma|tab|semicolon|pipe|colon|space",
    "hasHeader": true,
    "headerRowIndex": 0,
    "skipRows": 0,
    "wordColumnIndex": 0,
    "translationColumnIndex": 1,
    "commentPrefixes": ["#", "//"],
    "replaceRules": [{"target": "", "replacement": "", "useRegex": false}],
    "linePattern": "",
    "stripQuotes": true,
    "trimWhitespace": true,
    "deduplicateByLowercaseWord": true,
    "skipEmptyLines": true
  }
}

规则：
1. 脚本必须适用于完整文件，而不是只适配样本行。
2. 优先使用 replaceRules、delimiter、列索引；只有必要时才使用 linePattern。
3. linePattern 必须提供命名分组 word 和 translation，或至少两个捕获组。
4. 脚本必须能跳过标题、来源、说明、序号、空行、注释、分隔线和多余列。
5. translationColumnIndex 必须指向释义列。
6. 不要输出 markdown、解释文字或代码块。''';

  static Future<AiWordBookImportResult> analyzeAndTransform({
    required String rawContent,
    required String fileName,
  }) async {
    Map<String, dynamic>? primaryResponse;

    try {
      primaryResponse = await _requestScript(
        rawContent: rawContent,
        fileName: fileName,
        isRepair: false,
      );
    } on TimeoutException {
      throw _buildTimeoutException();
    }

    try {
      final primaryResult = _buildResultFromResponse(
        rawContent: rawContent,
        fileName: fileName,
        response: primaryResponse,
      );

      if (!_shouldRepairResult(
        primaryResult: primaryResult,
        rawContent: rawContent,
      )) {
        return primaryResult;
      }

      try {
        final repairedResponse = await _requestScript(
          rawContent: rawContent,
          fileName: fileName,
          isRepair: true,
          repairReason:
              '首轮脚本识别到的单词偏少（${primaryResult.words.length} 个），请基于完整文件生成更稳健的脚本。',
          previousScript: _asMap(primaryResponse['script']),
        );

        return _buildResultFromResponse(
          rawContent: rawContent,
          fileName: fileName,
          response: repairedResponse,
        );
      } on TimeoutException {
        return primaryResult;
      } catch (_) {
        return primaryResult;
      }
    } catch (error) {
      try {
        final repairedResponse = await _requestScript(
          rawContent: rawContent,
          fileName: fileName,
          isRepair: true,
          repairReason:
              '首轮脚本执行失败：${error.toString().replaceFirst('Exception: ', '')}。请直接修正并返回新的 JSON 脚本。',
          previousScript: _asMap(primaryResponse['script']),
        );

        return _buildResultFromResponse(
          rawContent: rawContent,
          fileName: fileName,
          response: repairedResponse,
        );
      } on TimeoutException {
        throw _buildTimeoutException();
      }
    }
  }

  static Future<Map<String, dynamic>> _requestScript({
    required String rawContent,
    required String fileName,
    required bool isRepair,
    String repairReason = '',
    Map<String, dynamic>? previousScript,
  }) {
    return LlmApiService.generateJsonObject(
      systemPrompt: _systemPrompt,
      userPrompt: _buildUserPrompt(
        rawContent: rawContent,
        fileName: fileName,
        repairReason: repairReason,
        previousScript: previousScript,
      ),
      temperature: isRepair ? 0.0 : 0.1,
      maxTokens: isRepair ? _repairMaxTokens : _primaryMaxTokens,
    );
  }

  static AiWordBookImportResult _buildResultFromResponse({
    required String rawContent,
    required String fileName,
    required Map<String, dynamic> response,
  }) {
    final scriptJson = _asMap(response['script']);
    final script = AiWordBookImportScript.fromJson(scriptJson);

    return transformWithScript(
      rawContent: rawContent,
      fileName: fileName,
      script: script,
      summary: (response['summary'] ?? 'AI 已自动生成可执行标准化脚本').toString().trim(),
      bookNameSuggestion:
          (response['bookNameSuggestion'] ?? '').toString().trim(),
    );
  }

  static bool _shouldRepairResult({
    required AiWordBookImportResult primaryResult,
    required String rawContent,
  }) {
    final lines = const LineSplitter().convert(rawContent);
    final meaningfulLineCount = _countMeaningfulLines(lines);

    if (meaningfulLineCount < 8) {
      return false;
    }
    if (primaryResult.words.isEmpty) {
      return true;
    }
    if (primaryResult.words.length <= _repairWordThreshold) {
      return true;
    }
    return primaryResult.words.length * 4 < meaningfulLineCount;
  }

  static AiWordBookImportResult transformWithScript({
    required String rawContent,
    required String fileName,
    required AiWordBookImportScript script,
    String summary = '',
    String bookNameSuggestion = '',
  }) {
    String normalizedContent = rawContent;
    for (final rule in script.replaceRules) {
      if (rule.target.isEmpty) {
        continue;
      }
      if (rule.useRegex) {
        normalizedContent = normalizedContent.replaceAll(
          RegExp(rule.target, multiLine: true),
          rule.replacement,
        );
      } else {
        normalizedContent =
            normalizedContent.replaceAll(rule.target, rule.replacement);
      }
    }

    final rawLines = const LineSplitter().convert(normalizedContent);
    final words = <WordData>[];
    final sampleWords = <WordData>[];
    final seenWords = <String>{};
    int duplicateCount = 0;
    int effectiveLineCount = 0;

    for (int index = 0; index < rawLines.length; index++) {
      if (index < script.skipRows) {
        continue;
      }
      if (script.hasHeader && index == script.headerRowIndex) {
        continue;
      }

      final rawLine = rawLines[index];
      final line = script.trimWhitespace ? rawLine.trim() : rawLine;
      if (script.skipEmptyLines && line.trim().isEmpty) {
        continue;
      }
      if (_startsWithAny(line.trimLeft(), script.commentPrefixes)) {
        continue;
      }

      final parsedRow = _parseRow(line, script, index + 1);
      if (parsedRow == null) {
        continue;
      }

      effectiveLineCount++;
      final word = _sanitizeField(
        parsedRow.word,
        stripQuotes: script.stripQuotes,
        trimWhitespace: script.trimWhitespace,
      );
      final translation = _sanitizeField(
        parsedRow.translation,
        stripQuotes: script.stripQuotes,
        trimWhitespace: script.trimWhitespace,
      );

      if (word.isEmpty || translation.isEmpty) {
        continue;
      }

      final normalizedWord =
          script.deduplicateByLowercaseWord ? word.toLowerCase() : word;
      if (!seenWords.add(normalizedWord)) {
        duplicateCount++;
        continue;
      }

      final item = WordData(word: word, translation: translation);
      words.add(item);
      if (sampleWords.length < 6) {
        sampleWords.add(item);
      }
    }

    if (words.isEmpty) {
      throw Exception('AI 已生成转换脚本，但未提取到有效单词，请更换文件或调整内容后重试');
    }

    final resolvedBookNameSuggestion = bookNameSuggestion.trim().isNotEmpty
        ? bookNameSuggestion.trim()
        : _suggestBookName(fileName);

    return AiWordBookImportResult(
      script: script,
      words: words,
      sampleWords: sampleWords,
      duplicateCount: duplicateCount,
      lineCount: effectiveLineCount,
      bookNameSuggestion: resolvedBookNameSuggestion,
      summary:
          summary.trim().isNotEmpty ? summary.trim() : 'AI 已自动识别当前文件结构并完成兼容转换',
    );
  }

  static String prettyPrintScript(AiWordBookImportScript script) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(script.toJson());
  }

  static _ParsedImportRow? _parseRow(
    String line,
    AiWordBookImportScript script,
    int lineNumber,
  ) {
    if (script.linePattern.trim().isNotEmpty) {
      try {
        final pattern = RegExp(script.linePattern, multiLine: false);
        final match = pattern.firstMatch(line);
        if (match == null) {
          return null;
        }

        final namedWord = match.namedGroup('word');
        final namedTranslation = match.namedGroup('translation');
        final word =
            namedWord ?? (match.groupCount >= 1 ? (match.group(1) ?? '') : '');
        final translation = namedTranslation ??
            (match.groupCount >= 2 ? (match.group(2) ?? '') : '');

        return _ParsedImportRow(word: word, translation: translation);
      } catch (_) {
        throw Exception('AI 生成的转换脚本包含无效正则，无法解析第 $lineNumber 行');
      }
    }

    final delimiter = _resolveDelimiter(script.delimiter, line);
    final columns = _splitDelimitedLine(line, delimiter);
    if (columns.isEmpty) {
      return null;
    }

    final wordIndex = script.wordColumnIndex;
    final translationIndex = script.translationColumnIndex;
    if (wordIndex >= columns.length || translationIndex >= columns.length) {
      return null;
    }

    return _ParsedImportRow(
      word: columns[wordIndex],
      translation: columns[translationIndex],
    );
  }

  static List<String> _splitDelimitedLine(String line, String delimiter) {
    if (delimiter.isEmpty) {
      return <String>[line];
    }

    if (delimiter == ' ') {
      return line
          .split(RegExp(r'\s+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final columns = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    String? quoteChar;

    for (int index = 0; index < line.length; index++) {
      final char = line[index];
      final isQuote = char == '"' || char == '\'';

      if (isQuote) {
        if (!inQuotes) {
          inQuotes = true;
          quoteChar = char;
        } else if (quoteChar == char) {
          final nextChar = index + 1 < line.length ? line[index + 1] : null;
          if (nextChar == char) {
            buffer.write(char);
            index++;
          } else {
            inQuotes = false;
            quoteChar = null;
          }
        } else {
          buffer.write(char);
        }
        continue;
      }

      if (!inQuotes && char == delimiter) {
        columns.add(buffer.toString());
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    columns.add(buffer.toString());
    return columns;
  }

  static String _resolveDelimiter(String configured, String line) {
    switch (configured.trim().toLowerCase()) {
      case 'comma':
        return ',';
      case 'tab':
        return '\t';
      case 'semicolon':
        return ';';
      case 'pipe':
        return '|';
      case 'colon':
        return ':';
      case 'space':
        return ' ';
      case 'auto':
      default:
        final candidates = <String>['\t', ',', ';', '|', ':'];
        for (final delimiter in candidates) {
          if (line.contains(delimiter)) {
            return delimiter;
          }
        }
        return ',';
    }
  }

  static bool _startsWithAny(String value, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (prefix.isNotEmpty && value.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  static String _sanitizeField(
    String value, {
    required bool stripQuotes,
    required bool trimWhitespace,
  }) {
    String result = value;
    if (trimWhitespace) {
      result = result.trim();
    }
    if (stripQuotes) {
      result = _stripWrappingQuotes(result);
    }
    return result.trim();
  }

  static String _stripWrappingQuotes(String value) {
    if (value.length < 2) {
      return value;
    }
    final startsWithDouble = value.startsWith('"') && value.endsWith('"');
    final startsWithSingle = value.startsWith('\'') && value.endsWith('\'');
    if (startsWithDouble || startsWithSingle) {
      return value.substring(1, value.length - 1).trim();
    }
    return value;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const LlmApiException('AI 未返回有效的转换脚本');
  }

  static String _buildUserPrompt({
    required String rawContent,
    required String fileName,
    String repairReason = '',
    Map<String, dynamic>? previousScript,
  }) {
    final lines = const LineSplitter().convert(rawContent);
    final meaningfulLineCount = _countMeaningfulLines(lines);
    final sampleContent = _buildContentSample(lines);
    final previousScriptText = previousScript == null
        ? ''
        : '\n上一次脚本(JSON)：\n${const JsonEncoder.withIndent('  ').convert(previousScript)}';
    final repairText =
        repairReason.trim().isEmpty ? '' : '\n修正要求：$repairReason';

    return '''请基于以下导入文件样本生成可直接执行的标准化脚本 JSON。
脚本会在应用内直接运行于完整文件。

文件名：$fileName
总行数：${lines.length}
有效行数：$meaningfulLineCount
要求：
1. 优先生成最稳健、最短的脚本。
2. 优先使用 replaceRules、delimiter、列索引。
3. 只有必要时才使用 linePattern。
4. 脚本必须适用于完整文件，而不是只适配样本行。$repairText$previousScriptText

文件样本开始：
$sampleContent
文件样本结束''';
  }

  static String _buildContentSample(List<String> lines) {
    if (lines.isEmpty) {
      return '(空文件)';
    }

    final selectedIndexes = <int>{};

    void addRange(int start, int end) {
      for (int index = start; index < end; index++) {
        if (index >= 0 && index < lines.length) {
          selectedIndexes.add(index);
        }
      }
    }

    addRange(0, _sampleHeadLineCount);

    if (lines.length > _sampleHeadLineCount + _sampleTailLineCount) {
      final middleStart = ((lines.length - _sampleMiddleLineCount) / 2)
          .floor()
          .clamp(0, lines.length);
      addRange(middleStart, middleStart + _sampleMiddleLineCount);
    }

    addRange(lines.length - _sampleTailLineCount, lines.length);

    final orderedIndexes = selectedIndexes.toList()..sort();
    final buffer = StringBuffer();
    int? previousIndex;
    int currentLength = 0;
    bool truncated = false;

    for (final index in orderedIndexes) {
      if (previousIndex != null && index - previousIndex > 1) {
        const gapLine = '...';
        final gapLength = (currentLength == 0 ? 0 : 1) + gapLine.length;
        if (currentLength + gapLength > _sampleMaxCharacters) {
          truncated = true;
          break;
        }
        if (currentLength > 0) {
          buffer.writeln();
          currentLength++;
        }
        buffer.write(gapLine);
        currentLength += gapLine.length;
      }

      final formattedLine =
          '${index + 1}: ${_truncateSampleLine(lines[index])}';
      final lineLength = (currentLength == 0 ? 0 : 1) + formattedLine.length;
      if (currentLength + lineLength > _sampleMaxCharacters) {
        truncated = true;
        break;
      }
      if (currentLength > 0) {
        buffer.writeln();
        currentLength++;
      }
      buffer.write(formattedLine);
      currentLength += formattedLine.length;
      previousIndex = index;
    }

    if (truncated) {
      const suffix = '...(样本已截断)';
      final suffixLength = (currentLength == 0 ? 0 : 1) + suffix.length;
      if (currentLength + suffixLength <= _sampleMaxCharacters) {
        if (currentLength > 0) {
          buffer.writeln();
        }
        buffer.write(suffix);
      }
    }

    return buffer.toString().trimRight();
  }

  static String _truncateSampleLine(String line) {
    final normalized = line.trimRight();
    if (normalized.length <= _sampleLineMaxLength) {
      return normalized;
    }
    return '${normalized.substring(0, _sampleLineMaxLength)}…';
  }

  static Exception _buildTimeoutException() {
    return Exception('AI 解析超时（30 秒内未完成），已自动停止深度修正。请减少文件内容后重试');
  }

  static int _countMeaningfulLines(List<String> lines) {
    return lines.where((line) {
      final value = line.trim();
      if (value.isEmpty) {
        return false;
      }
      return !value.startsWith('#') && !value.startsWith('//');
    }).length;
  }

  static String _suggestBookName(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, lastDotIndex);
  }
}

class _ParsedImportRow {
  const _ParsedImportRow({
    required this.word,
    required this.translation,
  });

  final String word;
  final String translation;
}
