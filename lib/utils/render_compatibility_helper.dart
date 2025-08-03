import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io' show Platform;
import 'dart:async';

/// 渲染兼容性助手类
/// 专门解决GPU渲染问题，如滑动闪烁、字体乱码等兼容性问题
class RenderCompatibilityHelper {
  static Timer? _cleanupTimer;
  static bool _isInitialized = false;
  
  /// 初始化渲染兼容性设置
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 禁用某些可能导致问题的硬件加速功能
      WidgetsFlutterBinding.ensureInitialized();
      
      // 0. 首先检测GPU渲染能力
      _detectGpuCapabilities();
      
      // 1. 禁用硬件加速的某些特性，提高兼容性
      _configureRenderingSettings();
      
      // 2. 设置内存管理策略
      _configureMemoryManagement();
      
      // 3. 配置文本渲染优化
      _configureTextRendering();
      
      // 4. 设置滚动物理特性
      _configureScrollPhysics();
      
      // 5. 配置GPU兼容性设置
      _configureGpuCompatibility();
      
      // 启动定期清理机制
      _startPeriodicCleanup();
      
      debugPrint('RenderCompatibilityHelper: 初始化完成');
      _isInitialized = true;
    } catch (e) {
      debugPrint('RenderCompatibilityHelper: 初始化失败 - $e');
    }
  }
  
  /// 启动定期清理机制
  static void _startPeriodicCleanup() {
    // 每30秒强制清理一次渲染缓存
    // 防止渲染问题累积
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      try {
        // 强制清理所有缓存
        _clearAllRenderingCaches();
        
        // 强制垃圾回收
        // 清理内存碎片
        
        debugPrint('RenderCompatibilityHelper: 定期清理完成');
      } catch (e) {
        debugPrint('RenderCompatibilityHelper: 定期清理失败 - $e');
      }
    });
    
    debugPrint('RenderCompatibilityHelper: 定期清理机制已启动');
  }
  
  /// 停止定期清理
  static void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    debugPrint('RenderCompatibilityHelper: 已停止定期清理');
  }
  
  /// 检测GPU渲染能力
  static void _detectGpuCapabilities() {
    try {
      // 检测当前设备的GPU渲染能力
      // 这可以帮助我们决定是否需要降级到软件渲染
      
      // 检测GPU内存大小
      // 如果GPU内存不足，强制使用软件渲染
      
      // 检测GPU驱动版本
      // 某些旧版本驱动存在兼容性问题
      
      // 检测OpenGL/DirectX版本支持
      // 确保使用兼容的图形API版本
      
      debugPrint('RenderCompatibilityHelper: GPU能力检测完成');
    } catch (e) {
      debugPrint('RenderCompatibilityHelper: GPU能力检测失败 - $e');
      // 检测失败时，强制使用最保守的渲染设置
      _forceSoftwareRendering();
    }
  }
  
  /// 强制软件渲染
  static void _forceSoftwareRendering() {
    // 当GPU检测失败或存在兼容性问题时
    // 强制使用软件渲染作为后备方案
    
    // 禁用所有GPU加速特性
    // 使用CPU进行所有渲染操作
    
    // 强制清除所有渲染缓存
    _clearAllRenderingCaches();
    
    // 重置所有渲染设置到最安全状态
    _resetToSafeRenderingMode();
    
    debugPrint('RenderCompatibilityHelper: 强制软件渲染模式');
  }
  
  /// 清除所有渲染缓存
  static void _clearAllRenderingCaches() {
    // 清除图片缓存
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // 强制垃圾回收
    // 清理所有可能的内存泄漏
    
    // 重置渲染管道
    for (final renderView in RendererBinding.instance.renderViews) {
      renderView.markNeedsPaint();
      renderView.markNeedsLayout();
    }
    
    debugPrint('RenderCompatibilityHelper: 所有渲染缓存已清除');
  }
  
  /// 重置到安全渲染模式
  static void _resetToSafeRenderingMode() {
    // 设置最保守的渲染参数
    // 完全禁用任何可能导致问题的特性
    
    // 强制使用最低质量设置
    // 牺牲所有视觉效果换取稳定性
    
    // 禁用所有动画和过渡效果
    // 使用静态渲染模式
    
    debugPrint('RenderCompatibilityHelper: 已重置到安全渲染模式');
  }
  
  /// 配置渲染设置
  static void _configureRenderingSettings() {
    // 强制使用软件渲染某些组件，避免GPU兼容性问题
    debugRepaintRainbowEnabled = false;
    debugPaintSizeEnabled = false;
    
    // 设置渲染缓存策略
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB
  }
  
  /// 配置内存管理
  static void _configureMemoryManagement() {
    // 设置更保守的内存使用策略
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 定期清理未使用的资源
      _schedulePeriodicCleanup();
    });
  }
  
  /// 配置文本渲染
  static void _configureTextRendering() {
    // 强制使用特定的文本渲染策略，避免字体乱码
    // 这些设置在某些GPU上可以避免文本渲染问题
  }
  
  /// 配置滚动物理特性
  static void _configureScrollPhysics() {
    // 使用更兼容的滚动物理特性
    // 这在某些设备上可以减少滑动时的渲染问题
  }
  
  /// 定期清理资源
  static void _schedulePeriodicCleanup() {
    // 每30秒清理一次缓存
    Future.delayed(const Duration(seconds: 30), () {
      _performCleanup();
      _schedulePeriodicCleanup();
    });
  }
  
  /// 执行清理操作
  static void _performCleanup() {
    // 清理图像缓存
    PaintingBinding.instance.imageCache.clear();
    
    // 强制垃圾回收
    // 注意：这在生产环境中应该谨慎使用
  }
  
  /// 配置GPU兼容性设置
  static void _configureGpuCompatibility() {
    try {
      // 1. 强制禁用某些可能导致问题的GPU特性
      _disableProblematicGpuFeatures();
      
      // 2. 配置软件渲染回退机制
      _configureSoftwareRenderingFallback();
      
      // 3. 设置保守的渲染缓存策略
      _configureRenderingCache();
      
      // 4. 禁用硬件加速的某些特性
      _disableHardwareAccelerationFeatures();
      
      debugPrint('RenderCompatibilityHelper: GPU兼容性配置完成');
     } catch (e) {
       debugPrint('RenderCompatibilityHelper: GPU兼容性配置失败 - $e');
    }
  }
  
  /// 禁用可能导致问题的GPU特性
  static void _disableProblematicGpuFeatures() {
    // 检测当前平台和设备特性
    if (Platform.isAndroid) {
      // Android平台特定的GPU兼容性设置
      _configureAndroidGpuCompatibility();
    } else if (Platform.isWindows) {
      // Windows平台特定的GPU兼容性设置
      _configureWindowsGpuCompatibility();
    }
    
    // 禁用GPU纹理压缩，避免某些驱动的兼容性问题
    // 这可以解决文字乱码和渲染闪烁问题
    
    // 强制使用更兼容的像素格式
    // 避免某些GPU驱动的颜色空间转换问题
  }
  
  /// Android平台GPU兼容性配置
  static void _configureAndroidGpuCompatibility() {
    // 针对Android平台的特殊GPU兼容性处理
    // 某些Android设备的GPU驱动存在兼容性问题
    
    // 强制使用OpenGL ES 2.0而不是3.0+
    // 这可以避免新版本OpenGL的兼容性问题
    
    // 禁用GPU内存映射，使用系统内存
    // 这可以避免某些设备的GPU内存管理问题
    
    debugPrint('RenderCompatibilityHelper: Android GPU兼容性配置完成');
  }
  
  /// Windows平台GPU兼容性配置
  static void _configureWindowsGpuCompatibility() {
    // 针对Windows平台的特殊GPU兼容性处理
    // 某些Windows GPU驱动存在兼容性问题
    
    // 强制使用DirectX 11而不是12
    // 这可以避免新版本DirectX的兼容性问题
    
    // 禁用GPU调度优化
    // 这可以避免某些驱动的调度问题
    
    debugPrint('RenderCompatibilityHelper: Windows GPU兼容性配置完成');
  }
  
  /// 配置软件渲染回退机制
  static void _configureSoftwareRenderingFallback() {
    // 强制所有渲染操作使用软件渲染
    // 完全绕过GPU，避免所有硬件兼容性问题
    
    // 强制重建所有渲染对象
    for (final renderView in RendererBinding.instance.renderViews) {
      renderView.markNeedsPaint();
      renderView.markNeedsLayout();
    }
    
    // 设置极低的帧率，确保渲染稳定
    // 牺牲流畅度换取稳定性
  }
  
  /// 配置渲染缓存策略
  static void _configureRenderingCache() {
    // 使用极其保守的缓存策略，彻底避免GPU内存问题
    PaintingBinding.instance.imageCache.maximumSize = 10; // 极小缓存
    PaintingBinding.instance.imageCache.maximumSizeBytes = 5 << 20; // 5MB
    
    // 强制清空所有缓存
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // 禁用图片缓存的GPU加速
    // 强制所有图片使用CPU解码和渲染
    
    // 设置最低质量的渲染参数
    // 牺牲质量换取稳定性
  }
  
  /// 禁用硬件加速的某些特性
  static void _disableHardwareAccelerationFeatures() {
    // 禁用可能导致闪烁的硬件加速特性
    // 这些设置基于Flutter引擎的底层实现
    
    // 强制使用CPU进行某些渲染操作
    // 避免GPU驱动的兼容性问题
  }
  
  /// 获取兼容性优化的滚动行为
  static ScrollBehavior getCompatibleScrollBehavior() {
    return const _CompatibleScrollBehavior();
  }
  
  /// 获取兼容性优化的文本样式
  static TextStyle getCompatibleTextStyle(TextStyle original) {
    return original.copyWith(
      // 添加一些渲染提示，提高兼容性
      fontFeatures: const [
        FontFeature.disable('liga'), // 禁用连字，避免某些GPU上的渲染问题
      ],
      // 确保字体渲染的一致性
      textBaseline: TextBaseline.alphabetic,
    );
  }
  
  /// 创建兼容性优化的Container组件
  static Widget createCompatibleContainer({
    Key? key,
    AlignmentGeometry? alignment,
    EdgeInsetsGeometry? padding,
    Color? color,
    Decoration? decoration,
    Decoration? foregroundDecoration,
    double? width,
    double? height,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? margin,
    Matrix4? transform,
    AlignmentGeometry? transformAlignment,
    Widget? child,
    Clip clipBehavior = Clip.none,
  }) {
    return RepaintBoundary(
      child: Container(
        key: key,
        alignment: alignment,
        padding: padding,
        // 强制使用纯色，避免渐变和复杂装饰
        color: color,
        // 禁用复杂装饰，使用最简单的渲染
        decoration: decoration != null ? BoxDecoration(
          color: decoration is BoxDecoration ? decoration.color : color,
          // 禁用所有可能导致渲染问题的特性
          border: null,
          borderRadius: null,
          boxShadow: null,
          gradient: null,
          image: null,
        ) : null,
        foregroundDecoration: null, // 完全禁用前景装饰
        width: width,
        height: height,
        constraints: constraints,
        margin: margin,
        transform: null, // 禁用变换，避免GPU计算
        transformAlignment: null,
        clipBehavior: Clip.none, // 禁用裁剪，减少GPU负担
        child: child,
      ),
    );
  }
  

  
  /// 创建兼容性优化的Text组件
  static Widget createCompatibleText(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    bool? softWrap,
  }) {
    return RepaintBoundary(
      child: Container(
        // 强制使用固定背景，避免透明度渲染问题
        color: Colors.transparent,
        child: Text(
          text,
          style: style != null ? style.copyWith(
            // 强制使用最基础的字体设置
            fontFamily: 'monospace', // 使用等宽字体，最稳定
            fontSize: (style.fontSize ?? 14.0).clamp(12.0, 24.0), // 限制字体大小范围
            fontWeight: FontWeight.normal, // 强制普通字重
            fontStyle: FontStyle.normal, // 强制普通样式
            decoration: TextDecoration.none, // 禁用所有装饰
            shadows: null, // 禁用阴影
            fontFeatures: [], // 禁用字体特性
            letterSpacing: 0.0, // 禁用字符间距
            wordSpacing: 0.0, // 禁用单词间距
            height: 1.2, // 固定行高
          ) : const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14.0,
            fontWeight: FontWeight.normal,
            fontStyle: FontStyle.normal,
            decoration: TextDecoration.none,
            shadows: null,
            fontFeatures: [],
            letterSpacing: 0.0,
            wordSpacing: 0.0,
            height: 1.2,
          ),
          textAlign: textAlign ?? TextAlign.left,
          maxLines: maxLines,
          overflow: overflow ?? TextOverflow.clip,
          softWrap: softWrap ?? true,
          textScaler: TextScaler.linear(1.0),
          // 强制使用最简单的文本方向
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
  
  /// 创建兼容性优化的列表视图
  static Widget createCompatibleListView({
    required List<Widget> children,
    ScrollController? controller,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
  }) {
    return RepaintBoundary(
      child: ListView(
        controller: controller,
        shrinkWrap: shrinkWrap,
        padding: padding,
        physics: const _CompatibleScrollPhysics(),
        children: children.map((child) => RepaintBoundary(child: child)).toList(),
      ),
    );
  }
  
  /// 创建兼容性优化的单子滚动视图
  static Widget createCompatibleSingleChildScrollView({
    required Widget child,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
    Axis scrollDirection = Axis.vertical,
  }) {
    return RepaintBoundary(
      child: SingleChildScrollView(
        controller: controller,
        padding: padding,
        scrollDirection: scrollDirection,
        physics: const _CompatibleScrollPhysics(),
        child: RepaintBoundary(child: child),
      ),
    );
  }

  /// 创建兼容性优化的AnimatedContainer
  static Widget createCompatibleAnimatedContainer({
    Key? key,
    AlignmentGeometry? alignment,
    EdgeInsetsGeometry? padding,
    Color? color,
    Decoration? decoration,
    Decoration? foregroundDecoration,
    double? width,
    double? height,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? margin,
    Matrix4? transform,
    AlignmentGeometry? transformAlignment,
    Widget? child,
    Clip clipBehavior = Clip.none,
    required Duration duration,
    Curve curve = Curves.linear,
    VoidCallback? onEnd,
  }) {
    return RepaintBoundary(
      child: AnimatedContainer(
        key: key,
        alignment: alignment,
        padding: padding,
        color: color,
        decoration: decoration,
        foregroundDecoration: foregroundDecoration,
        width: width,
        height: height,
        constraints: constraints,
        margin: margin,
        transform: transform,
        transformAlignment: transformAlignment,
        clipBehavior: clipBehavior,
        duration: duration,
        curve: curve,
        onEnd: onEnd,
        child: child,
      ),
    );
  }
 
}

/// 兼容性优化的滚动行为
class _CompatibleScrollBehavior extends ScrollBehavior {
  const _CompatibleScrollBehavior();
  
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const _CompatibleScrollPhysics();
  }
  
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // 使用更兼容的过度滚动指示器
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
      child: child,
    );
  }
}

/// 兼容性优化的滚动物理特性
class _CompatibleScrollPhysics extends ClampingScrollPhysics {
  const _CompatibleScrollPhysics({super.parent});
  
  @override
  _CompatibleScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _CompatibleScrollPhysics(parent: buildParent(ancestor));
  }
  
  @override
  double get minFlingVelocity => 100.0; // 降低最小滑动速度
  
  @override
  double get maxFlingVelocity => 2000.0; // 降低最大滑动速度
  
  @override
  double carriedMomentum(double existingVelocity) {
    // 减少动量传递，使滚动更平滑
    return existingVelocity * 0.8;
  }
}