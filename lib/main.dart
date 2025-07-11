import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'utils/app_theme.dart';
import 'pages/library_page.dart';

void main() {
  runApp(const WordFlowApp());
}

/// WordFlow应用的主入口类
/// 负责应用的整体配置、主题设置和初始路由判断
class WordFlowApp extends StatelessWidget {
  const WordFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordFlow',
      // 使用自定义的简约主题，配色基于提供的图片风格
      theme: AppTheme.lightTheme,
      // 初始页面通过FutureBuilder动态决定
      home: const AppInitializer(),
      // 定义应用的路由配置
      routes: {
        '/onboarding': (context) => const OnboardingPage(),
        '/home': (context) => const HomePage(),
        '/library': (context) => const LibraryPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
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
