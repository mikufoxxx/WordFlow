import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// DeepSeek API服务
/// 用于判断用户造句的正确性并提供修改建议
class DeepSeekApiService {
  static const String _baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const Duration _timeout = Duration(seconds: 30);
  
  /// 造句判断的温度值，较低的值让AI更客观准确
  static const double _temperature = 0.3;
  
  /// 获取DeepSeek API密钥
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('deepseek_api_key');
  }
  
  /// 设置DeepSeek API密钥
  static Future<void> setApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepseek_api_key', apiKey);
  }

  /// 测试API连接
  static Future<bool> testApiConnection() async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return false;
      }
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'User-Agent': 'WordFlow/1.0',
      };
      
      final body = jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'user',
            'content': 'Hello, this is a test.',
          },
        ],
        'temperature': 0.1,
        'max_tokens': 10,
        'stream': false,
      });
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: body,
      ).timeout(Duration(seconds: 10));
      
      return response.statusCode == 200;
      
    } catch (e) {
      return false;
    }
  }
  
  /// 判断用户造句是否正确
  /// 
  /// [word] 目标单词
  /// [sentence] 用户造的句子
  /// [translation] 单词的中文释义
  /// 返回 [SentenceJudgmentResult] 包含判断结果和修改建议
  static Future<SentenceJudgmentResult?> judgeSentence({
    required String word,
    required String sentence,
    required String translation,
  }) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return SentenceJudgmentResult(
          isCorrect: false,
          errorMessage: '请先在设置中配置DeepSeek API密钥',
          suggestions: [],
        );
      }
      
      final prompt = _buildPrompt(word, sentence, translation);
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'User-Agent': 'WordFlow/1.0',
      };
      
      final body = jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'system',
            'content': '你是一个专业的英语教师，负责判断学生造句的正确性。请严格按照JSON格式返回结果。',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': _temperature,
        'max_tokens': 800,
        'stream': false,
      });
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: body,
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['choices'] != null && jsonData['choices'].isNotEmpty) {
          final content = jsonData['choices'][0]['message']['content'];
          return _parseJudgmentResult(content);
        }
      } else {
        final errorData = jsonDecode(response.body);
        return SentenceJudgmentResult(
          isCorrect: false,
          errorMessage: '请求失败：${errorData['error']['message'] ?? '未知错误'}',
          suggestions: [],
        );
      }
      
    } catch (e) {
      return SentenceJudgmentResult(
        isCorrect: false,
        errorMessage: '网络请求失败，请检查网络连接',
        suggestions: [],
      );
    }
    
    return null;
  }
  
  /// 构建判断提示词
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
- 如果句子基础正确但可以改进，在suggestions中提供具体的改进方向

**重要要求：**
- 这是一个单词学习练习，用户必须使用目标单词"$word"
- 在提供修改建议和更好的句子时，必须保持目标单词"$word"不变
- 不要将目标单词改为其他形式或其他单词
- 如果用户使用了错误的语法结构，请调整其他部分来配合目标单词

请严格按照以下JSON格式返回结果：
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
    "更好的句子示例1（必须包含目标单词$word）",
    "更好的句子示例2（必须包含目标单词$word）"
  ]
}

