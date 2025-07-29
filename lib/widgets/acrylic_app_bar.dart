// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/app_theme.dart';
import '../utils/performance_optimizer.dart';

/// 亚克力风格的AppBar
/// 具有毛玻璃模糊效果，适配浅色和深色主题
class AcrylicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final Color? backgroundColor;
  final Color? foregroundColor;
  
  const AcrylicAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.elevation,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 根据主题选择背景色
    final bgColor = backgroundColor ?? 
        (isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor);
    final fgColor = foregroundColor ?? 
        (isDark ? AppTheme.coolGray200 : AppTheme.coolGray700);
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 更强的毛玻璃模糊效果
        child: Container(
          decoration: BoxDecoration(
            // 多层次透明背景
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                bgColor.withOpacity(0.9), // 顶部更不透明
                bgColor.withOpacity(0.7), // 底部更透明
              ],
            ),
            // 亚克力边框效果
            border: Border(
              bottom: BorderSide(
                color: (isDark ? AppTheme.darkPrimaryGray : AppTheme.primaryGray)
                    .withOpacity(0.2),
                width: 1.0,
              ),
            ),
            // 微妙的阴影
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppTheme.coolGray400)
                    .withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            title: OptimizedText(title),
            actions: actions,
            leading: leading,
            automaticallyImplyLeading: automaticallyImplyLeading,
            bottom: bottom,
            elevation: elevation ?? 0,
            scrolledUnderElevation: 0, // 禁用滚动时的额外效果
            backgroundColor: Colors.transparent, // 透明背景，让Container的背景生效
            foregroundColor: fgColor,
            centerTitle: true,
            systemOverlayStyle: theme.appBarTheme.systemOverlayStyle,
            titleTextStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0.0)
  );
}