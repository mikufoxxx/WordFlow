import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 统一的 LLM 提供商类型。
enum LlmProviderType {
  openAiCompatible('openai_compatible', 'OpenAI 适配模式'),
  openAiResponses('openai_responses', 'OpenAI Responses 模式'),
  claude('claude', 'Anthropic 模式');

  const LlmProviderType(this.code, this.displayName);

  final String code;
  final String displayName;

  static LlmProviderType fromCode(String? code) {
    switch (code) {
      case 'openai_responses':
        return LlmProviderType.openAiResponses;
      case 'claude':
        return LlmProviderType.claude;
      case 'openai_compatible':
      default:
        return LlmProviderType.openAiCompatible;
    }
  }

  String get suggestedBaseUrl {
    switch (this) {
      case LlmProviderType.openAiCompatible:
      case LlmProviderType.openAiResponses:
        return 'https://api.openai.com';
      case LlmProviderType.claude:
        return 'https://api.anthropic.com';
    }
  }

  String get helpText {
    switch (this) {
      case LlmProviderType.openAiCompatible:
        return '适用于兼容 OpenAI Chat Completions 协议的平台，例如 DeepSeek、OpenRouter、One API 等。';
      case LlmProviderType.openAiResponses:
        return '使用新版 Responses 接口，适合支持 OpenAI Responses API 的服务端。';
      case LlmProviderType.claude:
        return '使用 Anthropic 官方 Messages 协议，自动按 Anthropic 的 Claude 接口格式发起请求。';
    }
  }
}

