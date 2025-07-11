import 'package:flutter/material.dart';

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
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.06), // 修复：不能在const中使用withOpacity
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: coolGray800,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: coolGray700,
          letterSpacing: 0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: coolGray600,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: coolGray700,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: coolGray500,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          color: coolGray400,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: coolGray600,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: coolGray50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: coolGray300, width: 1),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: coolGray700,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: coolGray700,
        ),
      ),
    );
  }
}