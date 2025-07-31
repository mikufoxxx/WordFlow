// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/word_book.dart';

/// Gitee API服务 (原GitHub API服务)
/// 用于从指定的Gitee仓库获取词库数据
/// 现在使用 https://gitee.com/mikufoxxx/maimemo-export 作为数据源
class GitHubApiService {
  // Gitee配置
  static const String _giteeBaseUrl = 'https://gitee.com';
  static const String _owner = 'mikufoxxx';
  static const String _repo = 'maimemo-export';
  static const String _branch = 'main';
  
  // GitHub备用配置
  static const String _githubRawUrl = 'https://raw.githubusercontent.com';
  static const String _githubOwner = 'busiyiworld';
  
  // 镜像源配置
  static const String _mirrorBaseUrl = 'http://git.techox.cc';
  
  // 网络请求超时时间
  static const Duration _timeout = Duration(seconds: 15);
  
  /// 获取词库列表
  /// 从Gitee仓库的词库.md文件解析词库信息，只获取词库名和翻译CSV链接
  static Future<List<WordBook>> getWordBooks() async {

    // 优先使用镜像源，然后Gitee源，最后GitHub源
    final urls = [
      // 镜像源 (最高优先级)
      '$_mirrorBaseUrl/$_githubRawUrl/$_githubOwner/$_repo/$_branch/%E8%AF%8D%E5%BA%93.md',
      
      // Gitee源
      '$_giteeBaseUrl/$_owner/$_repo/raw/$_branch/%E8%AF%8D%E5%BA%93.md',
      
      // GitHub直连 (备用)
      '$_githubRawUrl/$_githubOwner/$_repo/$_branch/%E8%AF%8D%E5%BA%93.md',
      'https://github.com/$_githubOwner/$_repo/raw/$_branch/%E8%AF%8D%E5%BA%93.md',
    ];
    
    for (String urlString in urls) {
      try {

        final url = Uri.parse(urlString);
        final response = await http.get(
          url,
          headers: {
            'User-Agent': 'WordFlow-App/1.0',
            'Accept': 'text/plain, application/octet-stream',
            'Referer': urlString.contains('gitee.com') ? 'https://gitee.com' : 'https://github.com',
          },
        ).timeout(_timeout);
        
        if (response.statusCode == 200) {

          // 解析Markdown表格内容
          final content = utf8.decode(response.bodyBytes);
          final wordBooks = _parseMarkdownTable(content);
          
          if (wordBooks.isNotEmpty) {
            return wordBooks;
          } else {
          }
        } else {
        }
        
      } on SocketException {
        continue; // 尝试下一个URL
      } on HttpException {
        continue;
      } on FormatException {
        continue;
      } catch (e) {
        continue;
      }
    }
    
    return _getExpandedDefaultWordBooks();
  }
  
