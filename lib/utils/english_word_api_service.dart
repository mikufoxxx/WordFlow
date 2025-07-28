import 'dart:convert';
import 'package:http/http.dart' as http;

/// 英语单词API服务
/// 用于获取单词的详细信息：音标、释义、例句、发音等
class EnglishWordApiService {
  static const String _baseUrl = 'https://v2.xxapi.cn/api/englishwords';
  
  /// 获取单词详细信息
  /// 
  /// [word] 要查询的英语单词
  /// 返回 [WordDetailResponse] 包含单词的详细信息
  static Future<WordDetailResponse?> getWordDetails(String word) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl?word=${Uri.encodeComponent(word)}');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'WordFlow/1.0',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          return WordDetailResponse.fromJson(jsonData['data']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

/// 单词详情响应模型
class WordDetailResponse {
  final String word;
  final String ukPhone;      // 英音音标
  final String usPhone;      // 美音音标
  final String ukSpeech;     // 英音音频URL
  final String usSpeech;     // 美音音频URL
  final List<WordTranslation> translations;
  final List<WordSentence> sentences;
  final List<WordPhrase> phrases;
  final String bookId;
  
  WordDetailResponse({
    required this.word,
    required this.ukPhone,
    required this.usPhone,
    required this.ukSpeech,
    required this.usSpeech,
    required this.translations,
    required this.sentences,
    required this.phrases,
    required this.bookId,
  });
  
  factory WordDetailResponse.fromJson(Map<String, dynamic> json) {
    return WordDetailResponse(
      word: json['word'] ?? '',
      ukPhone: json['ukphone'] ?? '',
      usPhone: json['usphone'] ?? '',
      ukSpeech: json['ukspeech'] ?? '',
      usSpeech: json['usspeech'] ?? '',
      translations: (json['translations'] as List<dynamic>?)
          ?.map((e) => WordTranslation.fromJson(e))
          .toList() ?? [],
      sentences: (json['sentences'] as List<dynamic>?)
          ?.map((e) => WordSentence.fromJson(e))
          .toList() ?? [],
      phrases: (json['phrases'] as List<dynamic>?)
          ?.map((e) => WordPhrase.fromJson(e))
          .toList() ?? [],
      bookId: json['bookId'] ?? '',
    );
  }
}

/// 单词翻译模型
class WordTranslation {
  final String pos;      // 词性
  final String tranCn;   // 中文翻译
  
  WordTranslation({
    required this.pos,
    required this.tranCn,
  });
  
  factory WordTranslation.fromJson(Map<String, dynamic> json) {
    return WordTranslation(
      pos: json['pos'] ?? '',
      tranCn: json['tran_cn'] ?? '',
    );
  }
}

/// 单词例句模型
class WordSentence {
  final String sContent;   // 英文例句
  final String sCn;        // 中文翻译
  
  WordSentence({
    required this.sContent,
    required this.sCn,
  });
  
  factory WordSentence.fromJson(Map<String, dynamic> json) {
    return WordSentence(
      sContent: json['s_content'] ?? '',
      sCn: json['s_cn'] ?? '',
    );
  }
}

/// 单词短语模型
class WordPhrase {
  final String pContent;   // 英文短语
  final String pCn;        // 中文翻译
  
  WordPhrase({
    required this.pContent,
    required this.pCn,
  });
  
  factory WordPhrase.fromJson(Map<String, dynamic> json) {
    return WordPhrase(
      pContent: json['p_content'] ?? '',
      pCn: json['p_cn'] ?? '',
    );
  }
}

/// 发音类型枚举
enum PronunciationType {
  uk,    // 英音
  us,    // 美音
}

/// 获取发音类型的显示名称
extension PronunciationTypeExtension on PronunciationType {
  String get displayName {
    switch (this) {
      case PronunciationType.uk:
        return '英音';
      case PronunciationType.us:
        return '美音';
    }
  }
  
  String get code {
    switch (this) {
      case PronunciationType.uk:
        return 'uk';
      case PronunciationType.us:
        return 'us';
    }
  }
} 