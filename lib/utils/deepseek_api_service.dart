import 'llm_api_service.dart';

/// DeepSeek 兼容服务。
///
/// 该门面保留原有调用方式，内部统一委托给通用的 LLM 服务，
/// 以兼容旧页面中仍然使用的 DeepSeek API 调用入口。
class DeepSeekApiService {
  static const String _defaultBaseUrl = 'https://api.deepseek.com';
  static const String _defaultModel = 'deepseek-chat';
  static const double _temperature = 0.3;

  /// 获取当前已配置的 API Key。
  ///
  /// 为了兼容旧逻辑，只有当完整 AI 配置可用时才返回非空值，
  /// 这样旧页面基于“是否存在 API Key”的判定仍可正常约束深入学习模式。
  static Future<String?> getApiKey() async {
    final config = await LlmApiService.getConfig();
    final apiKey = config.apiKey.trim();
    if (apiKey.isEmpty || !config.isUsable) {
      return null;
    }
    return apiKey;
  }

  /// 设置 API Key。
  ///
  /// 当旧入口只写入 key 时，自动补齐为 DeepSeek 兼容的默认配置，
  /// 保证旧 onboarding / 老逻辑仍然可以直接使用。
  static Future<void> setApiKey(String apiKey) async {
    final trimmedApiKey = apiKey.trim();
    final currentConfig = await LlmApiService.getConfig();
    final shouldApplyLegacyDefaults = currentConfig.baseUrl.trim().isEmpty &&
        currentConfig.model.trim().isEmpty;

    await LlmApiService.saveConfig(
      LlmProviderConfig(
        provider: shouldApplyLegacyDefaults
            ? LlmProviderType.openAiCompatible
            : currentConfig.provider,
        baseUrl: currentConfig.baseUrl.trim().isEmpty
            ? _defaultBaseUrl
            : currentConfig.baseUrl.trim(),
        apiKey: trimmedApiKey,
        model: currentConfig.model.trim().isEmpty
            ? _defaultModel
            : currentConfig.model.trim(),
      ),
    );
  }

  /// 判断用户造句是否正确。
  static Future<SentenceJudgmentResult?> judgeSentence({
    required String word,
    required String sentence,
    required String translation,
  }) async {
    final config = await LlmApiService.getConfig();
    if (!config.isUsable) {
      return SentenceJudgmentResult(
        isCorrect: false,
        errorMessage: '请先在设置中完成 AI 接口配置',
        suggestions: const <String>[],
      );
    }

    try {
      final jsonData = await LlmApiService.generateJsonObject(
        systemPrompt: '你是一个专业的英语教师，负责判断学生造句的正确性。请严格按照 JSON 格式返回结果。',
        userPrompt: _buildPrompt(word, sentence, translation),
        temperature: _temperature,
        maxTokens: 800,
      );
      return _parseJudgmentResult(jsonData);
    } on LlmApiException catch (error) {
      return SentenceJudgmentResult(
        isCorrect: false,
        errorMessage: error.message,
        suggestions: const <String>[],
      );
    } catch (_) {
      return SentenceJudgmentResult(
        isCorrect: false,
        errorMessage: '网络请求失败，请检查网络连接',
        suggestions: const <String>[],
      );
    }
  }

  /// 构建判断提示词。
  static String _buildPrompt(String word, String sentence, String translation) {
    return '''
请判断以下造句是否正确：

目标单词：$word
单词释义：$translation
用户造句：$sentence

请从以下几个方面进行判断：
1. 语法是否正确
2. 单词用法是否恰当
3. 句子意思是否清晰
4. 是否符合英语表达习惯

**评价指导原则：**
- 提供个性化、具体的建议，避免模板化的评价
- 即使句子正确，也要根据具体情况给出有针对性的建议
- 关注句子的表达水平、词汇丰富度、语言地道性等方面
- 如果句子基础正确但可以改进，在 suggestions 中提供具体的改进方向

**重要要求：**
- 这是一个单词学习练习，用户必须使用目标单词“$word”
- 在提供修改建议和更好的句子时，必须保持目标单词“$word”不变
- 不要将目标单词改为其他形式或其他单词
- 如果用户使用了错误的语法结构，请调整其他部分来配合目标单词

请严格按照以下 JSON 格式返回结果：
{
  "isCorrect": true/false,
  "score": 0-100,
  "errors": [
    "具体的错误描述1",
    "具体的错误描述2"
  ],
  "suggestions": [
    "针对这个句子的具体建议1",
    "针对这个句子的具体建议2"
  ],
  "betterSentences": [
    "更好的句子示例1（必须包含目标单词 $word）",
    "更好的句子示例2（必须包含目标单词 $word）"
  ]
}

注意：
- errors 数组：只有在句子有明显错误时才填入，描述具体的语法、用法或表达问题
- suggestions 数组：即使句子正确，也要提供有价值的改进建议，如让表达更地道、更丰富、更准确等
- 避免使用“您的句子语法正确，用词恰当”这样的通用评价，要针对具体句子给出个性化反馈
''';
  }

