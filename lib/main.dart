import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/word_review_page.dart';
import 'pages/enhanced_word_review_page.dart';
import 'pages/algorithm_settings_page.dart';
import 'utils/app_theme.dart';
import 'utils/learning_data_service.dart';
import 'utils/settings_helper.dart';
import 'utils/deepseek_api_service.dart';
import 'pages/library_page.dart';
import 'utils/algorithm_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 立即设置默认的系统UI覆盖层（浅色模式）
  AppTheme.setLightSystemUIOverlay();
  
  // 初始化学习数据服务
  await LearningDataService.instance.initialize();
  
  // 检查API Key和学习模式的兼容性
  await _validateLearningModeAndApiKey();
  
  runApp(const WordFlowApp());
}

/// 验证学习模式和API Key的兼容性
Future<void> _validateLearningModeAndApiKey() async {
  try {
    final learningMode = await SettingsHelper.getLearningMode();
    if (learningMode == LearningMode.deepLearning) {
      final apiKey = await DeepSeekApiService.getApiKey();
      final isApiKeyValid = apiKey != null && apiKey.isNotEmpty && apiKey.length >= 10;
      
      if (!isApiKeyValid) {
        // API Key无效，自动切换到快速学习模式
        await SettingsHelper.setLearningMode(LearningMode.quickMemory);
        print('⚠️ API Key无效，已自动切换到快速学习模式');
      }
    }
  } catch (e) {
    print('❌ 验证学习模式失败: $e');
  }
}

/// WordFlow应用的主入口类
/// 负责应用的整体配置、主题设置和初始路由判断
class WordFlowApp extends StatefulWidget {
  const WordFlowApp({super.key});

  @override
  State<WordFlowApp> createState() => _WordFlowAppState();
}

class _WordFlowAppState extends State<WordFlowApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  /// 初始化所有服务
  Future<void> _initServices() async {
    try {
      // 加载主题偏好
      _loadThemePreference();
      
      // 初始化学习数据服务
      await LearningDataService.instance.initialize();
      
      // 初始化算法管理器
      await AlgorithmManager.instance.initialize();
      
      print('✅ 所有服务初始化完成');
    } catch (e) {
      print('❌ 服务初始化失败: $e');
    }
  }

  /// 加载主题偏好设置
  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('enable_dark_mode') ?? false;
    
    setState(() {
      _isDarkMode = isDarkMode;
    });
    
    // 立即设置对应的系统UI覆盖层
    if (isDarkMode) {
      AppTheme.setDarkSystemUIOverlay();
    } else {
      AppTheme.setLightSystemUIOverlay();
    }
  }

  /// 切换主题
  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('enable_dark_mode', _isDarkMode);
    
    // 更新系统UI覆盖层
    if (_isDarkMode) {
      AppTheme.setDarkSystemUIOverlay();
    } else {
      AppTheme.setLightSystemUIOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordFlow',
      // 使用自定义的简约主题，支持深色模式
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // 本地化配置
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文
        Locale('en', 'US'), // 英文
      ],
      locale: const Locale('zh', 'CN'), // 默认使用中文
      // 初始页面通过FutureBuilder动态决定
      home: const AppInitializer(),
      // 定义应用的路由配置
      routes: {
        '/onboarding': (context) => const OnboardingPage(),
        '/home': (context) => const HomePage(),
        '/library': (context) => const LibraryPage(),
        '/settings': (context) => ThemeProvider(
          toggleTheme: _toggleTheme,
          child: const SettingsPage(),
        ),
        '/word_review': (context) => const WordReviewPage(),
        '/enhanced_word_review': (context) => const EnhancedWordReviewPage(),
        '/algorithm_settings': (context) => const AlgorithmSettingsPage(),
      },
    );
  }
}

/// 主题提供者，用于向设置页面传递主题切换函数
class ThemeProvider extends InheritedWidget {
  final VoidCallback toggleTheme;

  const ThemeProvider({
    super.key,
    required this.toggleTheme,
    required Widget child,
  }) : super(child: child);

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return toggleTheme != oldWidget.toggleTheme;
  }
}

/// 应用初始化器
/// 检查用户是否已完成起始页配置，决定显示哪个页面
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      // 检查用户是否已完成初始设置
      future: _checkOnboardingStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 加载中显示简约的启动画面
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F5),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF666666),
              ),
            ),
          );
        }
        
        // 根据是否完成初始设置决定显示的页面
        if (snapshot.data == true) {
          return const HomePage();
        } else {
          return const OnboardingPage();
        }
      },
    );
  }

  /// 检查用户是否已完成起始页配置
  /// 返回true表示已完成，false表示需要显示起始页
  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }
}