/// 统一的 AI 配置。
class LlmProviderConfig {
  const LlmProviderConfig({
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  const LlmProviderConfig.empty()
      : provider = LlmProviderType.openAiCompatible,
        baseUrl = '',
        apiKey = '',
        model = '';

  final LlmProviderType provider;
  final String baseUrl;
  final String apiKey;
  final String model;

  bool get hasBaseUrl => baseUrl.trim().isNotEmpty;

  bool get hasApiKey => apiKey.trim().length >= 10;

  bool get hasModel => model.trim().isNotEmpty;

  bool get isUsable => hasBaseUrl && hasApiKey && hasModel;

  LlmProviderConfig copyWith({
    LlmProviderType? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return LlmProviderConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}

/// 模型信息。
class LlmModelInfo {
  const LlmModelInfo({
    required this.id,
    this.displayName,
    this.ownedBy,
  });

  final String id;
  final String? displayName;
  final String? ownedBy;

  String get label {
    final resolvedName = (displayName ?? '').trim();
    if (resolvedName.isEmpty || resolvedName == id) {
      return id;
    }
    return '$resolvedName ($id)';
  }
}

/// 连接测试结果。
class LlmConnectionTestResult {
  const LlmConnectionTestResult({
    required this.isSuccess,
    required this.message,
    this.models = const <LlmModelInfo>[],
    this.selectedModel,
  });

  final bool isSuccess;
  final String message;
  final List<LlmModelInfo> models;
  final String? selectedModel;
}

class LlmApiException implements Exception {
  const LlmApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 统一的 LLM API 服务。
class LlmApiService {
  static const Duration _timeout = Duration(seconds: 30);

  static const String _providerKey = 'llm_provider_type';
  static const String _baseUrlKey = 'llm_base_url';
  static const String _apiKeyKey = 'llm_api_key';
  static const String _modelKey = 'llm_model';

  static Future<LlmProviderConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();

    final savedApiKey = prefs.getString(_apiKeyKey)?.trim() ?? '';
    if (savedApiKey.isEmpty) {
      final legacyDeepSeekKey =
          prefs.getString('deepseek_api_key')?.trim() ?? '';
      if (legacyDeepSeekKey.isNotEmpty) {
        final migratedConfig = LlmProviderConfig(
          provider: LlmProviderType.openAiCompatible,
          baseUrl: 'https://api.deepseek.com',
          apiKey: legacyDeepSeekKey,
          model: prefs.getString(_modelKey)?.trim().isNotEmpty == true
              ? prefs.getString(_modelKey)!.trim()
              : 'deepseek-chat',
        );
        await saveConfig(migratedConfig);
        return migratedConfig;
      }
    }

    return LlmProviderConfig(
      provider: LlmProviderType.fromCode(prefs.getString(_providerKey)),
      baseUrl: prefs.getString(_baseUrlKey)?.trim() ?? '',
      apiKey: savedApiKey,
      model: prefs.getString(_modelKey)?.trim() ?? '',
    );
  }

  static Future<void> saveConfig(LlmProviderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, config.provider.code);
    await prefs.setString(_baseUrlKey, _normalizeBaseUrl(config.baseUrl));
    await prefs.setString(_apiKeyKey, config.apiKey.trim());
    await prefs.setString(_modelKey, config.model.trim());

    if (config.apiKey.trim().isNotEmpty) {
      await prefs.setString('deepseek_api_key', config.apiKey.trim());
    }
  }

  static Future<void> updateConfig({
    LlmProviderType? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) async {
    final currentConfig = await getConfig();
    await saveConfig(
      currentConfig.copyWith(
        provider: provider,
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
      ),
    );
  }

  static Future<void> clearModelSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, '');
  }

  static Future<bool> hasUsableConfig() async {
    final config = await getConfig();
    return config.isUsable;
  }

  static Future<List<LlmModelInfo>> fetchModels({
    required LlmProviderType provider,
    required String baseUrl,
    required String apiKey,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (normalizedBaseUrl.isEmpty) {
      throw const LlmApiException('请先填写 Base URL');
    }
    if (apiKey.trim().length < 10) {
      throw const LlmApiException('请先填写有效的 API Key');
    }

    final response = await _getWithFallback(
      baseUrl: normalizedBaseUrl,
      candidateEndpoints: const <String>['v1/models', 'models'],
      headers: _buildModelHeaders(provider, apiKey.trim()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmApiException(_extractErrorMessage(response));
    }

    final Map<String, dynamic> jsonData = _decodeJsonMap(response.body);
    final dynamic data = jsonData['data'];
    if (data is! List) {
      throw const LlmApiException('模型列表解析失败：服务端没有返回 data 数组');
    }

    final models = data
        .whereType<Map>()
        .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => LlmModelInfo(
            id: (item['id'] ?? '').toString().trim(),
            displayName:
                (item['display_name'] ?? item['name'] ?? '').toString().trim(),
            ownedBy:
                (item['owned_by'] ?? item['provider'] ?? '').toString().trim(),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (models.isEmpty) {
      throw const LlmApiException('当前接口未返回任何模型');
    }

    return models;
  }

  static Future<LlmConnectionTestResult> testConnection({
    LlmProviderConfig? overrideConfig,
    bool autoSelectFirstModel = false,
  }) async {
    try {
      final config = overrideConfig ?? await getConfig();
      final normalizedConfig =
          config.copyWith(baseUrl: _normalizeBaseUrl(config.baseUrl));

      if (!normalizedConfig.hasBaseUrl) {
        return const LlmConnectionTestResult(
          isSuccess: false,
          message: '请先填写 Base URL',
        );
      }
      if (!normalizedConfig.hasApiKey) {
        return const LlmConnectionTestResult(
          isSuccess: false,
          message: '请先填写有效的 API Key',
        );
      }

      final models = await fetchModels(
        provider: normalizedConfig.provider,
        baseUrl: normalizedConfig.baseUrl,
        apiKey: normalizedConfig.apiKey,
      );

      final resolvedModel = normalizedConfig.hasModel
          ? normalizedConfig.model
          : _pickPreferredModel(normalizedConfig.provider, models);

      final requestConfig = normalizedConfig.copyWith(model: resolvedModel);
      final evaluation = await generateJsonObject(
        systemPrompt: '你是一个专业的英语教师，负责判断学生造句的正确性。请严格按照 JSON 格式返回结果。',
        userPrompt: _buildConnectionTestPrompt(),
        temperature: 0.1,
        maxTokens: 400,
        overrideConfig: requestConfig,
      );

      if (autoSelectFirstModel &&
          !normalizedConfig.hasModel &&
          resolvedModel.isNotEmpty) {
        await saveConfig(requestConfig);
      }

      return LlmConnectionTestResult(
        isSuccess: true,
        message: _buildConnectionTestSummary(
          modelCount: models.length,
          modelId: resolvedModel,
          evaluation: evaluation,
        ),
        models: models,
        selectedModel: resolvedModel,
      );
    } on LlmApiException catch (error) {
      return LlmConnectionTestResult(
        isSuccess: false,
        message: error.message,
      );
    } catch (error) {
      return LlmConnectionTestResult(
        isSuccess: false,
        message: '连接失败：$error',
      );
    }
  }

  static Future<Map<String, dynamic>> generateJsonObject({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.3,
    int maxTokens = 800,
    LlmProviderConfig? overrideConfig,
  }) async {
    final config = overrideConfig ?? await getConfig();
    final normalizedConfig =
        config.copyWith(baseUrl: _normalizeBaseUrl(config.baseUrl));

    if (!normalizedConfig.hasBaseUrl) {
      throw const LlmApiException('未配置 Base URL');
    }
    if (!normalizedConfig.hasApiKey) {
      throw const LlmApiException('未配置有效的 API Key');
    }
    if (!normalizedConfig.hasModel) {
      throw const LlmApiException('未选择模型');
    }

    final http.Response response;
    switch (normalizedConfig.provider) {
      case LlmProviderType.openAiCompatible:
        response = await _postOpenAiCompatible(
          config: normalizedConfig,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );
        break;
      case LlmProviderType.openAiResponses:
        response = await _postOpenAiResponses(
          config: normalizedConfig,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );
        break;
      case LlmProviderType.claude:
        response = await _postClaudeMessages(
          config: normalizedConfig,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );
        break;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmApiException(_extractErrorMessage(response));
    }

    final responseMap = _decodeJsonMap(response.body);
    final text = _extractResponseText(normalizedConfig.provider, responseMap);
    if (text.trim().isEmpty) {
      throw const LlmApiException('模型返回内容为空');
    }

    return _extractJsonObject(text);
  }

  static Future<http.Response> _postOpenAiCompatible({
    required LlmProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
  }) {
    return http
        .post(
          _resolveUri(config.baseUrl, 'v1/chat/completions'),
          headers: _buildOpenAiHeaders(config.apiKey),
          body: jsonEncode({
            'model': config.model,
            'messages': [
              {
                'role': 'system',
                'content': systemPrompt,
              },
              {
                'role': 'user',
                'content': userPrompt,
              },
            ],
            'temperature': temperature,
            'max_tokens': maxTokens,
            'stream': false,
          }),
        )
        .timeout(_timeout);
  }

  static Future<http.Response> _postOpenAiResponses({
    required LlmProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
  }) {
    return http
        .post(
          _resolveUri(config.baseUrl, 'v1/responses'),
          headers: _buildOpenAiHeaders(config.apiKey),
          body: jsonEncode({
            'model': config.model,
            'instructions': systemPrompt,
            'input': userPrompt,
            'temperature': temperature,
            'max_output_tokens': maxTokens,
          }),
        )
        .timeout(_timeout);
  }

  static Future<http.Response> _postClaudeMessages({
    required LlmProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
  }) {
    return http
        .post(
          _resolveUri(config.baseUrl, 'v1/messages'),
          headers: _buildClaudeHeaders(config.apiKey),
          body: jsonEncode({
            'model': config.model,
            'system': systemPrompt,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text': userPrompt,
                  },
                ],
              },
            ],
            'temperature': temperature,
            'max_tokens': maxTokens,
          }),
        )
        .timeout(_timeout);
  }

  static Future<http.Response> _getWithFallback({
    required String baseUrl,
    required List<String> candidateEndpoints,
    required Map<String, String> headers,
  }) async {
    http.Response? lastResponse;

    for (final endpoint in candidateEndpoints) {
      final response = await http
          .get(
            _resolveUri(baseUrl, endpoint),
            headers: headers,
          )
          .timeout(_timeout);
      lastResponse = response;

      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }

      return response;
    }

    return lastResponse ??
        http.Response(
          jsonEncode({
            'error': {'message': '模型列表接口不可用'}
          }),
          500,
        );
  }

