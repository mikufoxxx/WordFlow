/// 词库模型
/// 表示一个可选择的词库，包含基本信息和词汇数据链接
class WordBook {
  final String name;           // 词库名称
  final String translationUrl; // 单词和翻译CSV文件的URL
  final int wordCount;         // 单词数量（可选，默认为0）
  
  const WordBook({
    required this.name,
    required this.translationUrl,
    this.wordCount = 0,
  });

  /// 从JSON创建WordBook对象
  factory WordBook.fromJson(Map<String, dynamic> json) {
    return WordBook(
      name: json['name'] ?? '',
      translationUrl: json['translationUrl'] ?? '',
      wordCount: json['wordCount'] ?? 0,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'translationUrl': translationUrl,
      'wordCount': wordCount,
    };
  }

  /// 生成封面颜色（初音莫奈配色）
  int get coverColor {
    final hash = name.hashCode;
    final colors = [
      0xFF60B473, // 绿色调
      0xFF60B488, // 绿青色调
      0xFF60B49D, // 主要初音色
      0xFF60B4B2, // 青色调
      0xFF60A1B4, // 蓝色调
    ];
    return colors[hash.abs() % colors.length];
  }

  /// 获取封面图标颜色
  int get iconColor {
    return 0xFFFFFFFF; // 改为白色图标，更清晰
  }

  @override
  String toString() => 'WordBook(name: $name, wordCount: $wordCount)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordBook && 
           other.name == name && 
           other.translationUrl == translationUrl;
  }
  
  @override
  int get hashCode => name.hashCode ^ translationUrl.hashCode;
}

/// 单词数据模型
/// 表示一个具体的单词及其翻译
class WordData {
  final String word;        // 英文单词
  final String translation; // 中文翻译
  
  const WordData({
    required this.word,
    required this.translation,
  });

  /// 从CSV行创建WordData对象
  factory WordData.fromCsvRow(List<String> row) {
    return WordData(
      word: row.isNotEmpty ? row[0].trim() : '',
      translation: row.length > 1 ? row[1].trim() : '',
    );
  }

  @override
  String toString() => 'WordData(word: $word, translation: $translation)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordData && 
           other.word == word && 
           other.translation == translation;
  }
  
  @override
  int get hashCode => word.hashCode ^ translation.hashCode;
} 