  /// 解析判断结果。
  static SentenceJudgmentResult _parseJudgmentResult(
    Map<String, dynamic> jsonData,
  ) {
    try {
      return SentenceJudgmentResult(
        isCorrect: _asBool(jsonData['isCorrect']),
        score: _asInt(jsonData['score']),
        errors: _asStringList(jsonData['errors']),
        suggestions: _asStringList(jsonData['suggestions']),
        betterSentences: _asStringList(jsonData['betterSentences']),
      );
    } catch (_) {
      return SentenceJudgmentResult(
        isCorrect: false,
        errorMessage: '解析结果失败',
        suggestions: const <String>[],
      );
    }
  }

  /// 生成例句和翻译。
  static Future<ExampleSentenceResult?> generateExampleSentence({
    required String word,
    required String translation,
  }) async {
    final config = await LlmApiService.getConfig();
    if (!config.isUsable) {
      return ExampleSentenceResult(
        example: "No example available for '$word'.",
        exampleTranslation: '暂无例句，请先完成 AI 接口配置',
        errorMessage: '请先在设置中完成 AI 接口配置',
      );
    }

    try {
      final jsonData = await LlmApiService.generateJsonObject(
        systemPrompt: '你是一个专业的英语教师，负责为学生生成简洁明了的例句。请严格按照 JSON 格式返回结果。',
        userPrompt: _buildExamplePrompt(word, translation),
        temperature: 0.7,
        maxTokens: 300,
      );
      return _parseExampleResult(jsonData, word);
    } on LlmApiException catch (error) {
      return ExampleSentenceResult(
        example: "No example available for '$word'.",
        exampleTranslation: '暂无例句，请先完成 AI 接口配置',
        errorMessage: error.message,
      );
    } catch (_) {
      return ExampleSentenceResult(
        example: "No example available for '$word'.",
        exampleTranslation: '暂无例句，请检查网络连接',
        errorMessage: '网络请求失败，请检查网络连接',
      );
    }
  }

  /// 构建例句生成提示词。
  static String _buildExamplePrompt(String word, String translation) {
    return '''
请为以下英语单词生成一个简洁明了的例句：

目标单词：$word
单词释义：$translation

要求：
1. 例句要简短（不超过 15 个单词）
2. 语法正确，表达自然
3. 能够清楚体现单词的含义和用法
4. 适合英语学习者理解
5. 使用常见词汇，避免过于复杂的表达

请严格按照以下 JSON 格式返回结果：
{
  "example": "包含目标单词的英文例句",
  "translation": "例句的中文翻译"
}
''';
  }

  /// 解析例句生成结果。
  static ExampleSentenceResult _parseExampleResult(
    Map<String, dynamic> jsonData,
    String word,
  ) {
    try {
      final example = (jsonData['example'] ?? '').toString().trim();
      final translation = (jsonData['translation'] ?? '').toString().trim();

      return ExampleSentenceResult(
        example:
            example.isEmpty ? "No example available for '$word'." : example,
        exampleTranslation: translation.isEmpty ? '暂无例句，请稍后重试' : translation,
      );
    } catch (_) {
      return ExampleSentenceResult(
        example: "No example available for '$word'.",
        exampleTranslation: '暂无例句，请稍后重试',
        errorMessage: '解析结果失败',
      );
    }
  }

  /// 测试 API 连接。
  static Future<bool> testApiConnection() async {
    final result =
        await LlmApiService.testConnection(autoSelectFirstModel: true);
    return result.isSuccess;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .map(
          (item) {
            if (item is String) {
              return item.trim();
            }
            if (item is Map && item['description'] != null) {
              return item['description'].toString().trim();
            }
            return item.toString().trim();
          },
        )
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

/// 造句判断结果。
class SentenceJudgmentResult {
  final bool isCorrect;
  final int score;
  final List<String> errors;
  final List<String> suggestions;
  final List<String> betterSentences;
  final String? errorMessage;

  const SentenceJudgmentResult({
    required this.isCorrect,
    this.score = 0,
    this.errors = const <String>[],
    this.suggestions = const <String>[],
    this.betterSentences = const <String>[],
    this.errorMessage,
  });
}

/// 例句生成结果。
class ExampleSentenceResult {
  final String example;
  final String exampleTranslation;
  final String? errorMessage;

  const ExampleSentenceResult({
    required this.example,
    required this.exampleTranslation,
    this.errorMessage,
  });
}
