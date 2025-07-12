import 'package:flutter/material.dart';

/// 响应式布局工具类
/// 根据屏幕尺寸判断设备类型并提供相应的布局配置
class ResponsiveHelper {
  // 断点定义
  static const double _mobileBreakpoint = 600;
  static const double _tabletBreakpoint = 1200;
  static const double _desktopBreakpoint = 1920;

  /// 判断是否为手机设备
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < _mobileBreakpoint;
  }

  /// 判断是否为平板设备
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= _mobileBreakpoint && width < _tabletBreakpoint;
  }

  /// 判断是否为桌面设备
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= _tabletBreakpoint;
  }

  /// 获取设备类型
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < _mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (width < _tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// 获取响应式值
  static T getResponsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// 获取响应式padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
    );
  }

  /// 获取响应式容器宽度
  static double getResponsiveWidth(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: double.infinity,
      tablet: 600,
      desktop: 800,
    );
  }

  /// 获取响应式字体大小
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    return getResponsiveValue(
      context,
      mobile: baseSize,
      tablet: baseSize * 1.1,
      desktop: baseSize * 1.2,
    );
  }

  /// 获取响应式图标大小
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    return getResponsiveValue(
      context,
      mobile: baseSize,
      tablet: baseSize * 1.15,
      desktop: baseSize * 1.3,
    );
  }

  /// 获取响应式卡片边距
  static EdgeInsets getResponsiveCardMargin(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tablet: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      desktop: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    );
  }

  /// 获取响应式卡片内边距
  static EdgeInsets getResponsiveCardPadding(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(20),
      desktop: const EdgeInsets.all(24),
    );
  }

  /// 获取响应式列数（用于网格布局）
  static int getResponsiveGridColumns(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }

  /// 获取响应式网格交叉轴间距
  static double getResponsiveGridCrossAxisSpacing(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 12,
      tablet: 16,
      desktop: 20,
    );
  }

  /// 获取响应式网格主轴间距
  static double getResponsiveGridMainAxisSpacing(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 12,
      tablet: 16,
      desktop: 20,
    );
  }

  /// 获取响应式AppBar高度
  static double getResponsiveAppBarHeight(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: kToolbarHeight,
      tablet: kToolbarHeight + 8,
      desktop: kToolbarHeight + 16,
    );
  }

  /// 获取响应式按钮高度
  static double getResponsiveButtonHeight(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 42,
      tablet: 48,
      desktop: 52,
    );
  }

  /// 获取响应式按钮内边距
  static EdgeInsets getResponsiveButtonPadding(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tablet: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      desktop: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    );
  }

  /// 获取响应式圆角半径
  static double getResponsiveBorderRadius(BuildContext context, double baseRadius) {
    return getResponsiveValue(
      context,
      mobile: baseRadius,
      tablet: baseRadius * 1.2,
      desktop: baseRadius * 1.4,
    );
  }

  /// 获取响应式间距
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    return getResponsiveValue(
      context,
      mobile: baseSpacing,
      tablet: baseSpacing * 1.25,
      desktop: baseSpacing * 1.5,
    );
  }

  /// 获取响应式最大内容宽度
  static double getMaxContentWidth(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: double.infinity,
      tablet: 800,
      desktop: 1000,
    );
  }

  /// 为平板/桌面设备提供侧边栏布局
  static bool shouldUseSideNavigation(BuildContext context) {
    return isTablet(context) || isDesktop(context);
  }

  /// 获取响应式侧边栏宽度
  static double getSideNavigationWidth(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 0,
      tablet: 280,
      desktop: 300,
    );
  }
}

/// 设备类型枚举
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// 响应式构建器组件
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    return builder(context, deviceType);
  }
} 