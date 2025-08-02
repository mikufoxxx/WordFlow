// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';
import 'dart:async';

/// 性能优化工具类
/// 用于管理动画控制器、Timer和内存优化
class PerformanceOptimizer {
  
  /// 动画控制器池 - 重用动画控制器以减少内存分配
  static final Map<String, List<AnimationController>> _controllerPool = {};
  
  /// Timer池 - 管理所有Timer，确保正确清理
  static final Map<String, List<Timer>> _timerPool = {};
  
  /// TextPainter池 - 复用TextPainter对象减少文本渲染开销
  static final List<TextPainter> _textPainterPool = [];
  
  /// Tween对象池 - 复用Tween对象减少动画对象创建开销
  static final Map<String, List<Tween>> _tweenPool = {};
  
  /// CurvedAnimation池 - 复用CurvedAnimation对象
  static final List<CurvedAnimation> _curvedAnimationPool = [];
  
  // 预热池配置
  static const Map<String, int> _preWarmPoolSizes = {
    'character_animation': 50,
    'text_painter': 20,
    'opacity_tween': 30,
    'slide_tween': 30,
    'curved_animation': 40,
  };
  
  // 内存压力监控
  static bool _isMemoryPressureHigh = false;
  static DateTime _lastMemoryCheck = DateTime.now();
  
  /// 获取或创建动画控制器
  static AnimationController getAnimationController({
    required String poolKey,
    required Duration duration,
    required TickerProvider vsync,
  }) {
    final pool = _controllerPool[poolKey] ??= [];
    
    // 尝试重用现有的控制器 - 优化：检查更多条件
    for (int i = pool.length - 1; i >= 0; i--) {
      final controller = pool[i];
      if (!controller.isAnimating && 
          !controller.isCompleted && 
          controller.duration == duration) {
        controller.reset();
        pool.removeAt(i); // 从池中移除，避免重复使用
        return controller;
      }
    }
    
    // 限制池大小，避免内存泄漏
    if (pool.length > 20) {
      // 清理最旧的控制器
      final oldController = pool.removeAt(0);
      try {
        oldController.dispose();
      } catch (e) {
        // 忽略已释放的控制器
      }
    }
    
    // 如果没有可重用的，创建新的控制器
    final controller = AnimationController(duration: duration, vsync: vsync);
    return controller;
  }
  
  /// 归还动画控制器到池中
  static void returnAnimationController(String poolKey, AnimationController controller) {
    try {
      // 检查控制器状态
      
      controller.reset();
      final pool = _controllerPool[poolKey] ??= [];
      
      // 限制池大小并检查重复
      if (pool.length < 10 && !pool.contains(controller)) {
        pool.add(controller);
      } else if (!pool.contains(controller)) {
        // 池已满，直接释放控制器
        controller.dispose();
      }
    } catch (e) {
      // 如果控制器已被释放，忽略错误
    }
  }
  
  /// 创建并管理Timer
  static Timer createTimer({
    required String poolKey,
    required Duration duration,
    required VoidCallback callback,
  }) {
    _cleanupInactiveTimers(poolKey); // 清理无效Timer
    
    Timer? timer;
    timer = Timer(duration, () {
      callback();
      if (timer != null) {
        _removeTimerFromPool(poolKey, timer);
      }
    });
    final pool = _timerPool[poolKey] ??= [];
    pool.add(timer);
    return timer;
  }

  /// 创建并管理周期性Timer
  static Timer createPeriodicTimer({
    required String poolKey,
    required Duration duration,
    required void Function(Timer) callback,
  }) {
    _cleanupInactiveTimers(poolKey); // 清理无效Timer
    
    final timer = Timer.periodic(duration, callback);
    final pool = _timerPool[poolKey] ??= [];
    pool.add(timer);
    return timer;
  }

  /// 清理无效的Timer
  static void _cleanupInactiveTimers(String poolKey) {
    final pool = _timerPool[poolKey];
    if (pool != null) {
      pool.removeWhere((timer) => !timer.isActive);
    }
  }

  /// 从池中移除Timer
  static void _removeTimerFromPool(String poolKey, Timer timer) {
    final pool = _timerPool[poolKey];
    if (pool != null) {
      pool.remove(timer);
    }
  }
  
  /// 清理指定池的所有Timer
  static void cancelTimers(String poolKey) {
    final pool = _timerPool[poolKey];
    if (pool != null) {
      for (final timer in pool) {
        if (timer.isActive) {
          timer.cancel();
        }
      }
      pool.clear();
    }
  }
  
