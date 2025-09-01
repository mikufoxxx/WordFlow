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
  // 新增：同根词/同义词
  final List<WordRelGroup> relWords;
  final List<WordSynGroup> synonyms;
  
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
    this.relWords = const [],
    this.synonyms = const [],
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
      relWords: (json['relWords'] as List<dynamic>?)
              ?.map((e) => WordRelGroup.fromJson(e))
              .toList() ?? [],
      synonyms: (json['synonyms'] as List<dynamic>?)
              ?.map((e) => WordSynGroup.fromJson(e))
              .toList() ?? [],
    );
  }
}

/// 单词翻译模型
class WordTranslation {
  final String pos;         // 词性
  final String tranCn;      // 中文翻译
  
  WordTranslation({
    required this.pos,
    required this.tranCn,
  });
  
  factory WordTranslation.fromJson(Map<String, dynamic> json) {
    return WordTranslation(
      pos: json['pos']?.toString() ?? '',
      tranCn: json['tran_cn']?.toString() ?? '',
    );
  }
}

/// 单词例句模型
class WordSentence {
  final String sContent;    // 英文例句
  final String sCn;         // 中文翻译
  
  WordSentence({
    required this.sContent,
    required this.sCn,
  });
  
  factory WordSentence.fromJson(Map<String, dynamic> json) {
    return WordSentence(
      sContent: json['s_content']?.toString() ?? '',
      sCn: json['s_cn']?.toString() ?? '',
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

/// 同根词分组（按词性）
class WordRelGroup {
  final String pos; // 词性，注意API可能返回Pos
  final List<RelHwd> hwds;

  WordRelGroup({required this.pos, required this.hwds});

  factory WordRelGroup.fromJson(Map<String, dynamic> json) {
    final rawHwds = (json['Hwds'] as List<dynamic>?) ?? [];
    return WordRelGroup(
      pos: (json['Pos'] ?? json['pos'] ?? '').toString(),
      hwds: rawHwds.map((e) => RelHwd.fromJson(e)).toList(),
    );
  }
}

class RelHwd {
  final String hwd;  // 单词
  final String tran; // 翻译

  RelHwd({required this.hwd, required this.tran});

  factory RelHwd.fromJson(Map<String, dynamic> json) {
    return RelHwd(
      hwd: json['hwd']?.toString() ?? '',
      tran: json['tran']?.toString() ?? '',
    );
  }
}

/// 近义词分组
class WordSynGroup {
  final String pos; // 词性
  final String tran; // 翻译概述
  final List<SynHwd> hwds;

  WordSynGroup({required this.pos, required this.tran, required this.hwds});

  factory WordSynGroup.fromJson(Map<String, dynamic> json) {
    final rawHwds = (json['Hwds'] as List<dynamic>?) ?? [];
    return WordSynGroup(
      pos: (json['pos'] ?? json['Pos'] ?? '').toString(),
      tran: (json['tran'] ?? json['tran_cn'] ?? '').toString(),
      hwds: rawHwds.map((e) => SynHwd.fromJson(e)).toList(),
    );
  }
}

class SynHwd {
  final String word;

  SynHwd({required this.word});

  factory SynHwd.fromJson(Map<String, dynamic> json) {
    return SynHwd(
      word: (json['word'] ?? json['hwd'] ?? '').toString(),
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