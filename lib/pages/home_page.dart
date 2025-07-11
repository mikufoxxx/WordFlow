import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import '../models/word_book.dart';
import '../utils/cache_service.dart';

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
  
  // 当前学习的单词数量（无限流模式）
  int _studiedWordsCount = 0;
  
  // 是否显示单词释义
  bool _showMeaning = false;
  
  // 单词动画是否完成
  bool _wordAnimationCompleted = false;
  
  // 主要动画控制器
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _meaningController; // 释义框动画控制器
  late AnimationController _buttonsController; // 按钮动画控制器
  
  // 水滴球相关
  late AnimationController _dropController; // 水滴球动画控制器
  late AnimationController _hintController; // 提示区域动画控制器
  Offset _dragOffset = Offset.zero; // 当前拖拽偏移
  Offset _initialPosition = Offset.zero; // 初始位置
  bool _isDragging = false; // 是否正在拖拽
  String _dragHint = ''; // 拖拽提示文字
  Color _hintColor = Colors.grey; // 提示颜色
  
  // 拖拽阈值和动画
  final double _dragThreshold = 80.0;
  late Animation<double> _dropScaleAnimation;
  late Animation<double> _dropRotationAnimation;
  late Animation<double> _hintOpacityAnimation;
  late Animation<double> _hintScaleAnimation;
  
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
  List<Animation<double>> _meaningSlideAnimations = [];
  List<Animation<double>> _meaningOpacityAnimations = [];
  List<Animation<double>> _exampleSlideAnimations = [];
  List<Animation<double>> _exampleOpacityAnimations = [];
  List<Animation<double>> _exampleTranslationSlideAnimations = [];
  List<Animation<double>> _exampleTranslationOpacityAnimations = [];
  
  // 用于管理延迟执行的Timer，避免动画冲突
  List<Timer> _animationTimers = [];
  
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

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    _initializeMainAnimations();
    _loadWordsFromSelectedWordBook();
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
          _errorMessage = '词库数据为空，请重新下载词库';
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
      _generateNextWord();
    _initializeCharacterAnimations();
    _startWordAnimation();
      
    } catch (e) {
      setState(() {
        _errorMessage = '加载词库失败: $e';
        _isLoadingWords = false;
      });
    }
  }

  /// 生成下一个单词（扩展版本）
  void _generateNextWord() {
    if (_words.isEmpty) return;
    
    // 随机选择一个单词
    final randomIndex = _random.nextInt(_words.length);
    final wordData = _words[randomIndex];
    
    // 创建扩展的单词数据（为演示目的生成示例数据）
    _currentWord = ExtendedWordData.fromWordData(wordData);
  }

  /// 初始化音频播放器
  void _initializeAudioPlayer() {
    _audioPlayer = AudioPlayer();
  }

  /// 播放设置页面音效
  void _playSettingSound() async {
    try {
      await _audioPlayer.setVolume(1);
      await _audioPlayer.play(AssetSource('sound/settingpage.mp3'));
    } catch (e) {
      print('播放音效失败: $e');
    }
  }

  /// 播放词库选择音效
  void _playBookPageSound() async {
    try {
      await _audioPlayer.setVolume(1);
      await _audioPlayer.play(AssetSource('sound/bookpage.mp3'));
    } catch (e) {
      print('播放音效失败: $e');
    }
  }

  /// 初始化主要动画控制器
  void _initializeMainAnimations() {
    // 主要动画控制器
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // 释义框动画控制器
    _meaningController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // 按钮动画控制器
    _buttonsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // 水滴球动画控制器
    _dropController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // 提示区域动画控制器
    _hintController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // 水滴球缩放动画
    _dropScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _dropController,
      curve: Curves.elasticOut,
    ));
    
    // 水滴球旋转动画
    _dropRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _dropController,
      curve: Curves.easeOutBack,
    ));
    
    // 提示文字透明度动画
    _hintOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hintController,
      curve: Curves.easeOutCubic,
    ));
    
    // 提示文字缩放动画
    _hintScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hintController,
      curve: Curves.easeOutBack,
    ));
    
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
    
    // 翻译字符动画
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
    
    
    _meaningSlideAnimations = _meaningControllers.map((controller) =>
      Tween<double>(begin: 10.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutQuart,
        ),
      ),
    ).toList();
    
    _meaningOpacityAnimations = _meaningControllers.map((controller) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller, 
          curve: Curves.easeOutCubic,
        ),
      ),
    ).toList();
    
    // 例句字符动画
    _exampleControllers = List.generate(
      currentWord.example.length,
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
      
      // 启动按钮动画
      Timer timer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          _buttonsController.forward();
        }
      });
      _animationTimers.add(timer);
    }
  }

  /// 启动字符动画
  void _startCharacterAnimation(List<AnimationController> controllers, int delayMs) {
    for (int i = 0; i < controllers.length; i++) {
      Timer timer = Timer(Duration(milliseconds: i * delayMs), () {
        if (mounted && i < controllers.length) {
          controllers[i].forward();
        }
      });
      _animationTimers.add(timer);
    }
  }

  /// 立即重置所有释义框相关的字符动画状态
  void _resetMeaningCharacterAnimations() {
    _cancelAllAnimationTimers();
    
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

  /// 取消所有待执行的动画Timer
  void _cancelAllAnimationTimers() {
    for (Timer timer in _animationTimers) {
      timer.cancel();
    }
    _animationTimers.clear();
  }

  /// 清理字符控制器
  void _disposeCharacterControllers() {
    _cancelAllAnimationTimers();
    
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'WordFlow',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
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
              iconSize: 40,
              onPressed: () {
                _playBookPageSound();
                Navigator.pushNamed(context, '/library');
              },
              tooltip: '词库选择',
              color: Theme.of(context).primaryColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
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
                iconSize: 40,
                onPressed: () {
                  _playSettingSound();
                  Navigator.pushNamed(context, '/settings');
                },
                color: Theme.of(context).primaryColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
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
            SizedBox(height: 16),
            Text(
              '正在加载词库...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/library');
                },
                icon: Icon(Icons.library_books),
                label: Text('选择词库'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentWord == null) {
      return Center(
        child: Text(
          '词库为空',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 
                     kToolbarHeight - 
                     MediaQuery.of(context).padding.top - 
                     MediaQuery.of(context).padding.bottom - 40,
        ),
        child: IntrinsicHeight(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 词库名称显示
              _buildWordBookHeader(),
              
              const SizedBox(height: 30),
              
              // 单词卡片
              Flexible(
                child: _buildWordCard(_currentWord!),
              ),
              
              const SizedBox(height: 30),
              
              // 水滴拖拽球
              _buildFluidDragBall(),
              
              const SizedBox(height: 15),
              
              // 提示文字
              _buildAnimatedHintText(),
              
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建词库名称头部
  Widget _buildWordBookHeader() {
    if (_currentWordBookName == null) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: Theme.of(context).primaryColor,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            _currentWordBookName!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '已学 $_studiedWordsCount 词',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).primaryColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建水滴状拖拽球
  Widget _buildFluidDragBall() {
    return AnimatedBuilder(
      animation: _buttonsController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonsSlideAnimation.value),
          child: Opacity(
            opacity: _buttonsOpacityAnimation.value,
            child: IgnorePointer(
              ignoring: !_wordAnimationCompleted,
          child: Column(
                mainAxisSize: MainAxisSize.min,
            children: [
                  // 拖拽提示（上方）
                  AnimatedOpacity(
                    opacity: _isDragging && _getDragDirection() == 'up' ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 200),
                    child: _buildHintBubble(
                      _showMeaning ? '隐藏释义' : '已隐藏',
                      Icons.visibility_off,
                      Colors.orange,
                      _getDragDirection() == 'up',
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // 水滴球主体
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                children: [
                      // 左侧提示
                      AnimatedOpacity(
                        opacity: _isDragging && _getDragDirection() == 'left' ? 1.0 : 0.0,
                        duration: Duration(milliseconds: 200),
                        child: _buildHintBubble(
                          '不认识',
                          Icons.close,
                          Colors.red,
                          _getDragDirection() == 'left',
                        ),
                      ),
                      
                      SizedBox(width: 20),
                      
                      // 水滴球
                      GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: AnimatedBuilder(
                          animation: _dropController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: _dragOffset,
                              child: Transform.scale(
                                scale: _dropScaleAnimation.value,
                                child: Transform.rotate(
                                  angle: _dropRotationAnimation.value * 
                                         (_dragOffset.dx / 100),
                                  child: _buildDropShape(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      SizedBox(width: 20),
                      
                      // 右侧提示
                      AnimatedOpacity(
                        opacity: _isDragging && _getDragDirection() == 'right' ? 1.0 : 0.0,
                        duration: Duration(milliseconds: 200),
                        child: _buildHintBubble(
                          '认识',
                          Icons.check,
                          Colors.green,
                          _getDragDirection() == 'right',
                ),
              ),
            ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // 拖拽提示（下方）
                  AnimatedOpacity(
                    opacity: _isDragging && _getDragDirection() == 'down' ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 200),
                    child: _buildHintBubble(
                      _showMeaning ? '已显示' : '显示释义',
                      Icons.visibility,
                      Colors.blue,
                      _getDragDirection() == 'down',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建水滴形状
  Widget _buildDropShape() {
    return Container(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _DropPainter(
          color: Theme.of(context).primaryColor,
          dragOffset: _dragOffset,
          isDragging: _isDragging,
        ),
        child: Center(
          child: Icon(
            _isDragging ? Icons.drag_indicator : Icons.touch_app,
            color: Colors.white,
            size: _isDragging ? 24 : 28,
          ),
        ),
      ),
    );
  }

  /// 构建提示气泡
  Widget _buildHintBubble(String text, IconData icon, Color color, bool isActive) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(
        minWidth: 60,
        maxWidth: 100,
        minHeight: 32,
        maxHeight: 40,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.9) : color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive ? [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ] : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.white : color,
            size: 14,
          ),
          SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: isActive ? Colors.white : color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取拖拽方向
  String _getDragDirection() {
    final dx = _dragOffset.dx.abs();
    final dy = _dragOffset.dy.abs();
    
    if (dx > dy) {
      return _dragOffset.dx > 0 ? 'right' : 'left';
    } else {
      return _dragOffset.dy > 0 ? 'down' : 'up';
    }
  }

  /// 拖拽开始
  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _initialPosition = details.localPosition;
    _dropController.forward();
    _hintController.forward();
    setState(() {});
  }

  /// 拖拽更新
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = details.localPosition - _initialPosition;
      
      // 添加阻尼效果
      final distance = _dragOffset.distance;
      if (distance > _dragThreshold) {
        final dampening = _dragThreshold / distance;
        _dragOffset = Offset(
          _dragOffset.dx * dampening,
          _dragOffset.dy * dampening,
        );
      }
    });
  }

  /// 拖拽结束
  void _onPanEnd(DragEndDetails details) {
    final distance = _dragOffset.distance;
    final direction = _getDragDirection();
    
    // 判断是否达到触发阈值
    if (distance > _dragThreshold * 0.6) {
      _triggerAction(direction);
    }
    
    // 重置状态
    _isDragging = false;
    _dragOffset = Offset.zero;
    _dropController.reverse();
    _hintController.reverse();
    setState(() {});
  }

  /// 触发对应操作
  void _triggerAction(String direction) {
    switch (direction) {
      case 'left':
        _markAsUnknown();
        break;
      case 'right':
        _markAsKnown();
        break;
      case 'down':
        if (!_showMeaning) _toggleMeaning();
        break;
      case 'up':
        if (_showMeaning) _toggleMeaning();
        break;
    }
  }

  /// 开始单词动画
  void _startWordAnimation() {
    _fadeController.forward();
    _slideController.forward();
    
    // 启动单词字符动画
    Timer timer = Timer(const Duration(milliseconds: 300), () {
      _startCharacterAnimation(_wordControllers, 60);
    });
    _animationTimers.add(timer);
  }

  /// 开始释义动画
  void _startMeaningAnimation() {
    if (_showMeaning) {
      _meaningController.forward();
      
      Timer timer1 = Timer(const Duration(milliseconds: 100), () {
        _startCharacterAnimation(_translationControllers, 40);
      });
      _animationTimers.add(timer1);
      
      Timer timer2 = Timer(const Duration(milliseconds: 200), () {
        _startCharacterAnimation(_meaningControllers, 30);
      });
      _animationTimers.add(timer2);
      
      Timer timer3 = Timer(const Duration(milliseconds: 300), () {
        _startCharacterAnimation(_exampleControllers, 35);
      });
      _animationTimers.add(timer3);
      
      Timer timer4 = Timer(const Duration(milliseconds: 400), () {
        _startCharacterAnimation(_exampleTranslationControllers, 40);
      });
      _animationTimers.add(timer4);
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
    
    if (_showMeaning) {
      _resetMeaningCharacterAnimations();
    } else {
      _resetMeaningCharacterAnimations();
    }
    
    _startMeaningAnimation();
  }

  /// 标记为不认识
  void _markAsUnknown() {
    if (!_wordAnimationCompleted) return;
    _nextWord();
  }

  /// 标记为认识
  void _markAsKnown() {
    if (!_wordAnimationCompleted) return;
    _nextWord();
  }

  /// 下一个单词（无限流模式）
  void _nextWord() {
    // 重置动画状态
    _fadeController.reset();
    _slideController.reset();
    _meaningController.reset();
    _buttonsController.reset();
    
    // 取消所有动画Timer
    _cancelAllAnimationTimers();
    
    setState(() {
      _studiedWordsCount++;
      _showMeaning = false;
      _wordAnimationCompleted = false;
      _completedWordAnimations = 0;
    });
    
    // 生成新单词
    _generateNextWord();
    
    // 重新初始化字符动画
    _initializeCharacterAnimations();
    
    // 开始新单词动画
    _startWordAnimation();
  }

  /// 构建单词卡片
  Widget _buildWordCard(ExtendedWordData word) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _slideController.value)),
          child: FadeTransition(
            opacity: _fadeController,
            child: Card(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuart,
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 单词本体
                    Container(
                      constraints: BoxConstraints(minHeight: 65, maxHeight: 80),
                      child: _buildAnimatedText(
                        word.word,
                        _wordSlideAnimations,
                        _wordOpacityAnimations,
                        Theme.of(context).textTheme.headlineLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 2), // 从8改为4，使音标与单词更近
                    
                    // 音标
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      opacity: _fadeController.value,
                      child: Text(
                        word.pronunciation,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
    );
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
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 中文释义
                      Container(
                        constraints: BoxConstraints(minHeight: 35, maxHeight: 50),
                        child: _buildAnimatedText(
                          word.translation,
                          _translationSlideAnimations,
                          _translationOpacityAnimations,
                          Theme.of(context).textTheme.titleLarge!.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 详细释义部分被删除了，因为现在直接使用translation作为meaning
                      
                      const SizedBox(height: 12),
                      
                      // 例句容器
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuart,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
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
                              constraints: BoxConstraints(minHeight: 40, maxHeight: 55),
                              child: _buildAnimatedText(
                                word.example,
                                _exampleSlideAnimations,
                                _exampleOpacityAnimations,
                                Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 1), // 从3改为1，使例句翻译更近
                            // 例句翻译
                            Container(
                              constraints: BoxConstraints(minHeight: 30, maxHeight: 40),
                              child: _buildAnimatedText(
                                word.exampleTranslation,
                                _exampleTranslationSlideAnimations,
                                _exampleTranslationOpacityAnimations,
                                Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  color: Colors.grey.shade600,
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

  /// 构建字符独立动画的文本
  Widget _buildAnimatedText(
    String text,
    List<Animation<double>> slideAnimations,
    List<Animation<double>> opacityAnimations,
    TextStyle style,
  ) {
    return Center(
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
                _wordAnimationCompleted 
                    ? '拖拽水滴进行操作\n← 不认识  → 认识  ↓ 显示释义  ↑ 隐藏释义'
                    : '单词加载中...',
                key: ValueKey('${_wordAnimationCompleted}_fluid'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _cancelAllAnimationTimers();
    _fadeController.dispose();
    _slideController.dispose();
    _meaningController.dispose();
    _buttonsController.dispose();
    _dropController.dispose();
    _hintController.dispose();
    _disposeCharacterControllers();
    _audioPlayer.dispose();
    super.dispose();
  }
}

/// 扩展的单词数据模型（包含音标、详细释义、例句等）
class ExtendedWordData {
  final String word;
  final String pronunciation;
  // final String meaning;
  final String translation;
  final String example;
  final String exampleTranslation;

  ExtendedWordData({
    required this.word,
    required this.pronunciation,
    // required this.meaning,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
  });

  /// 从基础WordData创建扩展数据
  factory ExtendedWordData.fromWordData(WordData wordData) {
    // 为演示目的，这里生成一些示例数据
    // 实际应用中可以从词典API获取更详细的信息
    return ExtendedWordData(
      word: wordData.word,
      pronunciation: _generatePronunciation(wordData.word),
      // meaning: wordData.translation, // 直接使用翻译作为释义，不添加额外内容
      translation: wordData.translation,
      example: _generateExample(wordData.word),
      exampleTranslation: _generateExampleTranslation(wordData.word),
    );
  }

  static String _generatePronunciation(String word) {
    // 简单的音标生成（实际应用中应该从词典API获取）
    return "/${word.toLowerCase()}/";
  }

  static String _generateExample(String word) {
    // 生成示例句子
    return "This is an example sentence with the word '$word'.";
  }

  static String _generateExampleTranslation(String word) {
    // 生成例句翻译
    return "这是一个包含单词'$word'的例句。";
  }
}

/// 水滴形状绘制器
class _DropPainter extends CustomPainter {
  final Color color;
  final Offset dragOffset;
  final bool isDragging;

  _DropPainter({
    required this.color,
    required this.dragOffset,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 3;
    
    if (!isDragging) {
      // 静态水滴形状
      final path = Path();
      
      // 绘制水滴的主体部分（圆形）
      path.addOval(Rect.fromCircle(
        center: center,
        radius: baseRadius,
      ));
      
      // 绘制水滴的尖端
      final tipHeight = baseRadius * 0.6;
      path.moveTo(center.dx, center.dy - baseRadius);
      path.quadraticBezierTo(
        center.dx - baseRadius * 0.5, center.dy - baseRadius - tipHeight * 0.5,
        center.dx, center.dy - baseRadius - tipHeight,
      );
      path.quadraticBezierTo(
        center.dx + baseRadius * 0.5, center.dy - baseRadius - tipHeight * 0.5,
        center.dx, center.dy - baseRadius,
      );
      
      canvas.drawPath(path, paint);
    } else {
      // 拖拽时的形变效果
      final stretchAmount = dragOffset.distance / 10;
      final normalizedOffset = dragOffset.distance > 0 
          ? Offset(dragOffset.dx / dragOffset.distance, dragOffset.dy / dragOffset.distance)
          : Offset.zero;
      
      // 绘制拉伸的椭圆
      final rect = Rect.fromCenter(
        center: center,
        width: baseRadius * 2 + stretchAmount * normalizedOffset.dx.abs(),
        height: baseRadius * 2 + stretchAmount * normalizedOffset.dy.abs(),
      );
      
      canvas.drawOval(rect, paint);
      
      // 在拖拽方向绘制拉伸效果
      if (stretchAmount > 5) {
        final stretchPaint = Paint()
          ..color = color.withOpacity(0.6)
          ..style = PaintingStyle.fill;
        
        final stretchCenter = center - normalizedOffset * stretchAmount * 0.3;
        canvas.drawCircle(stretchCenter, baseRadius * 0.7, stretchPaint);
      }
    }
    
    // 添加高光效果
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      center - Offset(baseRadius * 0.3, baseRadius * 0.3),
      baseRadius * 0.2,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DropPainter oldDelegate) {
    return oldDelegate.dragOffset != dragOffset || 
           oldDelegate.isDragging != isDragging ||
           oldDelegate.color != color;
  }
} 