  /// 解析Markdown表格，提取词库名和翻译CSV链接
  static List<WordBook> _parseMarkdownTable(String content) {
    final List<WordBook> wordBooks = [];
    final lines = content.split('\n');
    

    // 找到表格开始的位置（包含"词库名"的行）
    int tableStartIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('词库名') && lines[i].contains('单词和翻译')) {
        tableStartIndex = i + 2; // 跳过表头和分隔符行
        break;
      }
    }
    
    if (tableStartIndex == -1) {
      return [];
    }
    
    // 解析表格行
    int validRows = 0;
    for (int i = tableStartIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // 检查是否是有效的表格行
      if (line.isEmpty || !line.startsWith('|') || !line.endsWith('|')) {
        continue;
      }
      
      try {
        final wordBook = _parseTableRow(line);
        if (wordBook != null) {
          wordBooks.add(wordBook);
          validRows++;
        }
      } catch (e) {
        continue;
      }
    }
    
    return wordBooks;
  }
  
  /// 解析单个表格行，提取词库信息
  static WordBook? _parseTableRow(String line) {
    // 移除首尾的 | 符号，然后按 | 分割
    final cleanLine = line.substring(1, line.length - 1);
    final columns = cleanLine.split('|').map((e) => e.trim()).toList();
    
    if (columns.length < 4) {
      return null; // 至少需要4列：词库名、仅单词、单词和章节、单词和翻译
    }
    
    final name = columns[0].trim();
    final translationColumn = columns[3].trim(); // "单词和翻译"是第4列
    
    if (name.isEmpty || translationColumn.isEmpty) {
      return null;
    }
    
    // 提取翻译CSV链接
    final translationUrl = _extractLinkFromMarkdown(translationColumn);
    
    if (translationUrl.isEmpty) {
      return null;
    }
    
    // 构建完整的URL - 使用blob格式（按用户要求）
    String fullUrl;
    if (translationUrl.startsWith('http')) {
      fullUrl = translationUrl;
    } else {
      // 相对路径，构建为Gitee blob URL
      final cleanPath = translationUrl.replaceFirst('./', '');
      fullUrl = '$_giteeBaseUrl/$_owner/$_repo/blob/$_branch/$cleanPath';
    }
    
    // 尝试从名称中提取单词数量
    int wordCount = _extractWordCountFromName(name);
    
    return WordBook(
      name: name,
      translationUrl: fullUrl,
      wordCount: wordCount,
    );
  }
  
  /// 从词库名称中提取单词数量
  static int _extractWordCountFromName(String name) {
    final numberPattern = RegExp(r'(\d+)(?=个|\s|词|单词)');
    final match = numberPattern.firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }
  
  /// 从Markdown链接格式中提取URL
  /// 例如：[📖](./exported/translation/词库名.csv) -> ./exported/translation/词库名.csv
  static String _extractLinkFromMarkdown(String markdown) {
    final linkPattern = RegExp(r'\[.*?\]\((.*?)\)');
    final match = linkPattern.firstMatch(markdown);
    return match?.group(1) ?? '';
  }
  
  /// 获取指定词库的单词数据
  /// 下载CSV文件并解析为WordData列表
  /// 优先使用镜像源，然后尝试其他源
  static Future<List<WordData>> getWordData(String csvUrl) async {

    // 构建多个尝试的URL，优先使用镜像源
    final urlsToTry = _buildUrlsToTry(csvUrl);
    
    // 尝试每个URL
    for (final urlInfo in urlsToTry) {
      try {

        final response = await http.get(
          Uri.parse(urlInfo['url']!),
          headers: {
            'User-Agent': 'WordFlow-App/1.0',
            'Accept': 'text/csv, text/plain, application/octet-stream',
            'Referer': urlInfo['referer'] ?? 'https://github.com',
          },
        ).timeout(_timeout);
        
        if (response.statusCode == 200) {
          final content = utf8.decode(response.bodyBytes);
          final words = _parseCsvContent(content);
          return words;
        } else {
        }
        
      } on SocketException {
        continue;
      } catch (e) {
        continue;
      }
    }
    
    return _getDefaultWordData();
  }
  
  /// 构建URL尝试列表，优先使用镜像源
  static List<Map<String, String>> _buildUrlsToTry(String originalUrl) {
    final urlsToTry = <Map<String, String>>[];
    
    if (originalUrl.contains('gitee.com')) {
      // Gitee URL处理
      String giteeRawUrl = originalUrl;
      if (originalUrl.contains('/blob/')) {
        giteeRawUrl = originalUrl.replaceAll('/blob/', '/raw/');
      }
      
      // 构造对应的GitHub URL
      final githubUrl = giteeRawUrl
          .replaceAll('gitee.com/$_owner', 'raw.githubusercontent.com/$_githubOwner')
          .replaceAll('/raw/', '/');
      
      // 1. 镜像源 (最高优先级)
      urlsToTry.add({
        'url': '$_mirrorBaseUrl/$githubUrl',
        'source': '镜像源',
        'referer': 'https://github.com',
      });
      
      // 2. Gitee原始URL
      urlsToTry.add({
        'url': giteeRawUrl,
        'source': 'Gitee',
        'referer': 'https://gitee.com',
      });
      
      // 3. GitHub直连
      urlsToTry.add({
        'url': githubUrl,
        'source': 'GitHub直连',
        'referer': 'https://github.com',
      });
      
    } else if (originalUrl.contains('raw.githubusercontent.com')) {
      // 已经是GitHub raw URL
      
      // 1. 镜像源 (最高优先级)
      urlsToTry.add({
        'url': '$_mirrorBaseUrl/$originalUrl',
        'source': '镜像源',
        'referer': 'https://github.com',
      });
      
      // 2. GitHub直连
      urlsToTry.add({
        'url': originalUrl,
        'source': 'GitHub直连',
        'referer': 'https://github.com',
      });
      
    } else if (originalUrl.contains('github.com')) {
      // GitHub页面URL，转换为raw URL
      final rawUrl = originalUrl
          .replaceAll('github.com', 'raw.githubusercontent.com')
          .replaceAll('/blob/', '/');
      
      // 1. 镜像源 (最高优先级)
      urlsToTry.add({
        'url': '$_mirrorBaseUrl/$rawUrl',
        'source': '镜像源',
        'referer': 'https://github.com',
      });
      
      // 2. GitHub直连
      urlsToTry.add({
        'url': rawUrl,
        'source': 'GitHub直连',
        'referer': 'https://github.com',
      });
      
    } else {
      // 其他URL，直接使用
      urlsToTry.add({
        'url': originalUrl,
        'source': '原始URL',
        'referer': 'https://github.com',
      });
    }
    
    return urlsToTry;
  }
  
  /// 解析CSV内容为WordData列表
  static List<WordData> _parseCsvContent(String content) {
    final List<WordData> words = [];
    final lines = content.split('\n');
    
    // 跳过表头（如果存在）
    int startIndex = 0;
    if (lines.isNotEmpty && 
        (lines[0].toLowerCase().contains('word') || 
         lines[0].toLowerCase().contains('单词'))) {
      startIndex = 1;
    }
    
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      try {
        final columns = line.split(',');
        if (columns.length >= 2) {
          final wordData = WordData.fromCsvRow(columns);
          if (wordData.word.isNotEmpty && wordData.translation.isNotEmpty) {
            words.add(wordData);
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    return words;
  }
  
  /// 扩展的默认词库数据（作为fallback）
  static List<WordBook> _getExpandedDefaultWordBooks() {
    return [
      // 高考/中学词汇
      const WordBook(
        name: '高考核心词汇3500',
        translationUrl: 'local://gaokao-3500',
        wordCount: 3500,
      ),
      const WordBook(
        name: '中考必备词汇2000',
        translationUrl: 'local://zhongkao-2000',
        wordCount: 2000,
      ),
      
      // 大学英语词汇
      const WordBook(
        name: 'CET-4核心词汇4000',
        translationUrl: 'local://cet4-4000',
        wordCount: 4000,
      ),
      const WordBook(
        name: 'CET-6核心词汇2500',
        translationUrl: 'local://cet6-2500',
        wordCount: 2500,
      ),
      
      // 考研词汇
      const WordBook(
        name: '考研英语词汇5500',
        translationUrl: 'local://kaoyan-5500',
        wordCount: 5500,
      ),
      
      // 出国考试词汇
      const WordBook(
        name: 'TOEFL托福词汇7000',
        translationUrl: 'local://toefl-7000',
        wordCount: 7000,
      ),
      const WordBook(
        name: 'IELTS雅思词汇7000',
        translationUrl: 'local://ielts-7000',
        wordCount: 7000,
      ),
      const WordBook(
        name: 'GRE核心词汇8000',
        translationUrl: 'local://gre-8000',
        wordCount: 8000,
      ),
      
      // 商务/职场英语
      const WordBook(
        name: 'BEC商务英语词汇3000',
        translationUrl: 'local://bec-3000',
        wordCount: 3000,
      ),
      
      // 基础词汇
      const WordBook(
        name: '小学英语词汇800',
        translationUrl: 'local://primary-800',
        wordCount: 800,
      ),
      
      // 来自镜像源的样例数据 - 优先使用镜像访问
      WordBook(
        name: '100个句子记完3500个高考单词',
        translationUrl: '$_mirrorBaseUrl/https://raw.githubusercontent.com/$_githubOwner/$_repo/main/exported/translation/100%E4%B8%AA%E5%8F%A5%E5%AD%90%E8%AE%B0%E5%AE%8C3500%E4%B8%AA%E9%AB%98%E8%80%83%E5%8D%95%E8%AF%8D.csv',
        wordCount: 3500,
      ),
      WordBook(
        name: '100个句子记完5500个考研单词（2025）',
        translationUrl: '$_mirrorBaseUrl/https://raw.githubusercontent.com/$_githubOwner/$_repo/main/exported/translation/100%E4%B8%AA%E5%8F%A5%E5%AD%90%E8%AE%B0%E5%AE%8C5500%E4%B8%AA%E8%80%83%E7%A0%94%E5%8D%95%E8%AF%8D%EF%BC%882025%EF%BC%89.csv',
        wordCount: 5500,
      ),
    ];
  }
  
  /// 默认单词数据（用于测试和离线模式）
  static List<WordData> _getDefaultWordData() {
    return [
      const WordData(word: 'hello', translation: '你好'),
      const WordData(word: 'world', translation: '世界'),
      const WordData(word: 'flutter', translation: 'Flutter框架'),
      const WordData(word: 'dart', translation: 'Dart语言'),
      const WordData(word: 'mobile', translation: '移动的'),
      const WordData(word: 'application', translation: '应用程序'),
      const WordData(word: 'development', translation: '开发'),
      const WordData(word: 'framework', translation: '框架'),
      const WordData(word: 'language', translation: '语言'),
      const WordData(word: 'programming', translation: '编程'),
      const WordData(word: 'study', translation: '学习'),
      const WordData(word: 'vocabulary', translation: '词汇'),
      const WordData(word: 'english', translation: '英语'),
      const WordData(word: 'learning', translation: '学习中'),
      const WordData(word: 'memory', translation: '记忆'),
      const WordData(word: 'practice', translation: '练习'),
      const WordData(word: 'progress', translation: '进步'),
      const WordData(word: 'knowledge', translation: '知识'),
      const WordData(word: 'education', translation: '教育'),
      const WordData(word: 'improvement', translation: '改进'),
    ];
  }
  
  /// 网络连接诊断
  static Future<bool> checkNetworkConnection() async {
    try {
      // 先尝试镜像源连接
      final mirrorResponse = await http.get(
        Uri.parse(_mirrorBaseUrl),
        headers: {'User-Agent': 'WordFlow-App/1.0'},
      ).timeout(const Duration(seconds: 5));
      
      if (mirrorResponse.statusCode == 200) {
        return true;
      }
      
      // 再尝试Gitee连接
      final giteeResponse = await http.get(
        Uri.parse('https://gitee.com'),
        headers: {'User-Agent': 'WordFlow-App/1.0'},
      ).timeout(const Duration(seconds: 5));
      
      if (giteeResponse.statusCode == 200) {
        return true;
      }
      
      // 最后尝试GitHub
      final githubResponse = await http.get(
        Uri.parse('https://github.com'),
        headers: {'User-Agent': 'WordFlow-App/1.0'},
      ).timeout(const Duration(seconds: 5));
      
      return githubResponse.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
} 