  /// 获取TextPainter对象 - 复用以减少文本渲染开销
  static TextPainter getTextPainter({
    required TextSpan textSpan,
    TextDirection textDirection = TextDirection.ltr,
    TextAlign textAlign = TextAlign.left,
  }) {
    _checkMemoryPressure();
    
    TextPainter? painter;
    
    // 尝试从池中获取可复用的TextPainter
    if (_textPainterPool.isNotEmpty) {
      painter = _textPainterPool.removeLast();
    } else {
      painter = TextPainter(textDirection: textDirection);
    }
    
    // 配置TextPainter
    painter.text = textSpan;
    painter.textAlign = textAlign;
    painter.textDirection = textDirection;
    
    return painter;
  }
  
  /// 归还TextPainter到池中
  static void returnTextPainter(TextPainter painter) {
    if (_textPainterPool.length < 20) { // 限制池大小
      painter.text = null; // 清理引用
      _textPainterPool.add(painter);
    } else {
      painter.dispose();
    }
  }
  
  /// 获取Tween对象 - 复用以减少动画对象创建开销
  static Tween<T> getTween<T>(String poolKey, T begin, T end) {
    final pool = _tweenPool[poolKey] ??= [];
    
    // 尝试从池中获取可复用的Tween
    for (int i = pool.length - 1; i >= 0; i--) {
      final tween = pool[i];
      if (tween is Tween<T>) {
        pool.removeAt(i);
        tween.begin = begin;
        tween.end = end;
        return tween;
      }
    }
    
    // 如果没有可复用的，创建新的
    return Tween<T>(begin: begin, end: end);
  }
  
  /// 归还Tween对象到池中
  static void returnTween(String poolKey, Tween tween) {
    final pool = _tweenPool[poolKey] ??= [];
    if (pool.length < 15) { // 限制池大小
      pool.add(tween);
    }
  }
  
  /// 获取CurvedAnimation对象 - 复用以减少动画对象创建开销
  static CurvedAnimation getCurvedAnimation({
    required AnimationController parent,
    required Curve curve,
    Curve? reverseCurve,
  }) {
    CurvedAnimation? curvedAnimation;
    
    // 尝试从池中获取可复用的CurvedAnimation
    for (int i = _curvedAnimationPool.length - 1; i >= 0; i--) {
      final existing = _curvedAnimationPool[i];
      if (existing.parent == parent) {
        _curvedAnimationPool.removeAt(i);
        curvedAnimation = existing;
        break;
      }
    }
    
    if (curvedAnimation != null) {
      // 重新配置现有的CurvedAnimation
      return CurvedAnimation(
        parent: parent,
        curve: curve,
        reverseCurve: reverseCurve,
      );
    } else {
      // 创建新的CurvedAnimation
      return CurvedAnimation(
        parent: parent,
        curve: curve,
        reverseCurve: reverseCurve,
      );
    }
  }
  
  /// 归还CurvedAnimation到池中
  static void returnCurvedAnimation(CurvedAnimation curvedAnimation) {
    if (_curvedAnimationPool.length < 15) { // 限制池大小
      _curvedAnimationPool.add(curvedAnimation);
    } else {
      curvedAnimation.dispose();
    }
  }
  
  /// 清理指定池的所有动画控制器
  static void disposeAnimationControllers(String poolKey) {
    final pool = _controllerPool[poolKey];
    if (pool != null) {
      for (final controller in pool) {
        try {
          controller.dispose();
        } catch (e) {
          // 如果控制器已被释放，忽略错误
        }
      }
      pool.clear();
    }
  }
  
  /// 预热常用对象池
  static void preWarmPools() {
    // 预热TextPainter池
    final preWarmTextPainters = _preWarmPoolSizes['text_painter'] ?? 0;
    for (int i = 0; i < preWarmTextPainters; i++) {
      _textPainterPool.add(TextPainter(
        textDirection: TextDirection.ltr,
      ));
    }
    
    // 预热Tween池
     final preWarmTweens = _preWarmPoolSizes['opacity_tween'] ?? 0;
     for (int i = 0; i < preWarmTweens; i++) {
       final key = 'preWarm_opacity_$i';
       final pool = _tweenPool[key] ??= [];
       pool.add(Tween<double>(begin: 0.0, end: 1.0));
     }
     
     final preWarmSlideTweens = _preWarmPoolSizes['slide_tween'] ?? 0;
     for (int i = 0; i < preWarmSlideTweens; i++) {
       final key = 'preWarm_slide_$i';
       final pool = _tweenPool[key] ??= [];
       pool.add(Tween<Offset>(begin: Offset.zero, end: Offset.zero));
     }
  }
  
