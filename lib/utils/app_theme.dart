import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// 应用主题配置类
/// 性冷淡风格的简约灰白色调主题
class AppTheme {
  // 主要颜色定义
  static const Color primaryGray = Color(0xFF6B7280);
  static const Color lightGray = Color(0xFFF9FAFB);
  static const Color mediumGray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF374151);
  static const Color backgroundColor = Color(0xFFFBFCFD);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color accentGreen = Color(0xFF10B981);
  
  // 性冷淡风格的辅助颜色
  static const Color coolGray50 = Color(0xFFF8FAFC);
  static const Color coolGray100 = Color(0xFFF1F5F9);
  static const Color coolGray200 = Color(0xFFE2E8F0);
  static const Color coolGray300 = Color(0xFFCBD5E1);
  static const Color coolGray400 = Color(0xFF94A3B8);
  static const Color coolGray500 = Color(0xFF64748B);
  static const Color coolGray600 = Color(0xFF475569);
  static const Color coolGray700 = Color(0xFF334155);
  static const Color coolGray800 = Color(0xFF1E293B);
  static const Color coolGray900 = Color(0xFF0F172A);

  /// 浅色主题配置
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primarySwatch: Colors.blueGrey,
      primaryColor: primaryGray,
      scaffoldBackgroundColor: backgroundColor,
      
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0.5, // 减少阴影
        shadowColor: Colors.black.withOpacity(0.04), // 减少阴影透明度
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)), // 减少圆角
        ),
      ),
      
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24, // 从32减少到24
          fontWeight: FontWeight.w700,
          color: coolGray800,
          letterSpacing: 0.3, // 减少字间距
        ),
        headlineMedium: TextStyle(
          fontSize: 20, // 从24减少到20
          fontWeight: FontWeight.w600,
          color: coolGray700,
          letterSpacing: 0.2, // 减少字间距
        ),
        titleLarge: TextStyle(
          fontSize: 18, // 从20减少到18
          fontWeight: FontWeight.w500,
          color: coolGray600,
        ),
        bodyLarge: TextStyle(
          fontSize: 14, // 从16减少到14
          color: coolGray700,
          height: 1.4, // 减少行高
        ),
        bodyMedium: TextStyle(
          fontSize: 13, // 从14减少到13
          color: coolGray500,
          height: 1.3, // 减少行高
        ),
        labelLarge: TextStyle(
          fontSize: 11, // 从12减少到11
          color: coolGray400,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: coolGray600,
          foregroundColor: Colors.white,
          elevation: 0.5, // 减少阴影
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 减少padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // 减少圆角
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: coolGray50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 减少内边距
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // 减少圆角
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // 减少圆角
          borderSide: BorderSide(color: coolGray300, width: 1),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: coolGray700,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 16, // 从18减少到16
          fontWeight: FontWeight.w600,
          color: coolGray700,
        ),
      ),
      
      // 添加ListTile主题，减少列表项高度
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // 减少内边距
        minVerticalPadding: 4, // 减少最小垂直间距
        dense: true, // 启用紧凑模式
      ),
      
      // 添加Icon主题，减少图标大小
      iconTheme: IconThemeData(
        size: 20, // 减少默认图标大小
        color: coolGray500,
      ),
      
      // 添加Chip主题
      chipTheme: ChipThemeData(
        backgroundColor: coolGray100,
        labelStyle: TextStyle(
          fontSize: 12,
          color: coolGray700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}