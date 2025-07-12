import 'package:flutter/material.dart';
import 'package:lordicon/lordicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/animated_text_helper.dart';
import '../utils/responsive_helper.dart';
import 'dart:async'; // Added for Timer

/// 起始页面 - 重新设计的引导流程
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> 
    with TickerProviderStateMixin {
  
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Token输入相关
  final TextEditingController _tokenController = TextEditingController();
  bool _isTokenValid = false;
  
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
      subtitle: "连接墨墨背单词",
      description: "输入墨墨背单词的API Token\n同步您的学习进度",
      icon: Icons.link_outlined,
      color: Color(0xFF10B981), // 更柔和的绿色
    ),
  ];
  
  // 学习流程数据 - 使用更柔和的颜色
  final List<LearningStepData> _learningSteps = [
    LearningStepData(
      title: "单词浮现",
      description: "优雅的流式动画\n逐字浮现单词",
      icon: Icons.visibility_outlined,
      color: Color(0xFF6B7280), // 柔和灰色
    ),
    LearningStepData(
      title: "思考记忆",
      description: "点击屏幕查看释义\n加深记忆印象",
      icon: Icons.psychology_outlined,
      color: Color(0xFF8B5CF6), // 柔和紫色
    ),
    LearningStepData(
      title: "确认掌握",
      description: "标记认识程度\n智能调整复习频率",
      icon: Icons.done_all_outlined,
      color: Color(0xFF10B981), // 柔和绿色
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
          backgroundColor: AppTheme.backgroundColor,
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
                  ? _pages[index].color 
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
      width: 120, // 从150减少到120
      height: 120, // 从150减少到120
      decoration: BoxDecoration(
        color: page.color.withOpacity(0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: page.color.withOpacity(0.15), // 从0.2减少到0.15
            blurRadius: 15, // 从20减少到15
            offset: const Offset(0, 8), // 从10减少到8
          ),
        ],
      ),
      child: IconViewer(
        controller: controller,
        width: 80, // 从100减少到80
        height: 80, // 从100减少到80
      ),
    );
  }
  
  /// 构建学习流程轮播图 - 不使用动画
  Widget _buildLearningCarousel() {
    return Container(
      height: 240, // 从280减少到240
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
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16), // 从20减少到16
            decoration: BoxDecoration(
              color: step.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20), // 从24减少到20
              border: Border.all(
                color: step.color.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 步骤图标
                Container(
                  width: 68, // 从80减少到68
                  height: 68, // 从80减少到68
                  decoration: BoxDecoration(
                    color: step.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.icon,
                    size: 32, // 从40减少到32
                    color: step.color,
                  ),
                ),
                
                const SizedBox(height: 16), // 从20减少到16
                
                // 步骤编号
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // 从12,6减少到10,5
                  decoration: BoxDecoration(
                    color: step.color,
                    borderRadius: BorderRadius.circular(16), // 从20减少到16
                  ),
                  child: Text(
                    '第 ${index + 1} 步',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11, // 从12减少到11
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                const SizedBox(height: 14), // 从16减少到14
                
                // 步骤标题
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 18, // 从20减少到18
                    fontWeight: FontWeight.w700,
                    color: step.color,
                  ),
                ),
                
                const SizedBox(height: 6), // 从8减少到6
                
                // 步骤描述
                Text(
                  step.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13, // 从14减少到13
                    color: AppTheme.coolGray600,
                    height: 1.3, // 从1.4减少到1.3
                  ),
                ),
              ],
            ),
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // API连接图标
        Container(
          width: 100, // 从120减少到100
          height: 100, // 从120减少到100
          decoration: BoxDecoration(
            color: page.color.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: page.color.withOpacity(0.15), // 从0.2减少到0.15
                blurRadius: 15, // 从20减少到15
                offset: const Offset(0, 8), // 从10减少到8
              ),
            ],
          ),
          child: IconViewer(
            controller: controllerlink,
            width: 50, // 从60减少到50
            height: 50, // 从60减少到50
          ),
        ),
        
        const SizedBox(height: 32), // 从40减少到32
        
        // Token输入框
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16), // 从20减少到16
          child: TextField(
            controller: _tokenController,
            decoration: InputDecoration(
              labelText: '墨墨背单词 API Token',
              hintText: '请输入您的API Token',
              prefixIcon: Icon(Icons.key_outlined, color: page.color),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), // 从16减少到12
                borderSide: BorderSide(color: AppTheme.coolGray300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), // 从16减少到12
                borderSide: BorderSide(color: page.color, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), // 从16减少到12
                borderSide: BorderSide(color: AppTheme.coolGray300),
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
            style: const TextStyle(fontSize: 14), // 从16减少到14
          ),
        ),
        
        const SizedBox(height: 14), // 从16减少到14
        
        // 帮助文本
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // 从20减少到16
          child: Text(
            '在墨墨背单词 APP 中：\n我的 → 更多设置 → 实验功能 → 开放API',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12, // 从13减少到12
              color: AppTheme.coolGray500,
              height: 1.3, // 从1.4减少到1.3
            ),
          ),
        ),
      ],
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
            color: page.color,
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
                onPressed: _skipToken,
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
    return _pages[_currentPage].color;
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
  
  /// 跳过Token输入
  void _skipToken() async {
    await _completeOnboarding(skipToken: true);
  }
  
  /// 完成引导
  Future<void> _completeOnboarding({bool skipToken = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    // 保存Token（如果有）
    if (!skipToken && _isTokenValid) {
      await prefs.setString('maimemo_token', _tokenController.text.trim());
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