注意：
- errors数组：只有在句子有明显错误时才填入，描述具体的语法、用法或表达问题
- suggestions数组：即使句子正确，也要提供有价值的改进建议，如让表达更地道、更丰富、更准确等
- 避免使用"您的句子语法正确，用词恰当"这样的通用评价，要针对具体句子给出个性化反馈
''';
  }
  
  /// 解析判断结果
  static SentenceJudgmentResult _parseJudgmentResult(String content) {
    try {
      // 尝试提取JSON部分
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) {
        return SentenceJudgmentResult(
          isCorrect: false,
          errorMessage: '解析响应失败',
          suggestions: [],
        );
      }
      
      final jsonStr = jsonMatch.group(0)!;
      final jsonData = jsonDecode(jsonStr);
      
      final isCorrect = jsonData['isCorrect'] ?? false;
      final score = jsonData['score'] ?? 0;
      
      // 正确解析errors数组
      final errors = <String>[];
      if (jsonData['errors'] != null) {
        final errorsData = jsonData['errors'] as List;
        for (final error in errorsData) {
          if (error is String) {
            errors.add(error);
          } else if (error is Map && error['description'] != null) {
            errors.add(error['description'].toString());
          }
        }
      }
      
      final suggestions = (jsonData['suggestions'] as List?)?.map((s) => s.toString()).toList() ?? [];
      final betterSentences = (jsonData['betterSentences'] as List?)?.map((s) => s.toString()).toList() ?? [];
      
      return SentenceJudgmentResult(
        isCorrect: isCorrect,
        score: score,
        errors: errors,
        suggestions: suggestions,
        betterSentences: betterSentences,
      );
      
    } catch (e) {
      return SentenceJudgmentResult(
        isCorrect: false,
        errorMessage: '解析结果失败',
        suggestions: [],
      );
    }
  }
  
  /// 生成例句和翻译
  /// 
  /// [word] 目标单词
  /// [translation] 单词的中文释义
  /// 返回 [ExampleSentenceResult] 包含生成的例句和翻译
  static Future<ExampleSentenceResult?> generateExampleSentence({
    required String word,
    required String translation,
  }) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return ExampleSentenceResult(
          example: "No example available for '$word'.",
          exampleTranslation: "暂无例句，请填入API Key获取更多例句",
          errorMessage: '请先在设置中配置DeepSeek API密钥',
        );
      }
      
      final prompt = _buildExamplePrompt(word, translation);
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'User-Agent': 'WordFlow/1.0',
      };
      
      final body = jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'system',
            'content': '你是一个专业的英语教师，负责为学生生成简洁明了的例句。请严格按照JSON格式返回结果。',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 300,
        'stream': false,
      });
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: body,
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['choices'] != null && jsonData['choices'].isNotEmpty) {
          final content = jsonData['choices'][0]['message']['content'];
          return _parseExampleResult(content, word);
        }
      } else {
        final errorData = jsonDecode(response.body);
        return ExampleSentenceResult(
          example: "No example available for '$word'.",
          exampleTranslation: "暂无例句，请填入API Key获取更多例句",
          errorMessage: '请求失败：${errorData['error']['message'] ?? '未知错误'}',
        );
      }
      
    } catch (e) {
      return ExampleSentenceResult(
        example: "No example available for '$word'.",
        exampleTranslation: "暂无例句，请填入API Key获取更多例句",
        errorMessage: '网络请求失败，请检查网络连接',
      );
    }
    
    return ExampleSentenceResult(
      example: "No example available for '$word'.",
      exampleTranslation: "暂无例句，请填入API Key获取更多例句",
    );
  }

  /// 构建例句生成提示词
  static String _buildExamplePrompt(String word, String translation) {
    return '''
请为以下英语单词生成一个简洁、实用的例句：

目标单词：$word
单词释义：$translation

要求：
1. 例句要简洁明了，适合学习者理解
2. 要体现该单词的主要含义
3. 句子长度适中，不要过于复杂
4. 提供准确的中文翻译

