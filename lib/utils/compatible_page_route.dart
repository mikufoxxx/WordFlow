import 'package:flutter/material.dart';

/// 兼容性优化的页面路由
/// 使用软件渲染友好的动画，避免GPU兼容性问题
class CompatiblePageRoute<T> extends PageRouteBuilder<T> {
  final Widget? child;
  final WidgetBuilder? builder;
  final String routeName;
  final PageTransitionType transitionType;

  CompatiblePageRoute({
    this.child,
    this.builder,
    required this.routeName,
    this.transitionType = PageTransitionType.fade,
    RouteSettings? settings,
  }) : assert(child != null || builder != null, 'Either child or builder must be provided'),
        super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => 
              child ?? builder!(context),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(
              context,
              animation,
              secondaryAnimation,
              child,
              transitionType,
            );
          },
        );

  /// 构建页面转场动画
  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
    PageTransitionType type,
  ) {
    switch (type) {
      case PageTransitionType.fade:
        return _buildFadeTransition(animation, child);
      case PageTransitionType.slide:
        return _buildSlideTransition(animation, child);
      case PageTransitionType.scale:
        return _buildScaleTransition(animation, child);
      case PageTransitionType.slideFromBottom:
        return _buildSlideFromBottomTransition(animation, child);
      case PageTransitionType.none:
        return child;
    }
  }

  /// 淡入淡出动画 - 最兼容的动画
  static Widget _buildFadeTransition(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: child,
    );
  }

  /// 滑动动画 - 从右侧滑入
  static Widget _buildSlideTransition(Animation<double> animation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    );
  }

  /// 缩放动画
  static Widget _buildScaleTransition(Animation<double> animation, Widget child) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  /// 从底部滑入动画
  static Widget _buildSlideFromBottomTransition(Animation<double> animation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    );
  }
}

/// 页面转场动画类型
enum PageTransitionType {
  /// 淡入淡出 - 最兼容
  fade,
  /// 滑动 - 从右侧滑入
  slide,
  /// 缩放 - 带淡入效果
  scale,
  /// 从底部滑入
  slideFromBottom,
  /// 无动画
  none,
}

/// 兼容性导航助手
class CompatibleNavigator {
  /// 推送新页面 - 使用兼容性动画
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget page, {
    String? routeName,
    PageTransitionType transitionType = PageTransitionType.fade,
  }) {
    return Navigator.push<T>(
      context,
      CompatiblePageRoute<T>(
        child: page,
        routeName: routeName ?? page.runtimeType.toString(),
        transitionType: transitionType,
      ),
    );
  }

  /// 替换当前页面
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    String? routeName,
    PageTransitionType transitionType = PageTransitionType.fade,
    TO? result,
  }) {
    return Navigator.pushReplacement<T, TO>(
      context,
      CompatiblePageRoute<T>(
        child: page,
        routeName: routeName ?? page.runtimeType.toString(),
        transitionType: transitionType,
      ),
      result: result,
    );
  }

  /// 推送并清除所有历史页面
  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    Widget page,
    RoutePredicate predicate, {
    String? routeName,
    PageTransitionType transitionType = PageTransitionType.fade,
  }) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      CompatiblePageRoute<T>(
        child: page,
        routeName: routeName ?? page.runtimeType.toString(),
        transitionType: transitionType,
      ),
      predicate,
    );
  }

  /// 兼容性命名路由推送
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    PageTransitionType transitionType = PageTransitionType.fade,
  }) async {
    try {
      // 直接使用系统默认路由，但包装在兼容性动画中
      // 这样可以避免复杂的路由解析，同时保持动画兼容性
      
      // 创建一个延迟构建的页面
      final route = CompatiblePageRoute<T>(
        builder: (context) {
          // 在这里触发系统路由构建
          final navigator = Navigator.of(context);
          final settings = RouteSettings(name: routeName, arguments: arguments);
          
          // 尝试获取路由表中的页面
          try {
            final app = context.findAncestorWidgetOfExactType<MaterialApp>();
            if (app?.routes != null && app!.routes!.containsKey(routeName)) {
              final builder = app.routes![routeName]!;
              return builder(context);
            }
            
            // 如果没有找到，返回错误页面
            return _createErrorPage('页面未找到: $routeName');
          } catch (e) {
            return _createErrorPage('页面加载失败: $e');
          }
        },
        routeName: routeName,
        transitionType: transitionType,
        settings: RouteSettings(name: routeName, arguments: arguments),
      );
      
      return Navigator.push<T>(context, route);
    } catch (e) {
      // 出错时使用系统默认路由
      return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
    }
  }

  /// 根据路由名称获取页面 - 返回null让系统使用默认路由
  static Widget? _getRouteByName(BuildContext context, String routeName, Object? arguments) {
    // 返回null，让系统使用默认的路由表
    // 这样可以避免循环依赖问题，同时保持兼容性动画
    return null;
  }

  /// 创建错误页面
  static Widget _createErrorPage(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('错误')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(null as BuildContext).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}