  /// 检查内存压力
  static void _checkMemoryPressure() {
    final now = DateTime.now();
    if (now.difference(_lastMemoryCheck).inSeconds < 30) return;
    
    _lastMemoryCheck = now;
    
    // 简单的内存压力检测：基于池的大小
      final totalPoolSize = _controllerPool.values
          .fold(0, (sum, pool) => sum + pool.length) +
          _textPainterPool.length +
          _tweenPool.values.fold(0, (sum, pool) => sum + pool.length) +
          _curvedAnimationPool.length;
    
    _isMemoryPressureHigh = totalPoolSize > 500;
    
    // 如果内存压力高，清理一些缓存
    if (_isMemoryPressureHigh) {
      _cleanupExcessObjects();
    }
  }
  
  /// 清理多余对象
   static void _cleanupExcessObjects() {
     // 清理超过最大大小的池
     if (_textPainterPool.length > 20) {
       final excess = _textPainterPool.length - 20;
       for (int i = 0; i < excess; i++) {
         final painter = _textPainterPool.removeAt(0);
         painter.dispose();
       }
     }
     
     // 清理旧的Widget缓存
     final now = DateTime.now();
     WidgetCache._cacheTimestamps.removeWhere((key, timestamp) => 
         now.difference(timestamp) > WidgetCache._cacheTTL);
   }
  
  /// 清理所有资源
  static void clearAll() {
    // 清理所有Timer
    for (final pool in _timerPool.values) {
      for (final timer in pool) {
        if (timer.isActive) {
          timer.cancel();
        }
      }
      pool.clear();
    }
    _timerPool.clear();
    
    // 清理所有动画控制器
    for (final pool in _controllerPool.values) {
      for (final controller in pool) {
        try {
          controller.dispose();
        } catch (e) {
          // 如果控制器已被释放，忽略错误
        }
      }
      pool.clear();
    }
    _controllerPool.clear();
    
    // 清理TextPainter池
    for (final painter in _textPainterPool) {
      try {
        painter.dispose();
      } catch (e) {
        // 忽略错误
      }
    }
    _textPainterPool.clear();
    
    // 清理Tween池
    for (final pool in _tweenPool.values) {
      pool.clear();
    }
    _tweenPool.clear();
    
    // 清理CurvedAnimation池
    for (final curvedAnimation in _curvedAnimationPool) {
      try {
        curvedAnimation.dispose();
      } catch (e) {
        // 忽略错误
      }
    }
    _curvedAnimationPool.clear();
  }
  
  /// 获取当前资源使用情况
  static Map<String, dynamic> getResourceStats() {
    int totalControllers = 0;
    int totalTimers = 0;
    
    for (final pool in _controllerPool.values) {
      totalControllers += pool.length;
    }
    
    for (final pool in _timerPool.values) {
      totalTimers += pool.where((timer) => timer.isActive).length;
    }
    
    return {
      'activeControllers': totalControllers,
      'activeTimers': totalTimers,
      'controllerPools': _controllerPool.keys.toList(),
      'timerPools': _timerPool.keys.toList(),
    };
  }
}

/// 优化的Widget构建器 - 减少不必要的重建
class OptimizedBuilder extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  final List<Object?> dependencies;
  
  const OptimizedBuilder({
    Key? key,
    required this.builder,
    required this.dependencies,
  }) : super(key: key);
  
  @override
  State<OptimizedBuilder> createState() => _OptimizedBuilderState();
}

class _OptimizedBuilderState extends State<OptimizedBuilder> {
  Widget? _cachedWidget;
  List<Object?>? _lastDependencies;
  
  @override
  Widget build(BuildContext context) {
    // 检查依赖是否发生变化
    if (_cachedWidget == null || !_dependenciesEqual(widget.dependencies, _lastDependencies)) {
      _cachedWidget = widget.builder(context);
      _lastDependencies = List.from(widget.dependencies);
    }
    
    return _cachedWidget!;
  }
  
  bool _dependenciesEqual(List<Object?> a, List<Object?>? b) {
    if (b == null || a.length != b.length) return false;
    
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    
    return true;
  }
}

/// 内存缓存管理器
class MemoryCache {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _timestamps = {};
  static const Duration _defaultTTL = Duration(minutes: 10);
  static const int _maxCacheSize = 100; // 限制缓存大小
  
