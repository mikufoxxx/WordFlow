// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lordicon/lordicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/animated_text_helper.dart';
import '../utils/render_compatibility_helper.dart';
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

  // API Key 输入相关
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
      subtitle: "可先填写 API Key，完整接口可在设置中配置",
      description: "支持 OpenAI 兼容 / Responses / Claude\n也可跳过后在设置页完成配置",
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
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      // 增加轮播间隔
      if (_currentPage == 1) {
        // 只在第二页时自动轮播
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
        duration: const Duration(milliseconds: 800), // 增加动画时长
        curve: Curves.easeInOutQuart, // 使用更柔和的贝塞尔曲线
      );
    }
  }

  /// API Key 输入变化监听
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
                        physics: const ClampingScrollPhysics(),
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
      padding: EdgeInsets.symmetric(
          vertical: ResponsiveHelper.getResponsiveSpacing(context, 16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getResponsiveSpacing(context, 4)),
            width: _currentPage == index
                ? ResponsiveHelper.getResponsiveSpacing(context, 20)
                : ResponsiveHelper.getResponsiveSpacing(context, 8),
            height: ResponsiveHelper.getResponsiveSpacing(context, 6),
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? AppTheme.primaryGray
                  : AppTheme.coolGray300,
              borderRadius: BorderRadius.circular(
                  ResponsiveHelper.getResponsiveBorderRadius(context, 3)),
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
    var controller = IconController.assets(
        'assets/icon/wired-outline-112-book-hover-pinch.json');

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
      height: 280, // 进一步增加高度以容纳更丰富的视差效果
      child: PageView.builder(
        controller: _carouselController,
        onPageChanged: (index) {
          setState(() {
            _carouselIndex = index;
          });
        },
        itemCount: _learningSteps.length,
        physics: const BouncingScrollPhysics(), // 添加弹性滚动效果
        itemBuilder: (context, index) {
          final step = _learningSteps[index];
          return AnimatedBuilder(
            animation: _carouselController,
            builder: (context, child) {
              double value = 0.0;
              double normalizedValue = 0.0;
              if (_carouselController.position.haveDimensions) {
                value = index.toDouble() - (_carouselController.page ?? 0);
                normalizedValue = value.clamp(-1.0, 1.0);
                value = (value * 0.7).clamp(-1, 1); // 进一步增强3D效果
              }

              // 计算多层视差参数
              final absValue = normalizedValue.abs();
              final parallaxIntensity = (1 - absValue).clamp(0.0, 1.0);
              final scaleEffect = 0.85 + (parallaxIntensity * 0.15);
              final rotationEffect = normalizedValue * 0.25; // 进一步增强旋转效果

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0008) // 增强透视效果
                  ..rotateY(rotationEffect)
                  ..rotateX(normalizedValue * 0.08) // 增强X轴旋转效果
                  ..scale(scaleEffect),
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 12 + (absValue * 12), // 更动态的边距
                    vertical: absValue * 6, // 增强垂直视差
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGray
                        .withOpacity(0.06 + (parallaxIntensity * 0.04)),
                    borderRadius:
                        BorderRadius.circular(24 - (absValue * 4)), // 动态圆角
                    border: Border.all(
                      color: AppTheme.primaryGray
                          .withOpacity(0.15 + (parallaxIntensity * 0.15)),
                      width: 1.0 + (parallaxIntensity * 0.8), // 动态边框宽度
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGray
                            .withOpacity(0.08 * parallaxIntensity),
                        blurRadius: 24 * parallaxIntensity,
                        offset: Offset(normalizedValue * 4,
                            10 * parallaxIntensity), // 动态阴影偏移
                      ),
                      // 添加第二层阴影增强深度
                      BoxShadow(
                        color: AppTheme.primaryGray
                            .withOpacity(0.04 * parallaxIntensity),
                        blurRadius: 40 * parallaxIntensity,
                        offset:
                            Offset(normalizedValue * 8, 20 * parallaxIntensity),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 步骤图标 - 超强视差动效
                      Transform.translate(
                        offset: Offset(
                          normalizedValue * -20, // 增强水平视差移动
                          normalizedValue * -25, // 增强垂直反向移动
                        ),
                        child: Transform.scale(
                          scale: 0.85 + (parallaxIntensity * 0.3), // 更明显的缩放效果
                          child: Transform.rotate(
                            angle: normalizedValue * 0.2, // 增强旋转效果
                            child: Container(
                              width: 70 + (parallaxIntensity * 10), // 稍微缩小的尺寸
                              height: 70 + (parallaxIntensity * 10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGray.withOpacity(
                                    0.1 + (parallaxIntensity * 0.12)),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGray
                                        .withOpacity(0.2 * parallaxIntensity),
                                    blurRadius: 20 * parallaxIntensity,
                                    offset: Offset(normalizedValue * 5,
                                        8 * parallaxIntensity),
                                  ),
                                  // 增强内阴影效果
                                  BoxShadow(
                                    color: Colors.white
                                        .withOpacity(0.15 * parallaxIntensity),
                                    blurRadius: 12 * parallaxIntensity,
                                    offset: Offset(-normalizedValue * 3,
                                        -4 * parallaxIntensity),
                                  ),
                                ],
                              ),
                              child: Icon(
                                step.icon,
                                size: 35 + (parallaxIntensity * 5), // 稍微缩小的图标大小
                                color: AppTheme.primaryGray.withOpacity(
                                    0.7 + (parallaxIntensity * 0.3)),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20 - (absValue * 6)), // 更动态的间距

                      // 步骤编号 - 超强浮动效果
                      Transform.translate(
                        offset: Offset(
                          normalizedValue * 15, // 增强水平浮动
                          normalizedValue * 12, // 增强垂直浮动
                        ),
                        child: Transform.scale(
                          scale: 0.9 + (parallaxIntensity * 0.2), // 更明显的缩放效果
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16 + (parallaxIntensity * 4),
                              vertical: 8 + (parallaxIntensity * 2),
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGray.withOpacity(
                                  0.88 + (parallaxIntensity * 0.12)),
                              borderRadius:
                                  BorderRadius.circular(22 - (absValue * 3)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGray
                                      .withOpacity(0.35 * parallaxIntensity),
                                  blurRadius: 16 * parallaxIntensity,
                                  offset: Offset(normalizedValue * 4,
                                      6 * parallaxIntensity),
                                ),
                                // 增强高光效果
                                BoxShadow(
                                  color: Colors.white
                                      .withOpacity(0.3 * parallaxIntensity),
                                  blurRadius: 8 * parallaxIntensity,
                                  offset: Offset(-normalizedValue * 2,
                                      -3 * parallaxIntensity),
                                ),
                              ],
                            ),
                            child:
                                RenderCompatibilityHelper.createCompatibleText(
                              '第 ${index + 1} 步',
                              style: TextStyle(
                                color: Colors.white.withOpacity(
                                    0.9 + (parallaxIntensity * 0.1)),
                                fontSize:
                                    12 + (parallaxIntensity * 1.5), // 稍微缩小的字体大小
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8 + (parallaxIntensity * 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 16 - (absValue * 4)), // 更动态的间距

                      // 步骤标题 - 超强移动效果
                      Transform.translate(
                        offset: Offset(
                          normalizedValue * 15, // 增强水平移动
                          normalizedValue * 12, // 增强垂直移动
                        ),
                        child: Transform.scale(
                          scale: 0.9 + (parallaxIntensity * 0.2), // 更明显的缩放效果
                          child: Opacity(
                            opacity:
                                0.6 + (parallaxIntensity * 0.4), // 更强的透明度变化
                            child:
                                RenderCompatibilityHelper.createCompatibleText(
                              step.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize:
                                    17 + (parallaxIntensity * 2.5), // 稍微缩小的字体大小
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryGray.withOpacity(
                                    0.8 + (parallaxIntensity * 0.2)),
                                letterSpacing: 0.8 + (parallaxIntensity * 0.5),
                                shadows: [
                                  Shadow(
                                    color: AppTheme.primaryGray
                                        .withOpacity(0.15 * parallaxIntensity),
                                    offset: Offset(normalizedValue * 2,
                                        2 * parallaxIntensity),
                                    blurRadius: 4 * parallaxIntensity,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 10 - (absValue * 3)), // 更动态的间距

                      // 步骤描述 - 超强浮动效果
                      Transform.translate(
                        offset: Offset(
                          normalizedValue * 20, // 进一步增强水平移动
                          normalizedValue * 16, // 进一步增强垂直移动
                        ),
                        child: Transform.scale(
                          scale: 0.88 + (parallaxIntensity * 0.24), // 更强的缩放效果
                          child: Opacity(
                            opacity:
                                0.5 + (parallaxIntensity * 0.5), // 最强的透明度变化
                            child:
                                RenderCompatibilityHelper.createCompatibleText(
                              step.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize:
                                    13 + (parallaxIntensity * 1.5), // 稍微缩小的字体大小
                                color: AppTheme.coolGray600.withOpacity(
                                    0.6 + (parallaxIntensity * 0.4)),
                                height: 1.2 + (parallaxIntensity * 0.3),
                                letterSpacing: 0.3 + (parallaxIntensity * 0.4),
                                shadows: [
                                  Shadow(
                                    color: AppTheme.coolGray600
                                        .withOpacity(0.08 * parallaxIntensity),
                                    offset: Offset(normalizedValue * 1,
                                        1 * parallaxIntensity),
                                    blurRadius: 2 * parallaxIntensity,
                                  ),
                                ],
                              ),
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

  /// 构建 API Key 输入区域 - 不使用动画
  Widget _buildTokenInputIcon(OnboardingPageData page) {
    var controllerlink = IconController.assets(
        'assets/icon/wired-outline-11-link-unlink-hover-bounce.json');

    controllerlink.addStatusListener((status) {
      if (status == ControllerStatus.ready) {
        controllerlink.playFromBeginning();
      }
    });

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
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

          // API Key 输入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'API Key（可选）',
                hintText: '可先粘贴兼容接口的 API Key，稍后也能在设置中完整配置',
                labelStyle: TextStyle(color: AppTheme.primaryGray),
                hintStyle: TextStyle(color: AppTheme.coolGray500),
                prefixIcon:
                    Icon(Icons.key_outlined, color: AppTheme.primaryGray),
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
            child: RenderCompatibilityHelper.createCompatibleText(
              '当前版本支持 OpenAI 兼容 / Responses / Claude。\n如需完整配置 Base URL、模型与接口模式，请前往设置页。',
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
          animationDistance:
              ResponsiveHelper.getResponsiveSpacing(context, 25.0),
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
          animationDistance:
              ResponsiveHelper.getResponsiveSpacing(context, 20.0),
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
                child: RenderCompatibilityHelper.createCompatibleText(
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
              child: RenderCompatibilityHelper.createCompatibleText(
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

  /// 粘贴 API Key
  void _pasteToken() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        setState(() {
          _tokenController.text = data.text!;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RenderCompatibilityHelper.createCompatibleText(
                    'API Key已粘贴',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.primaryGray,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RenderCompatibilityHelper.createCompatibleText(
                    '剪贴板为空',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.red.shade700
                : Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '粘贴失败: $e',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.red.shade700
              : Colors.red,
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

  /// 跳过 API Key 输入
  void _skipApiKey() async {
    await _completeOnboarding(skipToken: true);
  }

  /// 完成引导
  Future<void> _completeOnboarding({bool skipToken = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    // 兼容旧流程：如果用户在引导页填写了 API Key，则按 DeepSeek 默认配置保存
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