  static Map<String, String> _buildModelHeaders(
    LlmProviderType provider,
    String apiKey,
  ) {
    switch (provider) {
      case LlmProviderType.claude:
        return _buildClaudeHeaders(apiKey);
      case LlmProviderType.openAiCompatible:
      case LlmProviderType.openAiResponses:
        return _buildOpenAiHeaders(apiKey);
    }
  }

  static Map<String, String> _buildOpenAiHeaders(String apiKey) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiKey.trim()}',
      'User-Agent': 'WordFlow/1.0',
    };
  }

  static Map<String, String> _buildClaudeHeaders(String apiKey) {
    return <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': apiKey.trim(),
      'anthropic-version': '2023-06-01',
      'User-Agent': 'WordFlow/1.0',
    };
  }

  static Uri _resolveUri(String baseUrl, String endpoint) {
    final baseUri = Uri.parse(_normalizeBaseUrl(baseUrl));
    final baseSegments =
        baseUri.pathSegments.where((item) => item.isNotEmpty).toList();
    final endpointSegments =
        endpoint.split('/').where((item) => item.isNotEmpty).toList();

    final overlap = _findPathOverlap(baseSegments, endpointSegments);
    final mergedSegments = <String>[
      ...baseSegments,
      ...endpointSegments.sublist(overlap),
    ];

    return baseUri.replace(pathSegments: mergedSegments);
  }

  static int _findPathOverlap(
      List<String> baseSegments, List<String> endpointSegments) {
    final maxSize = math.min(baseSegments.length, endpointSegments.length);

    for (int size = maxSize; size > 0; size--) {
      final baseTail = baseSegments.sublist(baseSegments.length - size);
      final endpointHead = endpointSegments.sublist(0, size);
      if (_listEquals(baseTail, endpointHead)) {
        return size;
      }
    }

    return 0;
  }

  static bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static Map<String, dynamic> _decodeJsonMap(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const LlmApiException('服务端返回了非对象格式数据');
  }

  static String _extractResponseText(
    LlmProviderType provider,
    Map<String, dynamic> responseMap,
  ) {
    switch (provider) {
      case LlmProviderType.openAiCompatible:
        final choices = responseMap['choices'];
        if (choices is List && choices.isNotEmpty) {
          final firstChoice = choices.first;
          if (firstChoice is Map) {
            final message = firstChoice['message'];
            if (message is Map) {
              return _extractTextFromDynamicContent(message['content']);
            }
          }
        }
        break;
      case LlmProviderType.openAiResponses:
        final outputText = responseMap['output_text'];
        if (outputText is String && outputText.trim().isNotEmpty) {
          return outputText;
        }

        final output = responseMap['output'];
        if (output is List) {
          final buffer = StringBuffer();
          for (final item in output) {
            if (item is! Map) {
              continue;
            }
            final content = item['content'];
            if (content is! List) {
              continue;
            }
            for (final block in content) {
              if (block is! Map) {
                continue;
              }
              final text = (block['text'] ?? block['value'] ?? '').toString();
              if (text.trim().isNotEmpty) {
                if (buffer.isNotEmpty) {
                  buffer.writeln();
                }
                buffer.write(text);
              }
            }
          }
          if (buffer.isNotEmpty) {
            return buffer.toString();
          }
        }
        break;
      case LlmProviderType.claude:
        final content = responseMap['content'];
        if (content is List) {
          final buffer = StringBuffer();
          for (final item in content) {
            if (item is! Map) {
              continue;
            }
            final text = (item['text'] ?? '').toString();
            if (text.trim().isNotEmpty) {
              if (buffer.isNotEmpty) {
                buffer.writeln();
              }
              buffer.write(text);
            }
          }
          if (buffer.isNotEmpty) {
            return buffer.toString();
          }
        }
        break;
    }

    throw const LlmApiException('解析模型响应失败');
  }

  static String _extractTextFromDynamicContent(dynamic content) {
    if (content is String) {
      return content;
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map) {
          final text = (item['text'] ?? item['value'] ?? '').toString();
          if (text.trim().isNotEmpty) {
            if (buffer.isNotEmpty) {
              buffer.writeln();
            }
            buffer.write(text);
          }
        } else if (item is String && item.trim().isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.writeln();
          }
          buffer.write(item);
        }
      }
      return buffer.toString();
    }

    return content?.toString() ?? '';
  }

  static Map<String, dynamic> _extractJsonObject(String text) {
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
    if (match == null) {
      throw const LlmApiException('模型未返回合法 JSON 内容');
    }

    final jsonString = match.group(0)!;
    final decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw const LlmApiException('JSON 内容解析失败');
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final dynamic error = decoded['error'];
        if (error is Map) {
          final message =
              (error['message'] ?? error['type'] ?? '').toString().trim();
          if (message.isNotEmpty) {
            return '请求失败：$message';
          }
        }
        final topLevelMessage = (decoded['message'] ?? '').toString().trim();
        if (topLevelMessage.isNotEmpty) {
          return '请求失败：$topLevelMessage';
        }
      }
    } catch (_) {
      // 忽略 JSON 解析异常，回退到 HTTP 状态码。
    }

    return '请求失败：HTTP ${response.statusCode}';
  }

  static String _buildConnectionTestPrompt() {
    return '''
请判断以下造句是否正确：

目标单词：design
单词释义：设计；设计，构思
用户造句：wordflow is design by mikufoxxx

请重点判断：
1. “design” 在这个句子里的词形和用法是否正确
2. 整个句子的语法是否自然
3. 如果不正确，应该如何修改

请严格按照以下 JSON 格式返回：
{
  "isCorrect": true/false,
  "issue": "用中文简要说明 design 在句中的用法是否正确",
  "suggestion": "用中文给出简洁修改建议",
  "correctedSentence": "如果句子有问题，给出正确自然的英文句子；如果句子本身正确，就返回原句"
}

要求：
- 必须返回合法 JSON，不要添加任何额外说明
- issue 和 suggestion 要简洁明确，避免空话
- correctedSentence 必须是完整英文句子
- 请优先识别被动语态中 be + 过去分词 的搭配是否正确
''';
  }

  static String _buildConnectionTestSummary({
    required int modelCount,
    required String modelId,
    required Map<String, dynamic> evaluation,
  }) {
    final bool? isCorrect = _readBool(
      evaluation,
      const <String>['isCorrect', 'correct'],
    );
    final String issue = _readText(
      evaluation,
      const <String>['issue', 'reason', 'analysis', 'errors'],
    );
    final String suggestion = _readText(
      evaluation,
      const <String>['suggestion', 'advice', 'improvement', 'suggestions'],
    );
    final String correctedSentence = _readText(
      evaluation,
      const <String>[
        'correctedSentence',
        'correctSentence',
        'betterSentence',
        'betterSentences',
      ],
    );

    final String verdict = isCorrect == null
        ? '已完成真实句子评估'
        : isCorrect
            ? '模型判定该句基本正确'
            : '模型判定该句中 design 用法不正确';

    final List<String> details = <String>[];
    if (issue.isNotEmpty) {
      details.add(issue);
    }
    if (suggestion.isNotEmpty) {
      details.add(suggestion);
    }
    if (correctedSentence.isNotEmpty) {
      details.add('建议句：$correctedSentence');
    }

    final String detailText = details.isEmpty ? '' : '；${details.join('；')}';
    return '连接成功，已获取 $modelCount 个模型，当前模型 $modelId 已完成真实句子评估：$verdict$detailText';
  }

  static bool? _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final dynamic value = json[key];
      if (value is bool) {
        return value;
      }
      final String normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  static String _readText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final dynamic value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is List) {
        final List<String> parts = value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          return parts.join('；');
        }
      }
    }
    return '';
  }

  static String _pickPreferredModel(
    LlmProviderType provider,
    List<LlmModelInfo> models,
  ) {
    if (models.isEmpty) {
      return '';
    }

    String? matchKeyword(List<String> keywords) {
      for (final keyword in keywords) {
        for (final model in models) {
          if (model.id.toLowerCase().contains(keyword.toLowerCase())) {
            return model.id;
          }
        }
      }
      return null;
    }

    switch (provider) {
      case LlmProviderType.openAiCompatible:
        return matchKeyword(
                <String>['deepseek-chat', 'gpt-4o-mini', 'gpt-4.1-mini']) ??
            models.first.id;
      case LlmProviderType.openAiResponses:
        return matchKeyword(<String>['gpt-4.1', 'gpt-4o', 'gpt-4o-mini']) ??
            models.first.id;
      case LlmProviderType.claude:
        return matchKeyword(<String>['sonnet', 'haiku', 'opus']) ??
            models.first.id;
    }
  }
}
