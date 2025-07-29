// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lordicon/lordicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/animated_text_helper.dart';
import '../utils/responsive_helper.dart';
import '../utils/performance_optimizer.dart';
import '../utils/deepseek_api_service.dart';
import 'dart:async';

/// 起始页面 - 重新设计的引导流程
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> 
    with TickerProviderStateMixin {
  
  // 性能优化：使用池化的key
  static const String _animationPoolKey = 'onboarding_page_animations';
  static const String _timerPoolKey = 'onboarding_page_timers';
  
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Token输入相关
  final TextEditingController _tokenController = TextEditingController();
  bool _isTokenValid = false;
  bool _showToken = false;
  
  // 轮播图相关
  late PageController _carouselController;
  late Timer _carouselTimer;
  int _carouselIndex = 0;
  
  // 动画控制器 - 为每个页面创建独立的控制器
  late List<AnimationController> _textAnimationControllers;
  late AnimationController _carouselAnimationController;
  
  // 页面数据 - 使用更柔和的颜色
  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: "WordFlow词流",
      subtitle: "让学习如流水般自然",
      description: "采用流式文字动画\n让每个单词都生动地浮现在眼前",
      icon: Icons.auto_stories_outlined,
      color: Color(0xFF6B7280), // 更柔和的灰色
    ),
    OnboardingPageData(
      title: "研习典则",
      subtitle: "三步轻松掌握单词",
      description: "简单高效的学习方式\n让背单词变成一种享受",
      icon: Icons.psychology_outlined,
      color: Color(0xFF8B5CF6), // 更柔和的紫色
    ),
          OnboardingPageData(
        title: "始于足下",
        subtitle: "输入API Key, 开启智能造句判断",
        description: "输入DeepSeek API Key\n开启智能造句判断",
        icon: Icons.psychology_outlined,
        color: Color(0xFF10B981), // 更柔和的绿色
      ),
  ];
  
  // 学习流程数据 - 使用更柔和的颜色
  final List<LearningStepData> _learningSteps = [
    LearningStepData(
      title: "单词呈现",
      description: "沉浸体验\n单词如流水般展现",
      icon: Icons.auto_awesome_outlined,
      color: AppTheme.primaryGray,
    ),
    LearningStepData(
      title: "深入记忆",
      description: "连词成句\n在思考中构建语言直觉",
      icon: Icons.psychology_alt_outlined,
      color: AppTheme.primaryGray,
    ),
    LearningStepData(
      title: "智能推送",
      description: "无限推词\n让你的词本独一无二",
      icon: Icons.psychology_outlined,
      color: AppTheme.primaryGray,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCarousel();
    _tokenController.addListener(_onTokenChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselController.dispose();
    _carouselTimer.cancel();
    _tokenController.dispose();
    
    // 使用性能优化器清理资源
    PerformanceOptimizer.cancelTimers(_timerPoolKey);
    PerformanceOptimizer.disposeAnimationControllers(_animationPoolKey);
    
    // 销毁所有动画控制器
    for (final controller in _textAnimationControllers) {
      controller.dispose();
    }
    _carouselAnimationController.dispose();
    
    super.dispose();
  }

  /// 初始化动画 - 为每个页面创建独立的控制器
  void _initializeAnimations() {
    _textAnimationControllers = List.generate(
      _pages.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      ),
    );
    
    _carouselAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // 启动第一页的动画
    _textAnimationControllers[0].forward();
  }
  
  /// 初始化轮播图
  void _initializeCarousel() {
    _carouselController = PageController();
    _startCarouselTimer();
  }
  
  /// 启动轮播图定时器
  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage == 1) { // 只在第二页时自动轮播
        _nextCarouselItem();
      }
    });
  }
  
  /// 下一个轮播项
  void _nextCarouselItem() {
    if (_carouselController.hasClients) {
      final nextIndex = (_carouselIndex + 1) % _learningSteps.length;
      _carouselController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }
  
  /// Token输入变化监听
  void _onTokenChanged() {
    final token = _tokenController.text.trim();
    final isValid = token.isNotEmpty && token.length >= 10; // 简单验证
    
    if (isValid != _isTokenValid) {
      setState(() {
        _isTokenValid = isValid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkBackgroundColor 
          : AppTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveHelper.getMaxContentWidth(context),
                ),
        child: Column(
          children: [
            // 页面指示器
            _buildPageIndicator(),
            
            // 主要内容
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(index),
              ),
            ),
            
            // 底部按钮
            _buildBottomButtons(),
          ],
        ),
      ),
            ),
          ),
        );
      },
    );
  }
  
  /// 构建页面指示器
  Widget _buildPageIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getResponsiveSpacing(context, 16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveSpacing(context, 4)),
            width: _currentPage == index ? ResponsiveHelper.getResponsiveSpacing(context, 20) : ResponsiveHelper.getResponsiveSpacing(context, 8),
            height: ResponsiveHelper.getResponsiveSpacing(context, 6),
            decoration: BoxDecoration(
              color: _currentPage == index 
                ? AppTheme.primaryGray 
                : AppTheme.coolGray300,
              borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 3)),
            ),
          );
        }),
      ),
    );
  }
  
  /// 构建页面内容
  Widget _buildPage(int index) {
    final page = _pages[index];
    
    return Padding(
      padding: ResponsiveHelper.getResponsivePadding(context),
      child: Column(
        children: [
          // 图标区域 - 不使用动画
          Expanded(
            flex: 3,
            child: _buildIconSection(page, index),
          ),
          
          // 文字区域 - 使用逐字浮现动画
          Expanded(
            flex: 2,
            child: _buildTextSection(page, index),
          ),
        ],
      ),
    );
  }
  
  /// 构建图标区域 - 不使用动画
  Widget _buildIconSection(OnboardingPageData page, int index) {
    return Center(
      child: _buildPageSpecificIcon(page, index),
    );
  }
  
  /// 构建特定页面的图标内容
  Widget _buildPageSpecificIcon(OnboardingPageData page, int index) {
    switch (index) {
      case 0:
        return _buildWelcomeIcon(page);
      case 1:
        return _buildLearningCarousel();
      case 2:
        return _buildTokenInputIcon(page);
      default:
        return _buildWelcomeIcon(page);
    }
  }
  
  /// 构建欢迎页图标
  Widget _buildWelcomeIcon(OnboardingPageData page) {
    var controller = IconController.assets('assets/icon/wired-outline-112-book-hover-pinch.json');

    controller.addStatusListener((status) {
      if (status == ControllerStatus.ready) {
        controller.playFromBeginning();
      }
    });

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.primaryGray.withOpacity(0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGray.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconViewer(
        controller: controller,
        width: 60,
        height: 60,
      ),
    );
  }
  
  /// 构建学习流程轮播图 - 增强视差动效
  Widget _buildLearningCarousel() {
    return SizedBox(
      height: 260, // 增加高度以容纳视差效果
      child: PageView.builder(
        controller: _carouselController,
        onPageChanged: (index) {
          setState(() {
            _carouselIndex = index;
          });
        },
        itemCount: _learningSteps.length,
        itemBuilder: (context, index) {
          final step = _learningSteps[index];
          return AnimatedBuilder(
            animation: _carouselController,
            builder: (context, child) {
              double value = 0.0;
              if (_carouselController.position.haveDimensions) {
                value = index.toDouble() - (_carouselController.page ?? 0);
                value = (value * 0.038).clamp(-1, 1);
              }
              
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(value),
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 16 + (value.abs() * 8), // 动态边距
                    vertical: value.abs() * 4, // 垂直视差
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGray.withOpacity(0.08 + (1 - value.abs()) * 0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryGray.withOpacity(0.2 + (1 - value.abs()) * 0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGray.withOpacity(0.1 * (1 - value.abs())),
                        blurRadius: 20 * (1 - value.abs()),
                        offset: Offset(0, 8 * (1 - value.abs())),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 步骤图标 - 添加视差动效
                      Transform.translate(
                        offset: Offset(0, -value * 8), // 图标反向移动
                        child: Transform.scale(
                          scale: 1.0 - (value.abs() * 0.1), // 缩放效果
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGray.withOpacity(0.15 + (1 - value.abs()) * 0.05),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGray.withOpacity(0.2 * (1 - value.abs())),
                                  blurRadius: 12 * (1 - value.abs()),
                                  offset: Offset(0, 4 * (1 - value.abs())),
                                ),
                              ],
                            ),
                            child: Icon(
                              step.icon,
                              size: 36,
                              color: AppTheme.primaryGray.withOpacity(0.8 + (1 - value.abs()) * 0.2),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 18 - (value.abs() * 4)), // 动态间距
                      
                      // 步骤编号 - 添加浮动效果
                      Transform.translate(
                        offset: Offset(0, value * 4), // 编号正向移动
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGray.withOpacity(0.9 + (1 - value.abs()) * 0.1),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGray.withOpacity(0.3 * (1 - value.abs())),
                                blurRadius: 8 * (1 - value.abs()),
                                offset: Offset(0, 2 * (1 - value.abs())),
                              ),
                            ],
                          ),
                          child: Text(
                            '第 ${index + 1} 步',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9 + (1 - value.abs()) * 0.1),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16 - (value.abs() * 2)), // 动态间距
                      
                      // 步骤标题 - 添加淡入淡出效果
                      Transform.translate(
                        offset: Offset(0, value * 6), // 标题移动
                        child: Opacity(
                          opacity: 1.0 - (value.abs() * 0.3), // 透明度变化
                          child: Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 19 - (value.abs() * 1), // 动态字体大小
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGray.withOpacity(0.9 + (1 - value.abs()) * 0.1),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 8 - (value.abs() * 2)), // 动态间距
                      
                      // 步骤描述 - 添加优雅的浮动效果
                      Transform.translate(
                        offset: Offset(0, value * 10), // 描述文字移动更多
                        child: Opacity(
                          opacity: 1.0 - (value.abs() * 0.4), // 更明显的透明度变化
                          child: Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14 - (value.abs() * 0.5), // 动态字体大小
                              color: AppTheme.coolGray600.withOpacity(0.8 + (1 - value.abs()) * 0.2),
                              height: 1.4,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  /// 构建Token输入图标 - 不使用动画
  Widget _buildTokenInputIcon(OnboardingPageData page) {
    var controllerlink = IconController.assets('assets/icon/wired-outline-11-link-unlink-hover-bounce.json');

    controllerlink.addStatusListener((status) {
      if (status == ControllerStatus.ready) {
        controllerlink.playFromBeginning();
      }
    });

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // API连接图标
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryGray.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGray.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconViewer(
              controller: controllerlink,
              width: 40,
              height: 40,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Token输入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'DeepSeek API Key',
                hintText: '请输入您的DeepSeek API Key',
                labelStyle: TextStyle(color: AppTheme.primaryGray),
                hintStyle: TextStyle(color: AppTheme.coolGray500),
                prefixIcon: Icon(Icons.key_outlined, color: AppTheme.primaryGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.coolGray300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGray, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.coolGray300),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.paste,
                        color: AppTheme.primaryGray.withOpacity(0.6),
                      ),
                      onPressed: _pasteToken,
                      tooltip: '粘贴API Key',
                    ),
                    IconButton(
                      icon: Icon(
                        _showToken ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.primaryGray.withOpacity(0.6),
                      ),
                      onPressed: () {
                        setState(() {
                          _showToken = !_showToken;
                        });
                      },
                      tooltip: _showToken ? '隐藏API Key' : '显示API Key',
                    ),
                  ],
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getPrimaryTextColor(context),
              ),
              obscureText: !_showToken,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 帮助文本
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '在DeepSeek官网申请API Key：\nplatform.deepseek.com \n → API Keys \n → 创建新Key',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.getSecondaryTextColor(context),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建文字区域 - 使用逐字浮现动画
  Widget _buildTextSection(OnboardingPageData page, int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 标题 - 逐字浮现动画
        AnimatedTextHelper.buildAnimatedText(
          text: page.title,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 26),
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryGray,
            height: 1.2,
          ),
          animationController: _textAnimationControllers[index],
          animationDelay: Duration.zero,
          characterDelay: const Duration(milliseconds: 80),
          animationDistance: ResponsiveHelper.getResponsiveSpacing(context, 25.0),
        ),
        
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 10)),
        
        // 副标题 - 逐字浮现动画
        AnimatedTextHelper.buildAnimatedText(
          text: page.subtitle,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: AppTheme.coolGray700,
          ),
          animationController: _textAnimationControllers[index],
          animationDelay: const Duration(milliseconds: 800),
          characterDelay: const Duration(milliseconds: 60),
          animationDistance: ResponsiveHelper.getResponsiveSpacing(context, 20.0),
        ),
        
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 14)),
        
        // 描述 - 逐字浮现动画，只有前两页显示，保持高度一致
        if (index != 2)
          AnimatedTextHelper.buildAnimatedText(
            text: page.description,
            style: TextStyle(
              fontSize: 14, // 从16减少到14
              color: AppTheme.coolGray600,
              height: 1.4, // 从1.5减少到1.4
            ),
            animationController: _textAnimationControllers[index],
            animationDelay: const Duration(milliseconds: 1400),
            characterDelay: const Duration(milliseconds: 40),
            animationDistance: 18.0, // 从20减少到18
          )
        else
          // 第三页用占位符保持高度一致
          SizedBox(
            height: 40, // 从48减少到40
          ),
      ],
    );
  }
  
  /// 构建底部按钮
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20), // 从24减少到20
      child: Row(
        children: [
          // 左侧按钮 - 只在最后一页显示
          if (_currentPage == _pages.length - 1)
            SizedBox(
              width: 110, // 从120减少到110
              child: TextButton(
                onPressed: _skipApiKey,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14), // 从16减少到14
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // 从12减少到10
                  ),
                ),
                child: Text(
                  '以后再说',
                  style: TextStyle(
                    fontSize: 14, // 从16减少到14
                    color: AppTheme.coolGray600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            // 前两页用占位符保持布局一致
            const Expanded(child: SizedBox()),
          
          // 中间间距 - 让按钮分开
          const Spacer(),
          
          // 右侧按钮 - 固定宽度，保持一致性
          SizedBox(
            width: 110, // 从120减少到110
            child: ElevatedButton(
              onPressed: _getButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getButtonColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14), // 从16减少到14
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // 从12减少到10
                ),
                elevation: _getButtonElevation(),
                shadowColor: _getButtonColor().withOpacity(0.4),
              ),
              child: Text(
                _getButtonText(),
                style: const TextStyle(
                  fontSize: 14, // 从16减少到14
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 获取按钮操作
  VoidCallback? _getButtonAction() {
    if (_currentPage < _pages.length - 1) {
      return _nextPage;
    } else {
      return _isTokenValid ? _completeOnboarding : null;
    }
  }
  
  /// 获取按钮颜色
  Color _getButtonColor() {
    if (_currentPage == _pages.length - 1 && !_isTokenValid) {
      return AppTheme.coolGray400;
    }
    return AppTheme.primaryGray;
  }
  
  /// 获取按钮阴影
  double _getButtonElevation() {
    if (_currentPage == _pages.length - 1 && !_isTokenValid) {
      return 0;
    }
    return 8;
  }
  
  /// 获取按钮文字
  String _getButtonText() {
    if (_currentPage < _pages.length - 1) {
      return '下一步';
    } else {
      return '开始学习';
    }
  }
  
  /// 页面变化回调 - 修复动画控制器问题
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    
    // 停止所有动画控制器
    for (final controller in _textAnimationControllers) {
      if (controller.isAnimating) {
        controller.stop();
      }
      controller.reset();
    }
    
    // 启动当前页面的动画
    _textAnimationControllers[page].forward();
  }
  
  /// 下一页
  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }
  
  /// 粘贴Token
  void _pasteToken() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        setState(() {
          _tokenController.text = data.text!;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ API Key已粘贴'),
            backgroundColor: AppTheme.primaryGray,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ 剪贴板为空'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 粘贴失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 跳过API Key输入
  void _skipApiKey() async {
    await _completeOnboarding(skipToken: true);
  }
  
  /// 完成引导
  Future<void> _completeOnboarding({bool skipToken = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    // 保存DeepSeek API Key（如果有）
    if (!skipToken && _isTokenValid) {
      await DeepSeekApiService.setApiKey(_tokenController.text.trim());
    }
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}

/// 引导页数据模型
class OnboardingPageData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// 学习步骤数据模型
class LearningStepData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const LearningStepData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}