  /// 设置缓存
  static void set(String key, dynamic value, {Duration? ttl}) {
    // 限制缓存大小，防止内存泄漏
    if (_cache.length >= _maxCacheSize) {
      _evictOldestEntries(10); // 清理最旧的10个条目
    }
    
    _cache[key] = value;
    _timestamps[key] = DateTime.now();
    
    // 清理过期缓存
    _cleanExpired(ttl ?? _defaultTTL);
  }

  /// 清理最旧的条目
  static void _evictOldestEntries(int count) {
    if (_timestamps.isEmpty) return;
    
    final sortedEntries = _timestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final toRemove = sortedEntries.take(count);
    for (final entry in toRemove) {
      _cache.remove(entry.key);
      _timestamps.remove(entry.key);
    }
  }
  
  /// 获取缓存
  static T? get<T>(String key, {Duration? ttl}) {
    final timestamp = _timestamps[key];
    if (timestamp == null) return null;
    
    final maxAge = ttl ?? _defaultTTL;
    if (DateTime.now().difference(timestamp) > maxAge) {
      _cache.remove(key);
      _timestamps.remove(key);
      return null;
    }
    
    return _cache[key] as T?;
  }
  
  /// 清理过期缓存
  static void _cleanExpired(Duration ttl) {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    _timestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > ttl) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      _cache.remove(key);
      _timestamps.remove(key);
    }
  }
  
  /// 清空所有缓存
  static void clear() {
    _cache.clear();
    _timestamps.clear();
  }
  
  /// 获取缓存统计
  static Map<String, dynamic> getStats() {
    return {
      'totalItems': _cache.length,
      'keys': _cache.keys.toList(),
      'memoryUsage': _cache.toString().length, // 简单的内存估算
    };
  }
}



/// 高级Widget缓存系统
class WidgetCache {
  static final Map<String, Widget> _widgetCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTTL = Duration(minutes: 5);
  static const int _maxCacheSize = 50;
  
  /// 获取缓存的Widget
  static Widget? get(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;
    
    if (DateTime.now().difference(timestamp) > _cacheTTL) {
      _widgetCache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    
    return _widgetCache[key];
  }
  
  /// 缓存Widget
  static void set(String key, Widget widget) {
    if (_widgetCache.length >= _maxCacheSize) {
      _evictOldest();
    }
    
    _widgetCache[key] = widget;
    _cacheTimestamps[key] = DateTime.now();
  }
  
  /// 清理最旧的缓存
  static void _evictOldest() {
    if (_cacheTimestamps.isEmpty) return;
    
    final oldestEntry = _cacheTimestamps.entries
        .reduce((a, b) => a.value.isBefore(b.value) ? a : b);
    
    _widgetCache.remove(oldestEntry.key);
    _cacheTimestamps.remove(oldestEntry.key);
  }
  
  /// 清空缓存
  static void clear() {
    _widgetCache.clear();
    _cacheTimestamps.clear();
  }
}

/// 渲染优化的Text Widget
class OptimizedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  
  const OptimizedText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 生成缓存键
    final cacheKey = 'text_${text.hashCode}_${style.hashCode}_${textAlign.hashCode}';
    
    // 尝试从缓存获取
    Widget? cachedWidget = WidgetCache.get(cacheKey);
    if (cachedWidget != null) {
      return cachedWidget;
    }
    
    // 创建新的Widget并缓存
    final widget = RepaintBoundary(
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
    
    WidgetCache.set(cacheKey, widget);
    return widget;
  }
}

/// 高性能动画Widget - 减少不必要的重建
class PerformantAnimatedWidget extends StatefulWidget {
  final AnimationController controller;
  final Widget Function(BuildContext context, Animation<double> animation) builder;
  final String? cacheKey;
  
  const PerformantAnimatedWidget({
    Key? key,
    required this.controller,
    required this.builder,
    this.cacheKey,
  }) : super(key: key);
  
  @override
  State<PerformantAnimatedWidget> createState() => _PerformantAnimatedWidgetState();
}

class _PerformantAnimatedWidgetState extends State<PerformantAnimatedWidget> {
  Widget? _cachedWidget;
  double? _lastValue;
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        // 检查动画值是否发生显著变化
        final currentValue = widget.controller.value;
        if (_cachedWidget != null && _lastValue != null) {
          final difference = (currentValue - _lastValue!).abs();
          if (difference < 0.01) { // 阈值优化，减少微小变化的重建
            return _cachedWidget!;
          }
        }
        
        _lastValue = currentValue;
        _cachedWidget = RepaintBoundary(
          child: widget.builder(context, widget.controller),
        );
        
        return _cachedWidget!;
      },
    );
  }
}