请按照以下JSON格式返回结果：
{
  "example": "包含目标单词的英语例句",
  "translation": "例句的中文翻译"
}
''';
  }

  /// 解析例句生成结果
  static ExampleSentenceResult _parseExampleResult(String content, String word) {
    try {
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) {
        return ExampleSentenceResult(
          example: "No example available for '$word'.",
          exampleTranslation: "暂无例句，请填入API Key获取更多例句",
          errorMessage: '解析响应失败',
        );
      }
      
      final jsonStr = jsonMatch.group(0)!;
      final jsonData = jsonDecode(jsonStr);
      
      final example = jsonData['example']?.toString() ?? "No example available for '$word'.";
      final translation = jsonData['translation']?.toString() ?? "暂无例句，请填入API Key获取更多例句";
      
      return ExampleSentenceResult(
        example: example,
        exampleTranslation: translation,
      );
      
    } catch (e) {
      return ExampleSentenceResult(
        example: "No example available for '$word'.",
        exampleTranslation: "暂无例句，请填入API Key获取更多例句",
        errorMessage: '解析结果失败',
      );
    }
  }

  /// 生成同根词/近义词/根词
  ///
  /// - 在没有API Key时返回null（调用方据此不显示）
  /// - 最多返回1个根词、至多[maxRelatives]个同根词、至多[maxSynonyms]个近义词
  static Future<WordRelationsResult?> generateWordRelations({
    required String word,
    required String translation,
    int maxRelatives = 3,
    int maxSynonyms = 3,
  }) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        // 无Key则不显示
        return null;
      }

      final prompt = _buildRelationsPrompt(word, translation, maxRelatives, maxSynonyms);

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'User-Agent': 'WordFlow/1.0',
      };

      final body = jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'system',
            'content': '你是一个专业的英语词源与词汇专家，帮助学习者提供简洁的同根词、近义词信息。只返回JSON。',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.5,
        'max_tokens': 300,
        'stream': false,
      });

      final response = await http
          .post(Uri.parse(_baseUrl), headers: headers, body: body)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['choices'] != null && jsonData['choices'].isNotEmpty) {
          final content = jsonData['choices'][0]['message']['content'];
          return _parseRelationsResult(content, maxRelatives, maxSynonyms);
        }
      }
    } catch (e) {
      // 忽略异常，返回null以便不显示
    }
    return null;
  }

  static String _buildRelationsPrompt(String word, String translation, int maxRelatives, int maxSynonyms) {
    return '''
请为以下英语单词提供同根词与近义词信息，并尽量简洁：

目标单词：$word
单词释义：$translation

要求：
1. root：最多给出1个该词的"词根/来源词"（若无法确定则置空字符串）
2. relatives：给出$maxRelatives个以内的同根词（派生/词形变化等），仅列出单词本身
3. synonyms：给出$maxSynonyms个以内的近义词，仅列出单词本身
4. 返回严格JSON，字段名固定：root、relatives、synonyms
5. 示例：
{
  "root": "",
  "relatives": ["related1", "related2"],
  "synonyms": ["syn1", "syn2"]
}
''';
  }

  static WordRelationsResult? _parseRelationsResult(String content, int maxRelatives, int maxSynonyms) {
    try {
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) return null;
      final jsonStr = jsonMatch.group(0)!;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      String? root = (data['root']?.toString() ?? '').trim();
      if (root.isEmpty) root = null;

      final relList = (data['relatives'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final synList = (data['synonyms'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      return WordRelationsResult(
        root: root,
        relatives: relList.take(maxRelatives).toList(),
        synonyms: synList.take(maxSynonyms).toList(),
      );
    } catch (e) {
      return null;
    }
  }
}

/// 造句判断结果
class SentenceJudgmentResult {
  final bool isCorrect;
  final int score;
  final List<String> errors;
  final List<String> suggestions;
  final List<String> betterSentences;
  final String? errorMessage;
  
  SentenceJudgmentResult({
    required this.isCorrect,
    this.score = 0,
    this.errors = const [],
    this.suggestions = const [],
    this.betterSentences = const [],
    this.errorMessage,
  });
}

/// 例句生成结果
class ExampleSentenceResult {
  final String example;
  final String exampleTranslation;
  final String? errorMessage;
  
  ExampleSentenceResult({
    required this.example,
    required this.exampleTranslation,
    this.errorMessage,
  });
}

/// 同根/近义词生成结果
class WordRelationsResult {
  final String? root; // 词根/来源词（可选）
  final List<String> relatives; // 同根词
  final List<String> synonyms; // 近义词

  WordRelationsResult({this.root, this.relatives = const [], this.synonyms = const []});
}