import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// 主页 - 背单词页面
/// 以流的形式显示单词，每次显示一个单词，背过就显示下一个
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> 
    with TickerProviderStateMixin {
  
  // 音频播放器
  late AudioPlayer _audioPlayer;
  
  // 当前单词索引
  int _currentWordIndex = 0;
  
  // 是否显示单词释义
  bool _showMeaning = false;
  
  // 单词动画是否完成
  bool _wordAnimationCompleted = false;
  
  // 主要动画控制器
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _meaningController; // 释义框动画控制器
  late AnimationController _progressController; // 进度条动画控制器
  late AnimationController _buttonsController; // 按钮动画控制器
  
  // 释义框动画
  late Animation<double> _meaningHeightAnimation;
  late Animation<double> _meaningOpacityAnimation;
  late Animation<double> _meaningScaleAnimation;
  
  // 进度条动画
  late Animation<double> _progressAnimation;
  
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
  
  // 示例单词列表（实际应用中应该从数据库或API获取）
  final List<WordData> _words = [
    WordData(
      word: "serendipity",
      pronunciation: "/ˌserənˈdɪpəti/",
      meaning: "意外发现珍奇事物的能力；机缘巧合",
      translation: "偶然发现",
      example: "It was pure serendipity that led to this discovery.",
      exampleTranslation: "这一发现纯属偶然。",
    ),
    WordData(
      word: "eloquent",
      pronunciation: "/ˈeləkwənt/",
      meaning: "雄辩的；有说服力的；富于表现力的",
      translation: "雄辩的",
      example: "She gave an eloquent speech about climate change.",
      exampleTranslation: "她就气候变化发表了一篇雄辩的演讲。",
    ),
    WordData(
      word: "ephemeral",
      pronunciation: "/ɪˈfemərəl/",
      meaning: "短暂的；朝生暮死的",
      translation: "短暂的",
      example: "The beauty of cherry blossoms is ephemeral.",
      exampleTranslation: "樱花之美是短暂的。",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    _initializeMainAnimations();
    _initializeCharacterAnimations();
    _startWordAnimation();
  }

  /// 初始化音频播放器
  void _initializeAudioPlayer() {
    _audioPlayer = AudioPlayer();
  }

  /// 播放设置页面音效
  void _playSettingSound() async {
    try {
      await _audioPlayer.setVolume(1); // 设置音量为50%，你可以调整为0.1~1.0之间
      await _audioPlayer.play(AssetSource('sound/settingpage.mp3'));
    } catch (e) {
      print('播放音效失败: $e');
    }
  }

  /// 播放词库选择音效
  void _playBookPageSound() async {
    try {
      await _audioPlayer.setVolume(1); // 设置音量，按需调整
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
    
    // 进度条动画控制器
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // 按钮动画控制器
    _buttonsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // 释义框动画 - 使用优雅的贝塞尔曲线，支持正向和反向
    _meaningHeightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _meaningController,
      curve: Curves.easeOutQuart, // 展开时使用
      reverseCurve: Curves.easeInQuart, // 收起时使用
    ));
    
    _meaningOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _meaningController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic, // 收起时使用
    ));
    
    _meaningScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _meaningController,
      curve: Curves.easeOutBack, // 展开时的弹性效果
      reverseCurve: Curves.easeInBack, // 收起时的弹性效果
    ));
    
    // 进度条动画
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutQuint, // 五次方缓出曲线
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
    final currentWord = _words[_currentWordIndex];
    
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
            // 所有单词字符动画完成
            _onWordAnimationCompleted();
          }
        }
      });
    }
    
    _wordSlideAnimations = _wordControllers.map((controller) =>
      Tween<double>(begin: 15.0, end: 0.0).animate( // 缩短浮现距离到15px
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
      Tween<double>(begin: 12.0, end: 0.0).animate( // 更短的浮现距离
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
      currentWord.meaning.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    
    _meaningSlideAnimations = _meaningControllers.map((controller) =>
      Tween<double>(begin: 10.0, end: 0.0).animate( // 更短的浮现距离
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

  /// 启动字符动画（只支持正向）
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
    // 取消所有待执行的动画Timer
    _cancelAllAnimationTimers();
    
    // 立即停止并重置所有释义相关的字符动画
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
    // 先取消所有Timer
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
    final currentWord = _words[_currentWordIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'WordFlow',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 28, // 标题更大
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
              enableFeedback: false, // 关闭系统点击音
              icon: const Icon(Icons.library_books_outlined),
              iconSize: 40,
              onPressed: () {
                _playBookPageSound(); // 播放你自己的音效
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
                enableFeedback: false, // 关闭系统点击音
                icon: const Icon(Icons.settings_outlined),
                iconSize: 40,
                onPressed: () {
                  _playSettingSound(); // 播放你自己的音效
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
      body: GestureDetector(
        // 只有当单词动画完成后才允许点击切换释义
        onTap: _wordAnimationCompleted ? _toggleMeaning : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 进度指示器 - 添加动画
              _buildAnimatedProgressIndicator(),
              
              const SizedBox(height: 40),
              
              // 单词卡片
              _buildWordCard(currentWord),
              
              const SizedBox(height: 40),
              
              // 操作按钮 - 只有单词动画完成后才显示
              _buildAnimatedActionButtons(),
              
              const SizedBox(height: 20),
              
              // 提示文字 - 只有单词动画完成后才显示
              _buildAnimatedHintText(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建动画进度指示器
  Widget _buildAnimatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.bodyMedium!,
                    child: const Text('今日进度'),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.bodyMedium!,
                    child: Text('${_currentWordIndex + 1} / ${_words.length}'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value * ((_currentWordIndex + 1) / _words.length),
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单词卡片
  Widget _buildWordCard(WordData word) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _slideController.value)), // 缩短卡片进入距离
          child: FadeTransition(
            opacity: _fadeController,
            child: Card(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuart,
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    // 单词本体 - 每个字母独立浮现
                    SizedBox(
                      height: 80,
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
                    
                    const SizedBox(height: 12),
                    
                    // 音标 - 添加淡入动画
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
                    
                    // 释义部分 - 优雅的展开/收起动画
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
  Widget _buildAnimatedMeaningSection(WordData word) {
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
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 中文释义 - 字符独立动画
                      SizedBox(
                        height: 50,
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
                      
                      const SizedBox(height: 12),
                      
                      // 详细释义 - 字符独立动画
                      SizedBox(
                        height: 80,
                        child: _buildAnimatedText(
                          word.meaning,
                          _meaningSlideAnimations,
                          _meaningOpacityAnimations,
                          Theme.of(context).textTheme.bodyLarge!,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 例句容器 - 添加动画
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuart,
                        padding: const EdgeInsets.all(12),
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
                          children: [
                            // 例句 - 字符独立动画
                            SizedBox(
                              height: 60,
                              child: _buildAnimatedText(
                                word.example,
                                _exampleSlideAnimations,
                                _exampleOpacityAnimations,
                                Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // 例句翻译 - 字符独立动画
                            SizedBox(
                              height: 40,
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
          // 如果是空格，返回固定宽度的空白
          if (text[index] == ' ') {
            return SizedBox(
              width: style.fontSize! * 0.3,
              height: style.fontSize! * 1.2,
            );
          }
          
          // 确保不会越界
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

  /// 构建动画操作按钮
  Widget _buildAnimatedActionButtons() {
    return AnimatedBuilder(
      animation: _buttonsController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonsSlideAnimation.value),
          child: Opacity(
            opacity: _buttonsOpacityAnimation.value,
            child: IgnorePointer(
              // 单词动画未完成时禁用按钮交互
              ignoring: !_wordAnimationCompleted,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 不认识按钮 - 添加悬停和点击动画
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 1.0, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: ElevatedButton.icon(
                          onPressed: _wordAnimationCompleted ? _markAsUnknown : null,
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('不认识'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red,
                            elevation: 2,
                            shadowColor: Colors.red.withOpacity(0.3),
                          ).copyWith(
                            animationDuration: const Duration(milliseconds: 200),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // 认识按钮 - 添加悬停和点击动画
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 1.0, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: ElevatedButton.icon(
                          onPressed: _wordAnimationCompleted ? _markAsKnown : null,
                          icon: const Icon(Icons.check, color: Colors.green),
                          label: const Text('认识'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade50,
                            foregroundColor: Colors.green,
                            elevation: 2,
                            shadowColor: Colors.green.withOpacity(0.3),
                          ).copyWith(
                            animationDuration: const Duration(milliseconds: 200),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                    ? (_showMeaning ? '点击屏幕隐藏释义' : '点击屏幕查看释义')
                    : '单词加载中...',
                key: ValueKey('${_wordAnimationCompleted}_$_showMeaning'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 开始单词动画
  void _startWordAnimation() {
    _fadeController.forward();
    _slideController.forward();
    _progressController.forward();
    
    // 启动单词字符动画
    Timer timer = Timer(const Duration(milliseconds: 300), () {
      _startCharacterAnimation(_wordControllers, 60); // 每60ms一个字符
    });
    _animationTimers.add(timer);
  }

  /// 开始释义动画
  void _startMeaningAnimation() {
    if (_showMeaning) {
      // 展开动画 - 框先展开，然后文字流式出现
      _meaningController.forward();
      
      // 依次启动释义相关的字符动画
      Timer timer1 = Timer(const Duration(milliseconds: 100), () {
        _startCharacterAnimation(_translationControllers, 40); // 翻译
      });
      _animationTimers.add(timer1);
      
      Timer timer2 = Timer(const Duration(milliseconds: 200), () {
        _startCharacterAnimation(_meaningControllers, 30); // 详细释义
      });
      _animationTimers.add(timer2);
      
      Timer timer3 = Timer(const Duration(milliseconds: 300), () {
        _startCharacterAnimation(_exampleControllers, 35); // 例句
      });
      _animationTimers.add(timer3);
      
      Timer timer4 = Timer(const Duration(milliseconds: 400), () {
        _startCharacterAnimation(_exampleTranslationControllers, 40); // 例句翻译
      });
      _animationTimers.add(timer4);
    } else {
      // 收起动画 - 立即重置所有文字状态，然后框收起
      _resetMeaningCharacterAnimations();
      _meaningController.reverse();
    }
  }

  /// 切换释义显示
  void _toggleMeaning() {
    // 只有当单词动画完成后才允许切换释义
    if (!_wordAnimationCompleted) return;
    
    setState(() {
      _showMeaning = !_showMeaning;
    });
    
    if (_showMeaning) {
      // 展开时重置释义动画并开始播放
      _resetMeaningCharacterAnimations();
    } else {
      // 收起时立即停止所有相关动画和Timer
      _resetMeaningCharacterAnimations();
    }
    
    _startMeaningAnimation();
  }

  /// 标记为不认识
  void _markAsUnknown() {
    // 只有当单词动画完成后才允许操作
    if (!_wordAnimationCompleted) return;
    _nextWord();
    // TODO: 实际应用中应该记录用户的学习数据
  }

  /// 标记为认识
  void _markAsKnown() {
    // 只有当单词动画完成后才允许操作
    if (!_wordAnimationCompleted) return;
    _nextWord();
    // TODO: 实际应用中应该记录用户的学习数据
  }

  /// 下一个单词
  void _nextWord() {
    if (_currentWordIndex < _words.length - 1) {
      // 重置动画状态
      _fadeController.reset();
      _slideController.reset();
      _meaningController.reset();
      _progressController.reset();
      _buttonsController.reset();
      
      // 取消所有动画Timer
      _cancelAllAnimationTimers();
      
      setState(() {
        _currentWordIndex++;
        _showMeaning = false;
        _wordAnimationCompleted = false;
        _completedWordAnimations = 0;
      });
      
      // 重新初始化字符动画
      _initializeCharacterAnimations();
      
      // 开始新单词动画
      _startWordAnimation();
    } else {
      // 所有单词完成
      _showCompletionDialog();
    }
  }

  /// 显示完成对话框
  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恭喜完成！'),
        content: const Text('你已经完成了今天的单词学习任务！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 重置到第一个单词
              setState(() {
                _currentWordIndex = 0;
                _showMeaning = false;
                _wordAnimationCompleted = false;
                _completedWordAnimations = 0;
              });
              _fadeController.reset();
              _slideController.reset();
              _meaningController.reset();
              _progressController.reset();
              _buttonsController.reset();
              _cancelAllAnimationTimers();
              _initializeCharacterAnimations();
              _startWordAnimation();
            },
            child: const Text('重新开始'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cancelAllAnimationTimers();
    _fadeController.dispose();
    _slideController.dispose();
    _meaningController.dispose();
    _progressController.dispose();
    _buttonsController.dispose();
    _disposeCharacterControllers();
    _audioPlayer.dispose(); // 释放音频播放器资源
    super.dispose();
  }
}

/// 单词数据模型
class WordData {
  final String word;           // 单词
  final String pronunciation; // 音标
  final String meaning;       // 详细释义
  final String translation;   // 中文翻译
  final String example;       // 例句
  final String exampleTranslation; // 例句翻译

  WordData({
    required this.word,
    required this.pronunciation,
    required this.meaning,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
  });
} 