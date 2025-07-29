// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import '../models/word_book.dart';
import '../models/word_learning_record.dart';
import '../utils/cache_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/performance_optimizer.dart';
import '../utils/english_word_api_service.dart';
import '../utils/settings_helper.dart';
import '../utils/deepseek_api_service.dart';
import '../utils/learning_data_service.dart';
import '../utils/algorithm_manager.dart';
import '../utils/app_theme.dart';
import '../utils/sound_service.dart';

/// 修改类型枚举
enum ModificationType {
  none,      // 无修改
  grammar,   // 语法修改
  idiomatic, // 地道性改进
  simplicity, // 简单性改进（句子过于简单）
}

/// 单词修改信息
class WordModificationInfo {
  final bool isModified;
  final ModificationType modificationType;
  
  WordModificationInfo({
    required this.isModified,
    required this.modificationType,
  });
}

/// 主页 - 背单词页面
/// 以流的形式显示单词，每次显示一个单词，背过就显示下一个
/// 支持无限流模式，从词库中随机获取单词
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> 
    with TickerProviderStateMixin {
  
  // 音频播放器
  late AudioPlayer _audioPlayer;
  
  // 性能优化：使用池化的key
  static const String _animationPoolKey = 'home_page_animations';
  static const String _timerPoolKey = 'home_page_timers';
  static const String _audioTimerPoolKey = 'home_page_audio_timers'; // 独立的音频定时器池
  
  // 当前学习的单词数量（无限流模式）
  int _todayStudiedCount = 0;
  int _totalStudiedCount = 0;
  
  // 是否显示单词释义
  bool _showMeaning = false;
  
  // 单词动画是否完成
  bool _wordAnimationCompleted = false;
  
  // 主要动画控制器 - 使用性能优化器管理
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _meaningController;
  late AnimationController _buttonsController;

  
  // 释义框动画
  late Animation<double> _meaningHeightAnimation;
  late Animation<double> _meaningOpacityAnimation;
  late Animation<double> _meaningScaleAnimation;
  
  // 按钮动画
  late Animation<double> _buttonsOpacityAnimation;
  late Animation<double> _buttonsSlideAnimation;
  
  // 字符级动画控制器
  List<AnimationController> _wordControllers = [];
  List<AnimationController> _translationControllers = [];
  List<AnimationController> _meaningControllers = [];
  List<AnimationController> _exampleControllers = [];
  List<AnimationController> _exampleTranslationControllers = [];
  
  // 字符级动画
  List<Animation<double>> _wordSlideAnimations = [];
  List<Animation<double>> _wordOpacityAnimations = [];
  List<Animation<double>> _translationSlideAnimations = [];
  List<Animation<double>> _translationOpacityAnimations = [];
  List<Animation<double>> _exampleSlideAnimations = [];
  List<Animation<double>> _exampleOpacityAnimations = [];
  List<Animation<double>> _exampleTranslationSlideAnimations = [];
  List<Animation<double>> _exampleTranslationOpacityAnimations = [];
  

  
  // 单词动画完成计数器
  int _completedWordAnimations = 0;
  
  // 词库数据 - 从缓存加载
  List<WordData> _words = [];
  bool _isLoadingWords = true;
  String? _currentWordBookName;
  String? _errorMessage;
  
  // 随机数生成器（用于无限流模式）
  final Random _random = Random();
  
  // 当前显示的单词（扩展版本，包含音标、例句等）
  ExtendedWordData? _currentWord;
  
  // 撤回功能相关
  ExtendedWordData? _previousWord;
  
  // 造句测试相关状态
  bool _showSentenceInput = false;
  bool _isTestingMode = false;
  bool _isSentenceSubmitted = false;
  bool _isJudging = false;
  final TextEditingController _sentenceInputController = TextEditingController();
  SentenceJudgmentResult? _judgmentResult;
  String _userSentence = '';
  late AnimationController _sentenceAnimationController;
  late AnimationController _wordMoveController;
  late Animation<double> _wordScaleAnimation;
  late Animation<double> _wordMoveAnimation;
  late Animation<double> _sentenceInputAnimation;
  
  // 逐字母浮现动画相关
  List<AnimationController> _betterSentenceControllers = [];
  List<Animation<double>> _betterSentenceAnimations = [];
  String _betterSentenceText = '';
  bool _showBetterSentenceAnimation = false;
  bool _showAdvancedResults = false;
  
  // 结果区域向上浮现动画
  late AnimationController _resultAreaController;
  late Animation<double> _resultAreaAnimation;
  
  // 按钮淡出动画
  late AnimationController _skipButtonFadeController;
  late Animation<double> _skipButtonFadeAnimation;
  late AnimationController _sendButtonFadeController;
  late Animation<double> _sendButtonFadeAnimation;
  
  // 输入框相关
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeAlgorithmManager();
    _initializeAudioPlayer();
    _initializeMainAnimations();
    _loadWordsFromSelectedWordBook();
  }

  /// 初始化算法管理器
  Future<void> _initializeAlgorithmManager() async {
      await AlgorithmManager.instance.initialize();
  }

  /// 更新学习统计
  Future<void> _updateLearningStats() async {
    if (_currentWordBookName == null) return;
      final records = await LearningDataService.instance.getWordBookRecords(_currentWordBookName!);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
      // 计算今日学习的单词数（基于最后学习时间）
      final todayRecords = records.where((record) {
        return record.lastLearningTime.isAfter(todayStart) && 
               record.lastLearningTime.isBefore(todayEnd);
      }).toList();
      
      setState(() {
        _todayStudiedCount = todayRecords.length;
        _totalStudiedCount = records.length;
      });
  }

  /// 检查并重新加载词库（仅在词库发生变化时）
  Future<void> _checkAndReloadWordBook() async {
    try {
      // 获取当前选中的词库名称
      final selectedWordBookName = await CacheService.getSelectedWordBook();
      
      // 如果词库名称没有变化，则不需要重新加载
      if (selectedWordBookName == _currentWordBookName) {
        return;
      }
      
      // 词库发生了变化，重新加载
      await _loadWordsFromSelectedWordBook();
    } catch (e) {
      // 如果检查失败，安全起见还是重新加载
      await _loadWordsFromSelectedWordBook();
    }
  }

  /// 加载选中词库的单词数据
  Future<void> _loadWordsFromSelectedWordBook() async {
    try {
      setState(() {
        _isLoadingWords = true;
        _errorMessage = null;
      });
      
      // 获取当前选中的词库名称
      final selectedWordBookName = await CacheService.getSelectedWordBook();
      
      if (selectedWordBookName == null || selectedWordBookName.isEmpty) {
        setState(() {
          _errorMessage = '请先选择一个词库';
          _isLoadingWords = false;
        });
        return;
      }
      
      // 从缓存加载词库数据
      final wordData = await CacheService.getCachedWordData(selectedWordBookName);
      
      if (wordData == null || wordData.isEmpty) {
        setState(() {
          _errorMessage = '词书好像空了，去收集一些新词汇吧';
          _isLoadingWords = false;
        });
        return;
      }
      
      setState(() {
        _words = wordData;
        _currentWordBookName = selectedWordBookName;
        _isLoadingWords = false;
      });
      
      // 生成第一个单词
      await _generateNextWord();
      
      // 更新学习统计
      await _updateLearningStats();
      
    _initializeCharacterAnimations();
    _startWordAnimation();
      
    } catch (e) {
      setState(() {
        _errorMessage = '词汇好像迷路了: $e';
        _isLoadingWords = false;
      });
    }
  }

  /// 生成下一个单词（扩展版本）
  Future<void> _generateNextWord() async {
    if (_words.isEmpty) return;
    
    // 随机选择一个单词
    final randomIndex = _random.nextInt(_words.length);
    final wordData = _words[randomIndex];
    
    // 获取当前发音类型设置
    final pronunciationType = await SettingsHelper.getPronunciationType();
    
    // 创建扩展的单词数据（从API获取详细信息）
    _currentWord = await ExtendedWordData.fromWordData(wordData, pronunciationType);
  }

  /// 初始化音频播放器
  void _initializeAudioPlayer() {
    _audioPlayer = AudioPlayer();
  }

  /// 播放单词发音
  Future<void> _playWordPronunciation() async {
    if (_currentWord == null || !mounted) return;
    
    try {
      final pronunciationType = await SettingsHelper.getPronunciationType();
      final audioUrl = _currentWord!.getValidAudioUrl(pronunciationType);
      
      if (audioUrl != null && audioUrl.isNotEmpty && mounted) {
        // 确保音频播放器处于可用状态
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
      }
    } catch (e) {
      // 发音播放失败时静默处理，不影响用户体验
      debugPrint('发音播放失败: $e');
    }
  }



  /// 初始化主要动画控制器 - 使用性能优化器
  void _initializeMainAnimations() {
    // 使用性能优化器获取动画控制器
    _fadeController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _meaningController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _buttonsController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    
    // 造句测试动画控制器
    _sentenceAnimationController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _wordMoveController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    
    // 释义框动画
    _meaningHeightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _meaningController,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInQuart,
    ));
    
    _meaningOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _meaningController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    
    _meaningScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _meaningController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    ));
    
    // 按钮动画
    _buttonsOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonsController,
      curve: Curves.easeOutCubic,
    ));
    
    _buttonsSlideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _buttonsController,
      curve: Curves.easeOutQuart,
    ));
    
    // 造句测试动画
    _wordScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _wordMoveController,
      curve: Curves.easeOutQuart,
    ));
    
    _wordMoveAnimation = Tween<double>(
      begin: 0.0,
      end: -30.0,
    ).animate(CurvedAnimation(
      parent: _wordMoveController,
      curve: Curves.easeOutQuart,
    ));
    
    _sentenceInputAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sentenceAnimationController,
      curve: Curves.easeOutQuart,
    ));
    
    // 结果区域向上浮现动画
    _resultAreaController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _resultAreaAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _resultAreaController,
      curve: Curves.easeOutQuart,
    ));
    
    // 跳过按钮淡出动画
    _skipButtonFadeController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _skipButtonFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _skipButtonFadeController,
      curve: Curves.easeOutCubic,
    ));
    
    // 发送按钮淡出动画
    _sendButtonFadeController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _sendButtonFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _sendButtonFadeController,
      curve: Curves.easeOutCubic,
    ));
    

  }

  /// 初始化字符级动画
  void _initializeCharacterAnimations() {
    if (_currentWord == null) return;
    
    final currentWord = _currentWord!;
    
    // 重置状态
    _wordAnimationCompleted = false;
    _completedWordAnimations = 0;
    
    // 清理旧的控制器
    _disposeCharacterControllers();
    
    // 单词字符动画
    _wordControllers = List.generate(
      currentWord.word.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );
    
    // 为每个单词字符添加完成监听器
    for (int i = 0; i < _wordControllers.length; i++) {
      _wordControllers[i].addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _completedWordAnimations++;
          if (_completedWordAnimations >= _wordControllers.length) {
            _onWordAnimationCompleted();
          }
        }
      });
    }
    
    _wordSlideAnimations = _wordControllers.map((controller) =>
      Tween<double>(begin: 15.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _wordOpacityAnimations = _wordControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
    
    // 翻译字符动画 - 始终使用字符级动画
    _translationControllers = List.generate(
      currentWord.translation.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    
    _translationSlideAnimations = _translationControllers.map((controller) =>
      Tween<double>(begin: 12.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _translationOpacityAnimations = _translationControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
    
    // 释义字符动画 - 始终使用字符级动画
    _meaningControllers = List.generate(
      currentWord.translation.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    


    // 例句单词动画 - 改为单词级动画以优化性能
    final exampleWords = currentWord.example.trim().split(RegExp(r'\s+'));
    _exampleControllers = List.generate(
      exampleWords.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    
    _exampleSlideAnimations = _exampleControllers.map((controller) =>
      Tween<double>(begin: 12.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _exampleOpacityAnimations = _exampleControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
    
    // 例句翻译字符动画 - 中文保持字符级动画
    _exampleTranslationControllers = List.generate(
      currentWord.exampleTranslation.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    
    _exampleTranslationSlideAnimations = _exampleTranslationControllers.map((controller) =>
      Tween<double>(begin: 10.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _exampleTranslationOpacityAnimations = _exampleTranslationControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
  }

  /// 单词动画完成回调
  void _onWordAnimationCompleted() {
    if (mounted) {
      setState(() {
        _wordAnimationCompleted = true;
      });
      
      // 启动按钮动画，增加健壮性检查
      PerformanceOptimizer.createTimer(
        poolKey: _timerPoolKey,
        duration: const Duration(milliseconds: 200),
        callback: () {
        if (mounted && _buttonsController.status != AnimationStatus.completed) {
          _buttonsController.forward();
        }
        },
      );
      
      // 检查并播放自动发音
      _checkAndPlayAutoPronunciation();
    }
  }
  
  /// 检查并播放自动发音
  void _checkAndPlayAutoPronunciation() async {
    final autoPlay = await SettingsHelper.getAutoPlayPronunciation();
    if (autoPlay && mounted) {
      // 延迟一点时间再播放，让动画完成
      // 使用独立的音频定时器池，确保播放不受其他操作影响
      PerformanceOptimizer.createTimer(
        poolKey: _audioTimerPoolKey,
        duration: const Duration(milliseconds: 500),
        callback: () {
          if (mounted) {
            _playWordPronunciation();
          }
        },
      );
    }
  }

  /// 为指定单词准备字符级动画
  void _prepareCharacterAnimations(ExtendedWordData word) {
    // 重置状态
    _wordAnimationCompleted = false;
    _completedWordAnimations = 0;
    
    // 清理旧的控制器
    _disposeCharacterControllers();
    
    // 单词字符动画
    _wordControllers = List.generate(
      word.word.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );
    
    // 为每个单词字符添加完成监听器
    for (int i = 0; i < _wordControllers.length; i++) {
      _wordControllers[i].addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _completedWordAnimations++;
          if (_completedWordAnimations >= _wordControllers.length) {
            _onWordAnimationCompleted();
          }
        }
      });
    }
    
    _wordSlideAnimations = _wordControllers.map((controller) =>
      Tween<double>(begin: 15.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _wordOpacityAnimations = _wordControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
    
    // 翻译字符动画
    _translationControllers = List.generate(
      word.translation.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    
    _translationSlideAnimations = _translationControllers.map((controller) =>
      Tween<double>(begin: 12.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _translationOpacityAnimations = _translationControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
    
    // 释义字符动画
    _meaningControllers = List.generate(
      word.translation.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    


    // 例句单词动画 - 改为单词级动画以优化性能
    final exampleWords = word.example.trim().split(RegExp(r'\s+'));
    _exampleControllers = List.generate(
      exampleWords.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    
    _exampleSlideAnimations = _exampleControllers.map((controller) =>
      Tween<double>(begin: 12.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _exampleOpacityAnimations = _exampleControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
    
    // 例句翻译字符动画
    _exampleTranslationControllers = List.generate(
      word.exampleTranslation.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    
    _exampleTranslationSlideAnimations = _exampleTranslationControllers.map((controller) =>
      Tween<double>(begin: 10.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _exampleTranslationOpacityAnimations = _exampleTranslationControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
  }

  /// 启动字符动画
  void _startCharacterAnimation(List<AnimationController> controllers, int delayMs) {
    for (int i = 0; i < controllers.length; i++) {
      final index = i; // 捕获循环变量
      PerformanceOptimizer.createTimer(
        poolKey: _timerPoolKey,
        duration: Duration(milliseconds: index * delayMs),
        callback: () {
          if (mounted && index < controllers.length) {
            controllers[index].forward();
          }
        },
      );
    }
  }

  /// 立即重置所有释义框相关的字符动画状态
  void _resetMeaningCharacterAnimations() {
    PerformanceOptimizer.cancelTimers(_timerPoolKey);
    
    for (var controller in _translationControllers) {
      controller.stop();
      controller.reset();
    }
    for (var controller in _meaningControllers) {
      controller.stop();
      controller.reset();
    }
    for (var controller in _exampleControllers) {
      controller.stop();
      controller.reset();
    }
    for (var controller in _exampleTranslationControllers) {
      controller.stop();
      controller.reset();
    }
  }

  /// 清理字符控制器
  void _disposeCharacterControllers() {
    PerformanceOptimizer.cancelTimers(_timerPoolKey);
    
    for (var controller in _wordControllers) {
      controller.dispose();
    }
    for (var controller in _translationControllers) {
      controller.dispose();
    }
    for (var controller in _meaningControllers) {
      controller.dispose();
    }
    for (var controller in _exampleControllers) {
      controller.dispose();
    }
    for (var controller in _exampleTranslationControllers) {
      controller.dispose();
    }
    
    _wordControllers.clear();
    _translationControllers.clear();
    _meaningControllers.clear();
    _exampleControllers.clear();
    _exampleTranslationControllers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkBackgroundColor 
          : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'WordFlow',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 22),
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.darkPrimaryTextColor 
                : AppTheme.primaryTextColor,
          ),
        ),
        leading: Padding(
              padding: EdgeInsets.only(left: ResponsiveHelper.getResponsiveSpacing(context, 10)),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
            ),
            child: IconButton(
              enableFeedback: false,
              icon: const Icon(Icons.library_books_outlined),
                  iconSize: ResponsiveHelper.getResponsiveIconSize(context, 26),
              onPressed: () async {
                SoundService.playTapSound();
                await Navigator.pushNamed(context, '/library');
                // 从词库页面返回时，检查是否需要重新加载词库数据
                await _checkAndReloadWordBook();
              },
              tooltip: '词库选择',
              color: Theme.of(context).primaryColor,
              padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: ResponsiveHelper.getResponsiveIconSize(context, 40),
                    minHeight: ResponsiveHelper.getResponsiveIconSize(context, 40),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
                padding: EdgeInsets.only(right: ResponsiveHelper.getResponsiveSpacing(context, 10)),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
              ),
              child: IconButton(
                enableFeedback: false,
                icon: const Icon(Icons.settings_outlined),
                    iconSize: ResponsiveHelper.getResponsiveIconSize(context, 26),
                onPressed: () {
                  SoundService.playTapSound();
                  Navigator.pushNamed(context, '/settings');
                },
                color: Theme.of(context).primaryColor,
                padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: ResponsiveHelper.getResponsiveIconSize(context, 40),
                      minHeight: ResponsiveHelper.getResponsiveIconSize(context, 40),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 主体内容
          Positioned.fill(
            child: SafeArea(child: _buildBody()),
          ),
          // 悬浮小球（造句测试模式下隐藏）
          if (!_isTestingMode)
            Positioned(
              left: 0, right: 0,
              bottom: ResponsiveHelper.getResponsiveSpacing(context, 60),
              child: _buildFluidDragBall(),
            ),
          // 底部提示
          if (!_isTestingMode || !_isSentenceSubmitted)
            Positioned(
              left: 0, right: 0,
              bottom: ResponsiveHelper.getResponsiveSpacing(context, 8),
              child: _buildAnimatedHintText(),
            ),
        ],
      ),
    );
      },
    );
  }

  /// 构建主体内容
  Widget _buildBody() {
    if (_isLoadingWords) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 12), // 从16减少到12
            Text(
              '词汇正在整理中...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkSecondaryTextColor 
                    : AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0), // 从20减少到16
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 52, // 从64减少到52
                color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
              ),
              SizedBox(height: 12), // 从16减少到12
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryTextColor 
                      : AppTheme.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20), // 从24减少到20
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/library');
                  // 从词库页面返回时，重新加载词库数据
                  await _loadWordsFromSelectedWordBook();
                },
                icon: Icon(Icons.library_books),
                label: Text('选择词库'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 从24,12减少到20,10
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentWord == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '新单词马上就来...',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
          ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // 只在非测试模式且单词动画完成时响应点击
        if (!_isTestingMode && _wordAnimationCompleted) {
          _toggleMeaning();
        }
      },
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 
                       kToolbarHeight - 
                       MediaQuery.of(context).padding.top - 
                       MediaQuery.of(context).padding.bottom - 
                       ResponsiveHelper.getResponsiveSpacing(context, 32),
          ),
          child: IntrinsicHeight(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveHelper.getMaxContentWidth(context),
                ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),
                    // 书籍信息区域在造句模式下淡出
                    AnimatedOpacity(
                      opacity: _isTestingMode ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      child: _buildWordBookInfoSection(),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                Flexible(child: _buildWordCard(_currentWord!)),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 20)),
                    // 底部浅灰字提示
                    AnimatedOpacity(
                      opacity: (!_isTestingMode && _wordAnimationCompleted) ? 0.6 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: Text(
                        _showMeaning ? '轻触卡片收起释义' : '轻触卡片展开释义',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 60)),
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建词库信息区域（分开显示书籍信息和学习进度）
  Widget _buildWordBookInfoSection() {
    if (_currentWordBookName == null) return SizedBox.shrink();
    
    return Column(
      children: [
        // 词库名称
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveHelper.getResponsiveSpacing(context, 12),
            vertical: ResponsiveHelper.getResponsiveSpacing(context, 5),
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 14)),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: Theme.of(context).brightness == Brightness.dark 
                ? null 
                : [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 0),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: Theme.of(context).primaryColor,
                size: ResponsiveHelper.getResponsiveIconSize(context, 14),
              ),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 6)),
              Flexible(
                child: Text(
                  _currentWordBookName!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryTextColor 
                        : AppTheme.primaryTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
        
        // 学习进度
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 今日已背单词
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getResponsiveSpacing(context, 8),
                vertical: ResponsiveHelper.getResponsiveSpacing(context, 4),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 10)),
                boxShadow: Theme.of(context).brightness == Brightness.dark 
                    ? null 
                    : [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.today_outlined,
                    color: Theme.of(context).primaryColor.withOpacity(0.7),
                    size: ResponsiveHelper.getResponsiveIconSize(context, 12),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                  Text(
                    '今日单词 $_todayStudiedCount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkSecondaryTextColor 
                          : AppTheme.secondaryTextColor,
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 11),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 6)),
            
            // 总背单词
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getResponsiveSpacing(context, 8),
                vertical: ResponsiveHelper.getResponsiveSpacing(context, 4),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 10)),
                boxShadow: Theme.of(context).brightness == Brightness.dark 
                    ? null 
                    : [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Theme.of(context).primaryColor.withOpacity(0.7),
                    size: ResponsiveHelper.getResponsiveIconSize(context, 12),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                  Text(
                    '总计单词 $_totalStudiedCount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkSecondaryTextColor 
                          : AppTheme.secondaryTextColor,
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }


  /// 构建优雅按钮
  Widget _buildFluidDragBall() {
    return AnimatedBuilder(
      animation: _buttonsController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonsSlideAnimation.value),
          child: Opacity(
            opacity: _buttonsOpacityAnimation.value,
            child: IgnorePointer(
              ignoring: !_wordAnimationCompleted || _buttonsController.status == AnimationStatus.dismissed,
                              child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 撤回按钮
                      if (_previousWord != null)
                        Container(
                          margin: EdgeInsets.only(bottom: 12),
                          child: _buildCompactButton(
                            onPressed: _undoLastAction,
                            icon: Icons.undo_rounded,
                            label: '回溯上个词',
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? AppTheme.darkAccentOrange.withOpacity(0.2)
                                : AppTheme.accentOrange.withOpacity(0.15),
                            textColor: Theme.of(context).brightness == Brightness.dark 
                                ? AppTheme.darkAccentOrange
                                : AppTheme.accentOrange.withOpacity(0.8),
                            iconColor: Theme.of(context).brightness == Brightness.dark 
                                ? AppTheme.darkAccentOrange.withOpacity(0.9)
                                : AppTheme.accentOrange,
                          ),
                        ),
                      
                      // 主要按钮行
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 不认识按钮
                          Expanded(
                            child: _buildElegantButton(
                              onPressed: () {SoundService.playForgotSound(); _markAsUnknown();},
                              icon: Icons.close_rounded,
                              label: '不认识',
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.darkAccentRed.withOpacity(0.2)
                                  : AppTheme.accentRed.withOpacity(0.15),
                              textColor: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.darkAccentRed
                                  : AppTheme.accentRed.withOpacity(0.8),
                              iconColor: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.darkAccentRed.withOpacity(0.9)
                                  : AppTheme.accentRed,
                            ),
                          ),
                          
                          SizedBox(width: 32),
                          
                          // 认识按钮
                          Expanded(
                            child: _buildElegantButton(
                              onPressed: () {SoundService.playRememberSound(); _markAsKnown();},
                              icon: Icons.check_rounded,
                              label: '认识',
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.darkAccentGreen.withOpacity(0.2)
                                  : AppTheme.accentGreen.withOpacity(0.15),
                              textColor: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.darkAccentGreen
                                  : AppTheme.accentGreen.withOpacity(0.8),
                              iconColor: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.darkAccentGreen.withOpacity(0.9)
                                  : AppTheme.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建优雅按钮
  Widget _buildElegantButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark 
            ? null 
            : [
                BoxShadow(
                  color: textColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
                SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建紧凑按钮（用于撤回）
  Widget _buildCompactButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark 
            ? null 
            : [
                BoxShadow(
                  color: textColor.withOpacity(0.08),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: iconColor,
                ),
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 开始单词动画
  void _startWordAnimation() {
    _fadeController.forward();
    _slideController.forward();
    
    // 启动单词字符动画
    PerformanceOptimizer.createTimer(
      poolKey: _timerPoolKey,
      duration: const Duration(milliseconds: 300),
      callback: () {
      _startCharacterAnimation(_wordControllers, 60);
      },
    );
  }

  /// 开始释义动画
  void _startMeaningAnimation() {
    if (_showMeaning) {
      _meaningController.forward();
      
      PerformanceOptimizer.createTimer(
        poolKey: _timerPoolKey,
        duration: const Duration(milliseconds: 100),
        callback: () {
        _startCharacterAnimation(_translationControllers, 40);
        },
      );
      
      PerformanceOptimizer.createTimer(
        poolKey: _timerPoolKey,
        duration: const Duration(milliseconds: 200),
        callback: () {
        _startCharacterAnimation(_meaningControllers, 30);
        },
      );
      
      PerformanceOptimizer.createTimer(
        poolKey: _timerPoolKey,
        duration: const Duration(milliseconds: 300),
        callback: () {
        _startCharacterAnimation(_exampleControllers, 120); // 增加延迟，因为现在是单词级动画
        },
      );
      
      PerformanceOptimizer.createTimer(
        poolKey: _timerPoolKey,
        duration: const Duration(milliseconds: 400),
        callback: () {
        _startCharacterAnimation(_exampleTranslationControllers, 40);
        },
      );
    } else {
      _resetMeaningCharacterAnimations();
      _meaningController.reverse();
    }
  }

  /// 切换释义显示
  void _toggleMeaning() {
    if (!_wordAnimationCompleted) return;
    
    setState(() {
      _showMeaning = !_showMeaning;
    });
    
    // 只在展开释义时重置动画，收起时不需要重置
    if (_showMeaning) {
      _resetMeaningCharacterAnimations();
    }
    
    _startMeaningAnimation();
    
    // 确保按钮动画在释义切换时保持可见状态
    if (_buttonsController.status != AnimationStatus.completed) {
      _buttonsController.forward();
    }
  }

  /// 标记为不认识
  void _markAsUnknown() async {
    if (!_wordAnimationCompleted) return;
    
    // 保存学习记录
    await _saveLearningRecord(ReviewResult.forgot);
    
    _nextWord();
  }

  /// 标记为认识
  void _markAsKnown() async {
    if (!_wordAnimationCompleted) return;
    
    // 根据学习模式决定是否进入造句测试
    final learningMode = await SettingsHelper.getLearningMode();
    
    if (learningMode == LearningMode.quickMemory) {
      // 快速记忆模式：保存为良好记录并直接进入下一个单词
      await _saveLearningRecord(ReviewResult.good);
      _nextWord();
    } else {
      // 深入学习模式：检查API Key是否有效
      final apiKey = await DeepSeekApiService.getApiKey();
      final isApiKeyValid = apiKey != null && apiKey.isNotEmpty && apiKey.length >= 10;
      
      if (!isApiKeyValid) {
        // API Key无效，自动切换到快速学习模式并显示提示
        await SettingsHelper.setLearningMode(LearningMode.quickMemory);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API Key无效，已自动切换到快速学习模式'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // 保存为良好记录并进入下一个单词
        await _saveLearningRecord(ReviewResult.good);
        _nextWord();
      } else {
        // API Key有效，开始造句测试（在造句完成后再保存记录）
        _startSentenceTest();
      }
    }
  }

  /// 撤回上一个单词
  void _undoLastAction() {
    if (_previousWord == null) return;
    
    if (!_wordAnimationCompleted) return;
    
    // 重置动画状态
    _fadeController.reset();
    _slideController.reset();
    _meaningController.reset();
    _buttonsController.reset();
    _wordMoveController.reset();
    _sentenceAnimationController.reset();
    _resultAreaController.reset();
    _skipButtonFadeController.reset();
    _sendButtonFadeController.reset();
    
    // 取消所有动画Timer
    PerformanceOptimizer.cancelTimers(_timerPoolKey);
    
    setState(() {
      // 恢复上一个单词
      _currentWord = _previousWord;
      _previousWord = null; // 清除历史记录，避免无限撤回
      
      // 重置状态
      _showMeaning = false;
      _wordAnimationCompleted = false;
      _completedWordAnimations = 0;
      _isTestingMode = false;
      _showSentenceInput = false;
      _isSentenceSubmitted = false;
      _judgmentResult = null;
      _userSentence = '';
      _showBetterSentenceAnimation = false;
      _showAdvancedResults = false;
    });
    
    // 清空输入框
    _sentenceInputController.clear();
    
    // 清理逐字母浮现动画控制器
    _disposeBetterSentenceControllers();
    
    // 重新准备字符级动画
    _prepareCharacterAnimations(_currentWord!);
    
    // 开始单词动画
    _startWordAnimation();
    
    // 显示撤回提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已回溯到上一个单词',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 保存学习记录
  Future<void> _saveLearningRecord(ReviewResult result) async {
    if (_currentWord == null || _currentWordBookName == null) return;

      // 获取当前单词的学习记录
      final records = await LearningDataService.instance.getWordBookRecords(_currentWordBookName!);
      final existingRecord = records.where((r) => r.word == _currentWord!.word).firstOrNull;
      
      final now = DateTime.now();
      WordLearningRecord newRecord;
      
      if (existingRecord != null) {
        // 更新现有记录
        newRecord = existingRecord.updateLearning(
          reviewResult: result,
          reviewTime: now,
          newWordBookName: _currentWordBookName,
        );
      } else {
        // 创建新记录
        newRecord = WordLearningRecord.firstTime(
          word: _currentWord!.word,
          translation: _currentWord!.translation,
          wordBookName: _currentWordBookName,
        );
        
        // 无论什么结果，都要调用updateLearning来记录到reviewHistory
        newRecord = newRecord.updateLearning(
          reviewResult: result,
          reviewTime: now,
        );
      }
      
      // 保存记录
      await LearningDataService.instance.saveWordLearningRecord(newRecord);
      
      // 更新学习统计
      await _updateLearningStats();

  }

  /// 开始造句测试
  void _startSentenceTest() {
    if (_currentWord == null) return;
    
    setState(() {
      _isTestingMode = true;
      _showSentenceInput = true; // 恢复显示原位置
      _showAdvancedResults = false;
    });
    
    // 确保动画重置，然后开始单词移动和缩放动画
    _wordMoveController.reset();
    _sentenceAnimationController.reset();
    
    PerformanceOptimizer.createTimer(
      poolKey: _timerPoolKey,
      duration: const Duration(milliseconds: 100),
      callback: () {
        if (mounted) {
          _wordMoveController.forward();
        }
      },
    );
    
    // 延迟显示输入框
    PerformanceOptimizer.createTimer(
      poolKey: _timerPoolKey,
      duration: const Duration(milliseconds: 400),
      callback: () {
        if (mounted) {
          _sentenceAnimationController.forward();
        }
      },
    );
  }
  
    /// 处理句子提交
    Future<void> _submitSentence() async {
      final sentence = _sentenceInputController.text.trim();
      
      // 检查句子长度
      if (sentence.isEmpty) {
        return;
      }
      
      if (sentence.length < 3) {
        return;
      }
      
      if (sentence.split(' ').length < 2) {
        return;
      }
      
      setState(() {
        _isJudging = true;
        _userSentence = sentence;
      });
      
      // 跳过按钮淡出
      _skipButtonFadeController.forward();
      
      try {
        final result = await DeepSeekApiService.judgeSentence(
          word: _currentWord!.word,
          sentence: sentence,
          translation: _currentWord!.translation,
        );
        
        setState(() {
          _judgmentResult = result;
          _isSentenceSubmitted = true;
          _showSentenceInput = false;
        });
        
        // 发送按钮淡出
        _sendButtonFadeController.forward();
        
        // 确保结果区域动画重置，然后启动
        _resultAreaController.reset();
        PerformanceOptimizer.createTimer(
          poolKey: _timerPoolKey,
          duration: const Duration(milliseconds: 100),
          callback: () {
            if (mounted) {
              _resultAreaController.forward();
              // 播放句子结果音效
              SoundService.playResultSound();
            }
          },
        );
        
        // 初始化逐词浮现动画
        _initializeBetterSentenceAnimation();
        
        // 如果没有正确句子需要显示，立即显示修改建议和下一个单词按钮
        if (_judgmentResult!.betterSentences.isEmpty) {
          PerformanceOptimizer.createTimer(
            poolKey: _timerPoolKey,
            duration: const Duration(milliseconds: 800),
            callback: () {
              if (mounted) {
                setState(() {
                  _showAdvancedResults = true;
                });
              }
            },
          );
        }
        
      } catch (e) {
        // 网络错误时静默处理
      } finally {
        setState(() {
          _isJudging = false;
        });
      }
    }
    

      /// 跳过造句测试
  void _skipSentenceTest() {
    _sentenceInputController.clear(); // 清空输入框
    _continueOrNext();
  }
    
      /// 初始化逐单词浮现动画
  void _initializeBetterSentenceAnimation() {
    if (_judgmentResult?.betterSentences.isEmpty ?? true) return;
    
    // 清理旧的动画控制器
    _disposeBetterSentenceControllers();
    
    // 获取第一个更好的句子
    final betterSentence = _judgmentResult!.betterSentences.first;
    _betterSentenceText = betterSentence;
    
    // 按单词分割并为每个单词创建动画控制器
    final words = _betterSentenceText.trim().split(RegExp(r'\s+'));
    _betterSentenceControllers = List.generate(
      words.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );
    
    // 创建动画
    _betterSentenceAnimations = _betterSentenceControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
    
    // 延迟显示动画
    PerformanceOptimizer.createTimer(
      poolKey: _timerPoolKey,
      duration: const Duration(milliseconds: 500),
      callback: () {
        if (mounted) {
          setState(() {
            _showBetterSentenceAnimation = true;
          });
          _startBetterSentenceAnimation();
        }
      },
    );
  }
  
  /// 开始逐单词浮现动画
  void _startBetterSentenceAnimation() {
    // 为最后一个单词添加完成监听器
    if (_betterSentenceControllers.isNotEmpty) {
      final lastController = _betterSentenceControllers.last;
      lastController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _showAdvancedResults = true;
          });
        }
      });
    }
    
    for (int i = 0; i < _betterSentenceControllers.length; i++) {
      PerformanceOptimizer.createTimer(
        poolKey: _timerPoolKey,
        duration: Duration(milliseconds: i * 150), // 每个单词延迟150ms
        callback: () {
          if (mounted && i < _betterSentenceControllers.length) {
            _betterSentenceControllers[i].forward();
          }
        },
      );
    }
  }
  
  /// 清理逐单词浮现动画控制器
  void _disposeBetterSentenceControllers() {
    for (var controller in _betterSentenceControllers) {
      controller.dispose();
    }
    _betterSentenceControllers.clear();
    _betterSentenceAnimations.clear();
  }
  
  /// 重新开始造句或下一个单词
  void _continueOrNext() async {
    
    // 根据造句测试结果保存学习记录
    if (_judgmentResult != null) {
      ReviewResult result;
      if (_judgmentResult!.isCorrect) {
        // 造句正确，根据分数判断
        if (_judgmentResult!.score >= 8) {
          result = ReviewResult.easy;
        } else {
          result = ReviewResult.good;
        }
      } else {
        // 造句错误
        result = ReviewResult.hard;
      }
      await _saveLearningRecord(result);
    } else {
      // 跳过了造句测试，保存为良好记录
      await _saveLearningRecord(ReviewResult.good);
    }
    
    setState(() {
      _isTestingMode = false;
      _showSentenceInput = false;
      _isSentenceSubmitted = false;
      _judgmentResult = null;
      _userSentence = '';
      _showBetterSentenceAnimation = false;
      _showAdvancedResults = false;
    });
    
    // 清空输入框
    _sentenceInputController.clear();
    _wordMoveController.reset();
    _sentenceAnimationController.reset();
    _resultAreaController.reset();
    _skipButtonFadeController.reset();
    _sendButtonFadeController.reset();
    _disposeBetterSentenceControllers();
    
    _nextWord();
  }
  
    /// 下一个单词（无限流模式）
  Future<void> _nextWord() async {
    
    // 重置动画状态
    _fadeController.reset();
    _slideController.reset();
    _meaningController.reset();
    _buttonsController.reset();
    _wordMoveController.reset();
    _sentenceAnimationController.reset();
    _resultAreaController.reset();
    _skipButtonFadeController.reset();
    _sendButtonFadeController.reset();
    
    // 取消所有动画Timer
    PerformanceOptimizer.cancelTimers(_timerPoolKey);
    
    setState(() {
      _showMeaning = false;
      _wordAnimationCompleted = false;
      _completedWordAnimations = 0;
      // 重置造句测试状态
      _isTestingMode = false;
      _showSentenceInput = false;
      _isSentenceSubmitted = false;
      _judgmentResult = null;
      _userSentence = '';
      _showBetterSentenceAnimation = false;
      _showAdvancedResults = false;
      // 保存当前单词到历史记录（用于撤回）
      _previousWord = _currentWord;
      // 立即清除当前单词，避免闪现
      _currentWord = null;
    });
    
    // 清空输入框
    _sentenceInputController.clear();
    
    // 清理逐字母浮现动画控制器
    _disposeBetterSentenceControllers();
    
    // 生成新单词
    await _generateNextWord();
    
    // 只有在获取到新单词后才更新UI
    if (_currentWord != null) {
      setState(() {
        // 新单词数据已准备好，触发重建
      });
    
    // 重新初始化字符动画
    _initializeCharacterAnimations();
    
    // 开始新单词动画
    _startWordAnimation();
    }
  }

  /// 构建单词卡片
  Widget _buildWordCard(ExtendedWordData word) {
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
            offset: Offset(0, 25 * (1 - _slideController.value)),
          child: FadeTransition(
            opacity: _fadeController,
            child: _isTestingMode 
                ? // 测试模式：只显示单词，无背景框
                Stack(
                  children: [
                    // 单词本体（测试模式下应用移动动画）
                    AnimatedBuilder(
                      animation: _wordMoveController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _wordMoveAnimation.value),
                          child: Transform.scale(
                            scale: _wordScaleAnimation.value,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 60),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 单词文本
                                  Flexible(
                                    child: _buildAnimatedText(
                                      word.word,
                                      _wordSlideAnimations,
                                      _wordOpacityAnimations,
                                      Theme.of(context).textTheme.headlineLarge!.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        fontSize: 34,
                                      ),
                                    ),
                                  ),
                                  
                                  // 发音按钮（造句模式下隐藏）
                                  SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // 输入框和结果显示区域 - 整体向上移动
                    Transform.translate(
                      offset: const Offset(0, -30), // 整体向上移动30px
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 预留单词原始位置的空间，考虑到单词会向上移动30px
                          const SizedBox(height: 30),
                          
                          // 单词与输入框的间距（增加到50px，让布局更舒适）
                          const SizedBox(height: 50),
                          
                          // 输入框和结果显示区域（位置一致）
                          _buildInputAndResultArea(),
                        ],
                      ),
                    ),
                  ],
                )
                : // 正常模式：显示完整的单词卡片
                Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkCardColor 
                          : AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuart,
                      width: double.infinity,
                        padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 单词本体和发音按钮
                          Container(
                            constraints: const BoxConstraints(minHeight: 60),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 单词文本
                                Flexible(
                                  child: _buildAnimatedText(
                                    word.word,
                                    _wordSlideAnimations,
                                    _wordOpacityAnimations,
                                    Theme.of(context).textTheme.headlineLarge!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      fontSize: 34,
                                    ),
                                  ),
                                ),
                                
                                // 发音按钮
                                FutureBuilder<Map<String, dynamic>>(
                                  future: _getPhoneticData(word),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return SizedBox.shrink();
                                    }
                                    
                                    final hasAudio = snapshot.data!['hasAudio'] as bool;
                                    
                                    if (!hasAudio) {
                                      return SizedBox.shrink();
                                    }
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: AnimatedOpacity(
                                        duration: const Duration(milliseconds: 600),
                                        curve: Curves.easeOutCubic,
                                        opacity: _fadeController.value,
                                        child: GestureDetector(
                                          onTap: _playWordPronunciation,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: Theme.of(context).brightness == Brightness.dark
                                                  ? null
                                                  : [
                                                BoxShadow(
                                                  color: Theme.of(context).primaryColor.withOpacity(0.15),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.volume_up_outlined,
                                              size: 20,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          // 音标和发音按钮（动态显示）
                          FutureBuilder<Map<String, dynamic>>(
                            future: _getPhoneticData(word),
                            builder: (context, snapshot) {
                              final hasPhonetic = snapshot.hasData && 
                                                 (snapshot.data!['phonetic'] as String).isNotEmpty;
                              
                              return               Column(
                children: [
                  SizedBox(height: hasPhonetic ? 2 : 8), // 有音标时间距为2，无音标时统一增加到8
                  _buildPhoneticSection(word),
                  if (hasPhonetic) const SizedBox(height: 8), // 音标和释义之间的间距统一为8
                ],
              );
                            },
                          ),
                            
                            // 释义部分
                            _buildAnimatedMeaningSection(word),
                            

                          ],
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  /// 构建音标和发音按钮部分
  Widget _buildPhoneticSection(ExtendedWordData word) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getPhoneticData(word),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // 加载中显示空容器
          return SizedBox.shrink();
        }
        
        final data = snapshot.data!;
        final phonetic = data['phonetic'] as String;

        // 如果没有音标，就不显示整个音标部分
        if (phonetic.isEmpty) {
          return SizedBox.shrink();
        }
        
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          opacity: _fadeController.value,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                phonetic,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // 最多显示两行
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// 获取当前发音设置对应的音标和音频可用性
  Future<Map<String, dynamic>> _getPhoneticData(ExtendedWordData word) async {
    final pronunciationType = await SettingsHelper.getPronunciationType();
    final phonetic = await word.getPhonetic(pronunciationType);
    final hasAudio = await word.hasAudio(pronunciationType);
    
    return {
      'phonetic': phonetic,
      'hasAudio': hasAudio,
    };
  }

  /// 构建动画释义部分
  Widget _buildAnimatedMeaningSection(ExtendedWordData word) {
    return AnimatedBuilder(
      animation: _meaningController,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _meaningHeightAnimation.value,
            child: Transform.scale(
              scale: _meaningScaleAnimation.value,
              child: Opacity(
                opacity: _meaningOpacityAnimation.value,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2), // 减少到2，因为间距已经在上面处理
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 中文释义（包含所有词性，用 | 分割）
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: 28,
                        ),
                        child: _buildAnimatedTextForMeaning(
                          word.translation,
                          _translationSlideAnimations,
                          _translationOpacityAnimations,
                          Theme.of(context).textTheme.titleLarge!.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8), // 统一间距为8，与音标-释义间距保持一致
                      
                      // 例句容器
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuart,
                          padding: const EdgeInsets.all(10), // 从12减少到10，更紧凑
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).cardColor.withOpacity(0.5)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              width: 4,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 例句
                            Container(
                              constraints: const BoxConstraints(minHeight: 30),
                              child: _buildWordLevelAnimatedText(
                                '"${word.example}"',
                                _exampleSlideAnimations,
                                _exampleOpacityAnimations,
                                Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3), // 保持原来的间距
                            // 例句翻译
                            Container(
                              constraints: const BoxConstraints(minHeight: 20),
                              child: _buildAnimatedTextForMeaning(
                                '"${word.exampleTranslation}"',
                                _exampleTranslationSlideAnimations,
                                _exampleTranslationOpacityAnimations,
                                Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.7)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建字符独立动画的文本（用于单词）
  Widget _buildAnimatedText(
    String text,
    List<Animation<double>> slideAnimations,
    List<Animation<double>> opacityAnimations,
    TextStyle style,
  ) {
    // 所有文本都使用字符级动画
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          children: List.generate(text.length, (index) {
            if (text[index] == ' ') {
              return SizedBox(
                width: style.fontSize! * 0.3,
                height: style.fontSize! * 1.2,
              );
            }
            
            if (index >= slideAnimations.length || index >= opacityAnimations.length) {
              return Text(
                text[index],
                style: style,
              );
            }
            
            return AnimatedBuilder(
              animation: Listenable.merge([slideAnimations[index], opacityAnimations[index]]),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, slideAnimations[index].value),
                  child: Opacity(
                    opacity: opacityAnimations[index].value,
                    child: Text(
                      text[index],
                      style: style,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  /// 测量文本宽度的辅助方法
  double _measureTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.size.width;
  }

  /// 构建单词级动画的文本（用于英文例句）
  Widget _buildWordLevelAnimatedText(
    String text,
    List<Animation<double>> slideAnimations,
    List<Animation<double>> opacityAnimations,
    TextStyle style,
  ) {
    if (slideAnimations.isEmpty || opacityAnimations.isEmpty) {
      return Center(
        child: Text(
          text,
          style: style,
          textAlign: TextAlign.center,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
      );
    }
    
    // 分割单词（去掉引号）
    final cleanText = text.replaceAll('"', '');
    final words = cleanText.trim().split(RegExp(r'\s+'));
    
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        child: _buildWordAnimatedWrap(words, slideAnimations, opacityAnimations, style),
      ),
    );
  }
  
  /// 构建单词动画的Wrap布局
  Widget _buildWordAnimatedWrap(
    List<String> words,
    List<Animation<double>> slideAnimations,
    List<Animation<double>> opacityAnimations,
    TextStyle style,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4.0, // 单词之间的水平间距
      runSpacing: 2.0, // 行之间的垂直间距
      children: [
        // 开始引号
        Text('"', style: style),
        ...List.generate(words.length, (index) {
          if (index >= slideAnimations.length || index >= opacityAnimations.length) {
            return Text(words[index], style: style);
          }
          
          return AnimatedBuilder(
            animation: Listenable.merge([slideAnimations[index], opacityAnimations[index]]),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, slideAnimations[index].value),
                child: Opacity(
                  opacity: opacityAnimations[index].value,
                  child: Text(
                    words[index],
                    style: style,
                  ),
                ),
              );
            },
          );
        }),
        // 结束引号
        Text('"', style: style),
      ],
    );
  }

  /// 构建字符独立动画的文本（用于释义和例句翻译）
  Widget _buildAnimatedTextForMeaning(
    String text,
    List<Animation<double>> slideAnimations,
    List<Animation<double>> opacityAnimations,
    TextStyle style,
  ) {
    if (slideAnimations.isEmpty || opacityAnimations.isEmpty) {
      return Center(
        child: Text(
          text,
          style: style,
          textAlign: TextAlign.center,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
      );
    }
    
    // 按单词分行，保持字符的全局索引
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80, // 保持原来的宽度设置
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, // 改回居中对齐
          children: _buildWordBasedAnimatedLines(text, slideAnimations, opacityAnimations, style),
        ),
      ),
    );
  }
  
  /// 按单词构建动画文本行
  List<Widget> _buildWordBasedAnimatedLines(
    String text,
    List<Animation<double>> slideAnimations,
    List<Animation<double>> opacityAnimations,
    TextStyle style,
  ) {
    final lines = <String>[];
    
    // 计算可用宽度（考虑边距和内边距）
    final screenWidth = MediaQuery.of(context).size.width;
    // 根据屏幕尺寸动态调整最大宽度，确保在各种设备上都有良好的显示效果
    final maxWidth = screenWidth > 600 
        ? screenWidth * 0.7  // 大屏设备：70%宽度
        : screenWidth * 0.8; // 小屏设备：80%宽度
    
    // 检查是否主要是中文内容
    final chineseCharCount = text.runes.where((rune) => rune >= 0x4e00 && rune <= 0x9fff).length;
    final isMostlyChinese = chineseCharCount > text.length * 0.5;
    
    if (isMostlyChinese) {
      // 中文文本：按字符逐个添加，遇到宽度超限时换行
      String currentLine = '';
      final characters = text.split('');
      
      for (final char in characters) {
        final testLine = currentLine + char;
        final textWidth = _measureTextWidth(testLine, style);
        
        if (textWidth <= maxWidth) {
          currentLine = testLine;
        } else {
          if (currentLine.isNotEmpty) {
            lines.add(currentLine);
            currentLine = char;
          } else {
            // 如果单个字符都太宽，直接添加
            lines.add(char);
          }
        }
      }
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
      }
    } else {
      // 英文文本：按单词分割
      final words = text.split(' ');
      String currentLine = '';
      
      for (final word in words) {
        final testLine = currentLine.isEmpty ? word : '$currentLine $word';
        final textWidth = _measureTextWidth(testLine, style);
        
        if (textWidth <= maxWidth) {
          currentLine = testLine;
        } else {
          if (currentLine.isNotEmpty) {
            lines.add(currentLine);
            currentLine = word;
          } else {
            // 如果单个单词太长，也直接添加为一行
            lines.add(word);
          }
        }
      }
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
      }
    }
    
    // 为每一行构建动画，维护全局字符索引
    final result = <Widget>[];
    int globalCharIndex = 0;
    
    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      
      // 构建这一行的动画文本
      final lineWidget = Padding(
        padding: EdgeInsets.only(
          bottom: lineIndex < lines.length - 1 ? 4.0 : 0.0,
        ),
        child: _buildAnimatedTextLine(
          line, 
          slideAnimations, 
          opacityAnimations, 
          style,
          globalCharIndex,
        ),
      );
      
      result.add(lineWidget);
      
      // 更新全局字符索引
      globalCharIndex += line.length;
      
      // 对于英文文本，需要考虑单词间的空格
      if (!isMostlyChinese && lineIndex < lines.length - 1) {
        // 检查原文本中是否有空格需要考虑
        final totalCharsInPreviousLines = lines.take(lineIndex + 1).map((l) => l.length).fold(0, (a, b) => a + b);
        final spacesCount = lineIndex; // 前面行数等于空格数
        if (totalCharsInPreviousLines + spacesCount < text.length) {
          globalCharIndex += 1; // 行间的空格
        }
      }
    }
    
    return result;
  }
  
  /// 构建单行动画文本，使用全局字符索引
  Widget _buildAnimatedTextLine(
    String line,
    List<Animation<double>> slideAnimations,
    List<Animation<double>> opacityAnimations,
    TextStyle style,
    int globalStartIndex,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(line.length, (localIndex) {
        final char = line[localIndex];
        final globalIndex = globalStartIndex + localIndex;
        
        // 处理空格
        if (char == ' ') {
          return SizedBox(
            width: style.fontSize! * 0.3,
            height: style.fontSize! * 1.2,
          );
        }
        
        // 确保所有字符都有动画，包括标点符号
        // 如果超出动画范围，使用最后一个动画或创建静态文本
        if (globalIndex >= slideAnimations.length || globalIndex >= opacityAnimations.length) {
          // 使用最后一个动画的值，或者直接显示
          final lastSlideIndex = slideAnimations.length - 1;
          final lastOpacityIndex = opacityAnimations.length - 1;
          
          if (lastSlideIndex >= 0 && lastOpacityIndex >= 0) {
            return AnimatedBuilder(
              animation: Listenable.merge([
                slideAnimations[lastSlideIndex], 
                opacityAnimations[lastOpacityIndex]
              ]),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, slideAnimations[lastSlideIndex].value),
                  child: Opacity(
                    opacity: opacityAnimations[lastOpacityIndex].value,
                    child: Text(
                      char,
                      style: style,
                    ),
                  ),
                );
              },
            );
          } else {
            return Text(
              char,
              style: style,
            );
          }
        }
        
        // 正常的字符动画
        return AnimatedBuilder(
          animation: Listenable.merge([
            slideAnimations[globalIndex], 
            opacityAnimations[globalIndex]
          ]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, slideAnimations[globalIndex].value),
              child: Opacity(
                opacity: opacityAnimations[globalIndex].value,
                child: Text(
                  char,
                  style: style,
                ),
              ),
            );
          },
        );
      }),
    );
  }

  /// 构建动画提示文字
  Widget _buildAnimatedHintText() {
    return AnimatedBuilder(
      animation: _buttonsController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonsSlideAnimation.value),
          child: Opacity(
            opacity: _buttonsOpacityAnimation.value,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: Text(
                _isTestingMode 
                    ? (_showSentenceInput 
                        ? ''
                        : '正在准备造句测试...')
                    : (_wordAnimationCompleted 
                        ? ''
                        : '单词即将登场...'),
                key: ValueKey('${_wordAnimationCompleted}_${_isTestingMode}_breath'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.6)
                      : Colors.grey.shade400,
                  height: 1.4,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建输入框和结果显示区域（位置一致）
  Widget _buildInputAndResultArea() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      child: _isSentenceSubmitted && _judgmentResult != null
          ? _buildSentenceResult()
          : _showSentenceInput
              ? _buildSentenceInput()
              : const SizedBox(),
    );
  }
  
    /// 显示编辑浮层
  void _showInputOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext dialogContext) {
        double? previousKeyboardHeight;
        bool isClosing = false; // 防止重复关闭
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            
            // 键盘高度监听逻辑
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!isClosing && 
                  previousKeyboardHeight != null && 
                  previousKeyboardHeight! > 0 && 
                  currentKeyboardHeight == 0) {
                // 键盘从显示状态变为隐藏状态
                isClosing = true;
                Navigator.of(dialogContext).pop();
                setState(() {});
              }
              previousKeyboardHeight = currentKeyboardHeight;
            });
            
            return WillPopScope(
              onWillPop: () async {
                setState(() {});
                return true;
              },
              child: Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset: true,
                body: GestureDetector(
                  onTap: () {
                    if (!isClosing) {
                      _inputFocusNode.unfocus();
                    }
                  },
                  child: Column(
                    children: [
                      Expanded(child: Container()), // 占位
                      Container(
                        color: isDark ? AppTheme.darkCardColor : AppTheme.coolGray100,
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 12,
                          bottom: MediaQuery.of(context).padding.bottom + 12,
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? AppTheme.darkCardColor 
                                        : AppTheme.coolGray50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? AppTheme.coolGray600 
                                          : AppTheme.coolGray200,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _sentenceInputController,
                                    focusNode: _inputFocusNode,
                                    maxLines: 4,
                                    minLines: 1,
                                    maxLength: null,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: '输入句子...',
                                      hintStyle: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? AppTheme.coolGray500 
                                            : AppTheme.coolGray400,
                                      ),
                                      border: InputBorder.none,
                                      counterText: '',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? AppTheme.darkPrimaryTextColor 
                                          : AppTheme.coolGray700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  if (!isClosing) {
                                    isClosing = true;
                                    Navigator.of(dialogContext).pop();
                                    setState(() {});
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGreen,
                                  foregroundColor: Colors.white,
                                  shape: CircleBorder(),
                                  padding: EdgeInsets.all(12),
                                  minimumSize: Size(44, 44),
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  

  


  /// 构建句子输入框（原方法，现在仅用于兼容性）
  Widget _buildSentenceInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _sentenceInputAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _sentenceInputAnimation.value)),
          child: Opacity(
            opacity: _sentenceInputAnimation.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 输入提示区域
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardColor : AppTheme.coolGray100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.darkCardColor : AppTheme.coolGray100),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '请用 ${_currentWord?.word} 写一个句子：',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? AppTheme.darkSecondaryTextColor 
                              : AppTheme.coolGray600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 输入框（点击时弹出编辑浮层）
                      GestureDetector(
                        onTap: _showInputOverlay,
                        child: Container(
                          width: double.infinity,
                          height: 50, // 固定高度，与弹出框单行高度一致
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 与弹出框完全一致的padding
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkCardColor
                                : AppTheme.coolGray50,
                            borderRadius: BorderRadius.circular(12), // 与弹出框完全一致的圆角
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.coolGray600
                                  : AppTheme.coolGray200,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _sentenceInputController.text.isEmpty 
                                ? '输入句子...'
                                : _sentenceInputController.text,
                              style: TextStyle(
                                fontSize: 16,
                                color: _sentenceInputController.text.isEmpty 
                                  ? (Theme.of(context).brightness == Brightness.dark 
                                      ? AppTheme.coolGray500 
                                      : AppTheme.coolGray400)
                                  : (Theme.of(context).brightness == Brightness.dark 
                                      ? AppTheme.darkPrimaryTextColor 
                                      : AppTheme.coolGray700),
                              ),
                              maxLines: 1, // 原界面只显示单行
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 按钮区域
                Column(
                  children: [
                    // 发送按钮
                    AnimatedBuilder(
                      animation: _sendButtonFadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _isSentenceSubmitted ? _sendButtonFadeAnimation.value : 1.0,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isJudging ? null : () {SoundService.playTapSound(); _submitSentence();},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: AppTheme.coolGray300,
                              ),
                              child: _isJudging
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('正在判断...'),
                                      ],
                                    )
                                  : Text(
                                      '提交',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 跳过按钮（更小更轻量）
                    AnimatedBuilder(
                      animation: _skipButtonFadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _isJudging ? _skipButtonFadeAnimation.value : 1.0,
                          child: TextButton(
                            onPressed: _isJudging ? null : () {SoundService.playTapSound(); _skipSentenceTest();},
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              '跳过',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? AppTheme.darkSecondaryTextColor 
                                    : AppTheme.coolGray500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建句子结果
  Widget _buildSentenceResult() {
    if (_judgmentResult == null || _userSentence.isEmpty) return const SizedBox();
    
    return AnimatedBuilder(
      animation: _resultAreaAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _resultAreaAnimation.value)),
          child: Opacity(
            opacity: _resultAreaAnimation.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用户的句子（带高亮）- 第一个浮现
                _buildAnimatedResultItem(0, _buildHighlightedSentence()),
                
                // 正确的句子示例 - 第二个浮现
                if (_judgmentResult!.betterSentences.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildAnimatedResultItem(1, _buildCorrectSentence()),
                ],
                
                // 修改说明 - 第三个浮现（需要等正确句子全部显示完毕）
                if (_showAdvancedResults) ...[
                  const SizedBox(height: 16),
                  _buildAnimatedResultItem(2, _buildErrorExplanation()),
                ],
                
                // 继续按钮 - 第四个浮现（需要等正确句子全部显示完毕）
                if (_showAdvancedResults) ...[
                  const SizedBox(height: 20),
                  _buildAnimatedResultItem(3, _buildNextWordButton()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// 构建带动画的结果项目
  Widget _buildAnimatedResultItem(int index, Widget child) {
    return AnimatedBuilder(
      animation: _resultAreaAnimation,
      builder: (context, _) {
        // 增强动画逻辑，使用更明显的延迟和更丰富的动画效果
        final progress = _resultAreaAnimation.value;
        final delay = index * 0.3; // 每个项目延迟0.3秒，增加延迟时间
        
        // 计算该项目的动画进度
        final adjustedProgress = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        
        // 使用更丰富的动画效果
        final easedProgress = Curves.easeOutQuart.transform(adjustedProgress);
        
        return Transform.translate(
          offset: Offset(0, 50 * (1 - easedProgress)), // 增加移动距离
          child: Transform.scale(
            scale: 0.8 + (0.2 * easedProgress), // 添加缩放效果
            child: Opacity(
              opacity: easedProgress,
              child: child,
            ),
          ),
        );
      },
    );
  }
  
  /// 构建下一个单词按钮
  Widget _buildNextWordButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {SoundService.playTapSound();_continueOrNext();},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '下一个单词',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 构建高亮的句子
  Widget _buildHighlightedSentence() {
    final words = _userSentence.split(' ');
    final result = _judgmentResult!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray200),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Text.rich(
        TextSpan(
          children: words.map((word) {
            // 智能错误检测逻辑
            Color textColor = isDark 
                ? AppTheme.darkPrimaryTextColor 
                : AppTheme.coolGray700;
            bool isErrorWord = false;
            
            // 只有当句子有错误时，才检查并标记错误单词
            if (!result.isCorrect) {
              isErrorWord = _isWordError(word, result);
              
              if (isErrorWord) {
                textColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
              }
            }
            
            return TextSpan(
              text: '$word ',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: textColor,
                fontWeight: isErrorWord ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  /// 智能判断单词是否为错误
  bool _isWordError(String word, SentenceJudgmentResult result) {
    // 如果没有正确的句子作为参考，使用错误描述来判断
    if (result.betterSentences.isEmpty) {
      return _checkWordInErrorDescription(word, result);
    }
    
    // 使用正确句子进行比较
    return _isWordDifferentFromCorrect(word, result.betterSentences.first);
  }
  
  /// 检查单词是否在错误描述中被提及
  bool _checkWordInErrorDescription(String word, SentenceJudgmentResult result) {
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    
    for (final error in result.errors) {
      final errorText = error.description.toLowerCase();
      final errorPosition = error.position.toLowerCase();
      
      // 直接匹配错误位置
      if (errorPosition.contains(cleanWord) || cleanWord.contains(errorPosition)) {
        return true;
      }
      
      // 检查错误描述中是否提到了这个单词
      if (errorText.contains(cleanWord)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// 比较单词与正确句子的差异
  bool _isWordDifferentFromCorrect(String userWord, String correctSentence) {
    final userWords = _userSentence.split(' ');
    final correctWords = correctSentence.split(' ');
    
    // 找到当前单词在用户句子中的位置
    final wordIndex = userWords.indexOf(userWord);
    if (wordIndex == -1) return false;
    
    // 处理句子长度不同的情况
    if (wordIndex >= correctWords.length) {
      return true; // 用户句子更长，这个单词可能是多余的
    }
    
    final userWordClean = userWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    final correctWordClean = correctWords[wordIndex].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    
    // 检查拼写差异
    if (userWordClean != correctWordClean) {
      return true;
    }
    
    // 检查大小写差异
    if (userWord != correctWords[wordIndex]) {
      return true;
    }
    
    // 检查语法结构错误（通过检查前后文）
    return _isWordInWrongGrammarContext(userWord, wordIndex, userWords, correctWords);
  }
  
  /// 检查单词是否在错误的语法环境中
  bool _isWordInWrongGrammarContext(String userWord, int wordIndex, List<String> userWords, List<String> correctWords) {
    // 检查常见的语法错误模式
    
    // 检查 "i am very like" 这种错误模式
    if (wordIndex >= 1 && wordIndex < userWords.length - 1) {
      final prevWord = userWords[wordIndex - 1].toLowerCase();
      final nextWord = userWords[wordIndex + 1].toLowerCase();
      final currentWord = userWord.toLowerCase();
      
      // "am very like" 是错误的语法结构
      if (prevWord == 'am' && currentWord == 'very' && nextWord == 'like') {
        return true;
      }
      
      // "i am very" 开头的结构通常是错误的
      if (wordIndex >= 2) {
        final prevPrevWord = userWords[wordIndex - 2].toLowerCase();
        if (prevPrevWord == 'i' && prevWord == 'am' && currentWord == 'very') {
          return true;
        }
      }
    }
    
    // 检查 "am" 在错误位置
    if (userWord.toLowerCase() == 'am' && wordIndex > 0) {
      final prevWord = userWords[wordIndex - 1].toLowerCase();
      if (prevWord == 'i' && wordIndex < userWords.length - 1) {
        final nextWord = userWords[wordIndex + 1].toLowerCase();
        if (nextWord == 'very') {
          return true;
        }
      }
    }
    
    return false;
  }



  /// 构建正确句子
  Widget _buildCorrectSentence() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray200),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppTheme.accentGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '参考句子',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark 
                      ? AppTheme.darkPrimaryTextColor 
                      : AppTheme.coolGray700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 逐字母浮现的正确句子
          if (_showBetterSentenceAnimation && _betterSentenceText.isNotEmpty) ...[
            _buildAnimatedBetterSentence(),
          ],
        ],
      ),
    );
  }
  
  /// 构建错误说明
  Widget _buildErrorExplanation() {
    final hasErrors = _judgmentResult!.errors.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray200),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasErrors ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                color: hasErrors 
                    ? AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600)
                    : AppTheme.accentGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                hasErrors ? '修改说明' : '句子评价',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasErrors) ...[
            ..._judgmentResult!.errors.map((error) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• ${error.description}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
                  height: 1.4,
                ),
              ),
            )),
          ] else ...[
            Text(
              '• 您的句子语法正确，用词恰当',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• 参考句子提供了更地道的表达方式',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// 构建逐单词浮现的正确句子
  Widget _buildAnimatedBetterSentence() {
    final words = _betterSentenceText.trim().split(RegExp(r'\s+'));

    return Container(
      width: double.infinity, // 使用Container而不是SizedBox，让高度自适应
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray200),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6.0, // 单词之间的水平间距
        runSpacing: 4.0, // 行之间的垂直间距
        children: List.generate(words.length, (index) {
          final word = words[index];
          final modificationInfo = _getWordModificationInfo(word, index);
          
          if (index >= _betterSentenceAnimations.length) {
            return Text(
              word,
              style: TextStyle(
                fontSize: 15,
                color: _getWordHighlightColor(modificationInfo),
                fontWeight: modificationInfo.isModified ? FontWeight.w600 : FontWeight.w500,
                height: 1.5,
              ),
            );
          }
          
          return AnimatedBuilder(
            animation: _betterSentenceAnimations[index],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 8 * (1 - _betterSentenceAnimations[index].value)),
                                  child: Opacity(
                    opacity: _betterSentenceAnimations[index].value,
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: 15,
                        color: _getWordHighlightColor(modificationInfo),
                        fontWeight: modificationInfo.isModified ? FontWeight.w600 : FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
  

  /// 单词修改信息
  WordModificationInfo _getWordModificationInfo(String correctWord, int index) {
    final userWords = _userSentence.split(' ');
    final correctWords = _judgmentResult!.betterSentences.first.split(' ');
    
    // 新增的单词（正确句子更长）
    if (index >= userWords.length) {
      return WordModificationInfo(isModified: true, modificationType: ModificationType.grammar);
    }
    
    final userWord = userWords[index];
    final userWordClean = userWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    final correctWordClean = correctWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    
    // 拼写不同
    if (userWordClean != correctWordClean) {
      return WordModificationInfo(isModified: true, modificationType: ModificationType.grammar);
    }
    
    // 大小写不同
    if (userWord != correctWord) {
      return WordModificationInfo(isModified: true, modificationType: ModificationType.grammar);
    }
    
    // 检查是否是简单性改进
    if (_isWordInSimplicityImprovement(correctWord, index)) {
      return WordModificationInfo(isModified: true, modificationType: ModificationType.simplicity);
    }
    
    // 检查是否是地道性修改
    if (_isWordInIdiomaticImprovement(correctWord, index)) {
      return WordModificationInfo(isModified: true, modificationType: ModificationType.idiomatic);
    }
    
    // 检查是否在语法修正的范围内
    if (_isWordInCorrectedGrammarRange(correctWord, index, userWords, correctWords)) {
      return WordModificationInfo(isModified: true, modificationType: ModificationType.grammar);
    }
    
    return WordModificationInfo(isModified: false, modificationType: ModificationType.none);
  }
  
  /// 检查是否是简单性改进（基于错误类型判断）
  bool _isWordInSimplicityImprovement(String correctWord, int index) {
    // 检查是否有简单性相关的错误
    final hasSimplicityErrors = _judgmentResult!.errors.any((error) => 
      error.type.toLowerCase().contains('简单') || 
      error.type.toLowerCase().contains('简陋') ||
      error.type.toLowerCase().contains('basic') ||
      error.type.toLowerCase().contains('simple') ||
      error.description.contains('过于简单') ||
      error.description.contains('太简单') ||
      error.description.contains('可以更丰富') ||
      error.description.contains('表达更丰富') ||
      error.description.contains('更复杂') ||
      error.description.contains('更详细') ||
      error.description.contains('更具体')
    );
    
    if (!hasSimplicityErrors) return false;
    
    // 如果有简单性错误，且参考句子比用户句子更长或用词更丰富
    final userWords = _userSentence.split(' ');
    final correctWords = _judgmentResult!.betterSentences.first.split(' ');
    
    // 如果参考句子更长，说明是扩展内容
    if (correctWords.length > userWords.length) {
      return index >= userWords.length; // 新增的单词都标记为简单性改进
    }
    
    // 如果长度相同，检查是否有词汇替换（更丰富的表达）
    if (userWords.length == correctWords.length && index < userWords.length) {
      final userWord = userWords[index].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      final correctWordClean = correctWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      return userWord != correctWordClean;
    }
    
    return false;
  }
  
  /// 检查是否是地道性改进（基于错误类型判断）
  bool _isWordInIdiomaticImprovement(String correctWord, int index) {
    // 检查是否有地道性相关的错误
    final hasIdiomaticErrors = _judgmentResult!.errors.any((error) => 
      error.type.toLowerCase().contains('地道') || 
      error.type.toLowerCase().contains('idiomatic') ||
      error.description.contains('地道') ||
      error.description.contains('更自然') ||
      error.description.contains('更常用')
    );
    
    if (!hasIdiomaticErrors) return false;
    
    // 如果有地道性错误，且当前单词在建议的句子中，则可能是地道性改进
    final userWords = _userSentence.split(' ');
    final correctWords = _judgmentResult!.betterSentences.first.split(' ');
    
    // 简单的启发式规则：如果句子结构相同但用词不同，可能是地道性改进
    if (userWords.length == correctWords.length && index < userWords.length) {
      final userWord = userWords[index].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      final correctWordClean = correctWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      return userWord != correctWordClean;
    }
    
    return false;
  }
  
  /// 获取单词高亮颜色
  Color _getWordHighlightColor(WordModificationInfo info) {
    if (!info.isModified) {
      return AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700);
    }
    
    switch (info.modificationType) {
      case ModificationType.grammar:
        return AppTheme.accentGreen; // 绿色表示语法修改
      case ModificationType.idiomatic:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return isDark ? Colors.orange.shade300 : Colors.orange.shade600; // 橙色表示地道性改进
      case ModificationType.simplicity:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return isDark ? Colors.amber.shade300 : Colors.amber.shade600; // 黄色表示简单性改进
      case ModificationType.none:
        return AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray700);
    }
  }


  /// 检查单词是否在语法修正的范围内
  bool _isWordInCorrectedGrammarRange(String correctWord, int index, List<String> userWords, List<String> correctWords) {
    // 检查是否在"i am very like him" -> "I like him very much"的修正范围内
    
    // 在用户句子中找到"i am very like"的位置
    for (int i = 0; i < userWords.length - 3; i++) {
      if (userWords[i].toLowerCase() == 'i' && 
          userWords[i + 1].toLowerCase() == 'am' && 
          userWords[i + 2].toLowerCase() == 'very' && 
          userWords[i + 3].toLowerCase() == 'like') {
        
        // 如果当前单词在这个范围内或者是修正后的结果，则标记为修改过的
        if (index >= i && index <= i + 5) { // 扩展范围包括"him very much"
          final currentWordLower = correctWord.toLowerCase();
          if (currentWordLower == 'i' || currentWordLower == 'like' || 
              currentWordLower == 'him' || currentWordLower == 'very' || 
              currentWordLower == 'much') {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  @override
  void dispose() {
    // 清理FocusNode
    _inputFocusNode.dispose();
    
    // 使用性能优化器清理资源
    PerformanceOptimizer.cancelTimers(_timerPoolKey);
    PerformanceOptimizer.cancelTimers(_audioTimerPoolKey);
    PerformanceOptimizer.disposeAnimationControllers(_animationPoolKey);
    
    _disposeCharacterControllers();
    _disposeBetterSentenceControllers();
    _sentenceInputController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

/// 扩展的单词数据模型（包含音标、详细释义、例句等）
class ExtendedWordData {
  final String word;
  final String pronunciation;
  final String translation;
  final String example;
  final String exampleTranslation;
  final String? ukPhone;
  final String? usPhone;
  final String? ukSpeech;
  final String? usSpeech;

  ExtendedWordData({
    required this.word,
    required this.pronunciation,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
    this.ukPhone,
    this.usPhone,
    this.ukSpeech,
    this.usSpeech,
  });

  /// 从基础WordData创建扩展数据（使用API数据）
  static Future<ExtendedWordData> fromWordData(WordData wordData, PronunciationType pronunciationType) async {
    // 尝试从API获取详细信息
    final apiResponse = await EnglishWordApiService.getWordDetails(wordData.word);
    
    if (apiResponse != null) {
      // 获取并拼接所有词性的释义
      String mainTranslation = wordData.translation; // 默认使用原始翻译
      if (apiResponse.translations.isNotEmpty) {
        final translationParts = <String>[];
        
        for (final translation in apiResponse.translations) {
          final pos = translation.pos.trim();
          final tranCn = translation.tranCn.trim();
          
          if (pos.isNotEmpty && tranCn.isNotEmpty) {
            translationParts.add("$pos. $tranCn");
          }
        }
        
        if (translationParts.isNotEmpty) {
          mainTranslation = translationParts.join(" | ");
        }
      }
      
      // 获取例句 - 增加数据验证
      String example = "";
      String exampleTranslation = "";
      
      if (apiResponse.sentences.isNotEmpty) {
        final firstSentence = apiResponse.sentences.first;
        final sContent = firstSentence.sContent.trim();
        final sCn = firstSentence.sCn.trim();
        
        if (sContent.isNotEmpty && sCn.isNotEmpty) {
          example = sContent;
          exampleTranslation = sCn;
        }
      }
      
      // 如果没有获取到例句，使用AI生成
      if (example.isEmpty || exampleTranslation.isEmpty) {
        final aiExample = await _generateAIExample(wordData.word, mainTranslation);
        example = aiExample.example;
        exampleTranslation = aiExample.exampleTranslation;
      }
      
              return ExtendedWordData(
          word: wordData.word,
          pronunciation: "", // 不再使用这个字段
          translation: mainTranslation,
          example: example,
          exampleTranslation: exampleTranslation,
          ukPhone: apiResponse.ukPhone.isNotEmpty ? apiResponse.ukPhone : null,
          usPhone: apiResponse.usPhone.isNotEmpty ? apiResponse.usPhone : null,
          ukSpeech: apiResponse.ukSpeech.isNotEmpty ? apiResponse.ukSpeech : null,
          usSpeech: apiResponse.usSpeech.isNotEmpty ? apiResponse.usSpeech : null,
        );
    } else {
      // API调用失败，使用基础数据，不提供音标
      // 使用AI生成例句
      final aiExample = await _generateAIExample(wordData.word, wordData.translation);
      
      return ExtendedWordData(
        word: wordData.word,
        pronunciation: "", // 不再使用这个字段
        translation: wordData.translation,
        example: aiExample.example,
        exampleTranslation: aiExample.exampleTranslation,
        ukPhone: null, // API失败时不提供音标
        usPhone: null, // API失败时不提供音标
        ukSpeech: null, // API失败时不提供音频
        usSpeech: null, // API失败时不提供音频
      );
    }
  }



  /// 使用AI生成例句
  static Future<ExampleSentenceResult> _generateAIExample(String word, String translation) async {
    final result = await DeepSeekApiService.generateExampleSentence(
      word: word,
      translation: translation,
    );
    
    if (result != null) {
      return result;
    }
    
    // 如果AI生成失败，返回默认例句
    return ExampleSentenceResult(
      example: "This is an example sentence with the word '$word'.",
      exampleTranslation: "这是一个包含单词'$word'的例句。",
    );
  }
  
  /// 获取当前发音类型的音频URL
  String? getAudioUrl(PronunciationType pronunciationType) {
    switch (pronunciationType) {
      case PronunciationType.uk:
        return ukSpeech;
      case PronunciationType.us:
        return usSpeech;
    }
  }
  
  /// 根据发音类型获取对应的音标（支持回退机制）
  Future<String> getPhonetic(PronunciationType pronunciationType) async {
    switch (pronunciationType) {
      case PronunciationType.uk:
        // 优先返回英音
        if (ukPhone?.isNotEmpty == true) {
          return "/${ukPhone!}/";
        }
        // 回退到美音
        if (usPhone?.isNotEmpty == true) {
          return "/${usPhone!}/";
        }
        // 两个都没有，返回空字符串
        return "";
      case PronunciationType.us:
        // 优先返回美音
        if (usPhone?.isNotEmpty == true) {
          return "/${usPhone!}/";
        }
        // 回退到英音
        if (ukPhone?.isNotEmpty == true) {
          return "/${ukPhone!}/";
        }
        // 两个都没有，返回空字符串
        return "";
    }
  }
  
  /// 检查是否有可用的音频（支持回退机制）
  Future<bool> hasAudio(PronunciationType pronunciationType) async {
    switch (pronunciationType) {
      case PronunciationType.uk:
        // 优先检查英音
        if (ukSpeech?.isNotEmpty == true) {
          return true;
        }
        // 回退到美音
        if (usSpeech?.isNotEmpty == true) {
          return true;
        }
        return false;
      case PronunciationType.us:
        // 优先检查美音
        if (usSpeech?.isNotEmpty == true) {
          return true;
        }
        // 回退到英音
        if (ukSpeech?.isNotEmpty == true) {
          return true;
        }
        return false;
    }
  }
  
  /// 获取有效的音频URL（支持回退机制）
  String? getValidAudioUrl(PronunciationType pronunciationType) {
    switch (pronunciationType) {
      case PronunciationType.uk:
        // 优先返回英音
        if (ukSpeech?.isNotEmpty == true) {
          return ukSpeech;
        }
        // 回退到美音
        if (usSpeech?.isNotEmpty == true) {
          return usSpeech;
        }
        return null;
      case PronunciationType.us:
        // 优先返回美音
        if (usSpeech?.isNotEmpty == true) {
          return usSpeech;
        }
        // 回退到英音
        if (ukSpeech?.isNotEmpty == true) {
          return ukSpeech;
        }
        return null;
    }
  }
}

 