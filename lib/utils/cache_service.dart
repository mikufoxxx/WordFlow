import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_book.dart';
import 'performance_optimizer.dart';

/// 缓存服务
/// 负责管理词库数据的本地缓存
class CacheService {
  static const String _wordBooksKey = 'cached_word_books';
  static const String _wordDataPrefix = 'word_data_';
  static const String _downloadStatusPrefix = 'download_status_';
  static const String _selectedWordBookKey = 'selected_word_book';
  
  /// 缓存词库列表 - 同时更新内存缓存
  static Future<void> cacheWordBooks(List<WordBook> wordBooks) async {
    final prefs = await SharedPreferences.getInstance();
    final wordBooksJson = wordBooks.map((book) => book.toJson()).toList();
    await prefs.setString(_wordBooksKey, jsonEncode(wordBooksJson));
    
    // 同时更新内存缓存
    MemoryCache.set(_wordBooksKey, wordBooks);
  }
  
  /// 获取缓存的词库列表 - 优化内存缓存
  static Future<List<WordBook>> getCachedWordBooks() async {
    // 先检查内存缓存
    final cachedList = MemoryCache.get<List<WordBook>>(_wordBooksKey);
    if (cachedList != null) {
      return cachedList;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final wordBooksString = prefs.getString(_wordBooksKey);
    if (wordBooksString != null) {
      try {
        final wordBooksJson = jsonDecode(wordBooksString) as List;
        final wordBooks = wordBooksJson.map((json) => WordBook.fromJson(json)).toList();
        
        // 存入内存缓存
        MemoryCache.set(_wordBooksKey, wordBooks);
        return wordBooks;
      } catch (e) {
        print('❌ 解析缓存的词库数据失败: $e');
      }
    }
    return [];
  }
  
  /// 缓存单词数据
  static Future<void> cacheWordData(String wordBookName, List<WordData> wordData) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _wordDataPrefix + wordBookName.hashCode.toString();
    final wordDataJson = wordData.map((word) => {
      'word': word.word,
      'translation': word.translation,
    }).toList();
    await prefs.setString(key, jsonEncode(wordDataJson));
    
    // 同时缓存下载状态
    await prefs.setString(_downloadStatusPrefix + wordBookName.hashCode.toString(), 'downloaded');
  }
  
  /// 获取缓存的单词数据
  static Future<List<WordData>?> getCachedWordData(String wordBookName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _wordDataPrefix + wordBookName.hashCode.toString();
    final wordDataString = prefs.getString(key);
    if (wordDataString != null) {
      try {
        final wordDataJson = jsonDecode(wordDataString) as List;
        return wordDataJson.map((json) => WordData(
          word: json['word'],
          translation: json['translation'],
        )).toList();
      } catch (e) {
        print('❌ 解析缓存的单词数据失败: $e');
      }
    }
    return null;
  }
  
  /// 检查词库是否已下载
  static Future<bool> isWordBookDownloaded(String wordBookName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _downloadStatusPrefix + wordBookName.hashCode.toString();
    return prefs.getString(key) == 'downloaded';
  }
  
  /// 保存选中的词库
  static Future<void> saveSelectedWordBook(String wordBookName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedWordBookKey, wordBookName);
  }
  
  /// 获取选中的词库
  static Future<String?> getSelectedWordBook() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedWordBookKey);
  }
  
  /// 清除词库缓存
  static Future<void> clearWordBookCache(String wordBookName) async {
    final prefs = await SharedPreferences.getInstance();
    final wordDataKey = _wordDataPrefix + wordBookName.hashCode.toString();
    final statusKey = _downloadStatusPrefix + wordBookName.hashCode.toString();
    
    await prefs.remove(wordDataKey);
    await prefs.remove(statusKey);
  }
  
  /// 清除所有缓存
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith(_wordDataPrefix) || 
          key.startsWith(_downloadStatusPrefix) ||
          key == _wordBooksKey ||
          key == _selectedWordBookKey) {
        await prefs.remove(key);
      }
    }
  }
} 