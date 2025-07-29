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
    {
      "type": "语法错误/用法错误/拼写错误/表达问题",
      "description": "错误描述",
      "position": "错误位置"
    }
  ],
  "suggestions": [
    "修改建议1",
    "修改建议2"
  ],
  "betterSentences": [
    "更好的句子示例1（必须包含目标单词$word）",
    "更好的句子示例2（必须包含目标单词$word）"
  ]
}

如果句子完全正确，errors数组为空，suggestions可以提供一些让句子更地道的建议。
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
      final errors = (jsonData['errors'] as List?)?.map((e) => 
        SentenceError(
          type: e['type'] ?? '',
          description: e['description'] ?? '',
          position: e['position'] ?? '',
        )
      ).toList() ?? [];
      
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
          example: "This is an example sentence with the word '$word'.",
          exampleTranslation: "这是一个包含单词'$word'的例句。",
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
          example: "This is an example sentence with the word '$word'.",
          exampleTranslation: "这是一个包含单词'$word'的例句。",
          errorMessage: '请求失败：${errorData['error']['message'] ?? '未知错误'}',
        );
      }
      
    } catch (e) {
      return ExampleSentenceResult(
        example: "This is an example sentence with the word '$word'.",
        exampleTranslation: "这是一个包含单词'$word'的例句。",
        errorMessage: '网络请求失败，请检查网络连接',
      );
    }
    
    return ExampleSentenceResult(
      example: "This is an example sentence with the word '$word'.",
      exampleTranslation: "这是一个包含单词'$word'的例句。",
    );
  }

  /// 构建例句生成提示词
  static String _buildExamplePrompt(String word, String translation) {
    return '''
请为以下英语单词生成一个简洁明了的例句：

目标单词：$word
单词释义：$translation

要求：
1. 例句要简短（不超过15个单词）
2. 语法正确，表达自然
3. 能够清楚体现单词的含义和用法
4. 适合英语学习者理解
5. 使用常见词汇，避免过于复杂的表达

请严格按照以下JSON格式返回结果：
{
  "example": "包含目标单词的英文例句",
  "translation": "例句的中文翻译"
}
''';
  }

  /// 解析例句生成结果
  static ExampleSentenceResult _parseExampleResult(String content, String word) {
    try {
      // 尝试提取JSON部分
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) {
        return ExampleSentenceResult(
          example: "This is an example sentence with the word '$word'.",
          exampleTranslation: "这是一个包含单词'$word'的例句。",
          errorMessage: '解析响应失败',
        );
      }
      
      final jsonStr = jsonMatch.group(0)!;
      final jsonData = jsonDecode(jsonStr);
      
      final example = jsonData['example'] ?? "This is an example sentence with the word '$word'.";
      final translation = jsonData['translation'] ?? "这是一个包含单词'$word'的例句。";
      
      return ExampleSentenceResult(
        example: example,
        exampleTranslation: translation,
      );
      
    } catch (e) {
      return ExampleSentenceResult(
        example: "This is an example sentence with the word '$word'.",
        exampleTranslation: "这是一个包含单词'$word'的例句。",
        errorMessage: '解析结果失败',
      );
    }
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
}

/// 造句判断结果
class SentenceJudgmentResult {
  final bool isCorrect;
  final int score;
  final List<SentenceError> errors;
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

/// 句子错误信息
class SentenceError {
  final String type;
  final String description;
  final String position;
  
  SentenceError({
    required this.type,
    required this.description,
    required this.position,
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