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
  
  /// 获取或创建动画控制器
  static AnimationController getAnimationController({
    required String poolKey,
    required Duration duration,
    required TickerProvider vsync,
  }) {
    final pool = _controllerPool[poolKey] ??= [];
    
    // 尝试重用现有的控制器
    for (int i = pool.length - 1; i >= 0; i--) {
      final controller = pool[i];
      if (!controller.isAnimating && controller.duration == duration) {
        controller.reset();
        return controller;
      }
    }
    
    // 如果没有可重用的，创建新的控制器
    final controller = AnimationController(duration: duration, vsync: vsync);
    pool.add(controller);
    return controller;
  }
  
  /// 归还动画控制器到池中
  static void returnAnimationController(String poolKey, AnimationController controller) {
    try {
      controller.reset();
      final pool = _controllerPool[poolKey] ??= [];
      if (!pool.contains(controller)) {
        pool.add(controller);
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
    final timer = Timer(duration, callback);
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
    final timer = Timer.periodic(duration, callback);
    final pool = _timerPool[poolKey] ??= [];
    pool.add(timer);
    return timer;
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
  
  /// 设置缓存
  static void set(String key, dynamic value, {Duration? ttl}) {
    _cache[key] = value;
    _timestamps[key] = DateTime.now();
    
    // 清理过期缓存
    _cleanExpired(ttl ?? _defaultTTL);
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



/// 优化的Text Widget - 减少重建
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
    return RepaintBoundary(
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}