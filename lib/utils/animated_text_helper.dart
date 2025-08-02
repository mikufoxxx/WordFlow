import 'package:flutter/material.dart';
import 'dart:async';
import 'performance_optimizer.dart';

/// 动画文字帮助类
/// 提供字符级别的浮现动画效果，每个字符独立动画
class AnimatedTextHelper {
  
  /// 构建带动画的文字组件
  /// 每个字符都有独立的向上浮现动画效果
  /// 
  /// [text] 要显示的文本
  /// [style] 文字样式
  /// [animationController] 主动画控制器，用于控制整体动画时机
  /// [animationDelay] 动画延迟，在主控制器启动后的延迟时间
  /// [characterDelay] 字符间的延迟时间，默认为50ms
  /// [animationDistance] 动画移动距离，默认为20像素
  static Widget buildAnimatedText({
    required String text,
    required TextStyle style,
    required AnimationController animationController,
    Duration animationDelay = Duration.zero,
    Duration characterDelay = const Duration(milliseconds: 50),
    double animationDistance = 20.0,
  }) {
    return _AnimatedTextWidget(
      text: text,
      style: style,
      animationController: animationController,
      animationDelay: animationDelay,
      characterDelay: characterDelay,
      animationDistance: animationDistance,
    );
  }
}

/// 内部动画文字组件
class _AnimatedTextWidget extends StatefulWidget {
  final String text;
  final TextStyle style;
  final AnimationController animationController;
  final Duration animationDelay;
  final Duration characterDelay;
  final double animationDistance;

  const _AnimatedTextWidget({
    required this.text,
    required this.style,
    required this.animationController,
    required this.animationDelay,
    required this.characterDelay,
    required this.animationDistance,
  });

  @override
  State<_AnimatedTextWidget> createState() => _AnimatedTextWidgetState();
}

class _AnimatedTextWidgetState extends State<_AnimatedTextWidget>
    with TickerProviderStateMixin {
  
  final List<AnimationController> _characterControllers = [];
  final List<Animation<double>> _characterOpacityAnimations = [];
  final List<Animation<Offset>> _characterSlideAnimations = [];
  Timer? _animationTimer;
  bool _isDisposed = false;
  
  // 性能优化：使用池化的key
  static const String _animationPoolKey = 'animated_text_helper_chars';
  
  @override
  void initState() {
    super.initState();
    _initializeCharacterAnimations();
    _setupMainAnimationListener();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _animationTimer?.cancel();
    
    // 返回控制器到池中而不是销毁
    for (final controller in _characterControllers) {
      try {
        PerformanceOptimizer.returnAnimationController(
          _animationPoolKey,
          controller,
        );
      } catch (e) {
        // 忽略已销毁控制器的错误
      }
    }
    super.dispose();
  }
  
  /// 初始化每个字符的动画控制器
  void _initializeCharacterAnimations() {
    final characters = widget.text.split('');
    
    for (int i = 0; i < characters.length; i++) {
      // 为每个字符创建独立的动画控制器 - 使用性能优化器池化
      final controller = PerformanceOptimizer.getAnimationController(
        poolKey: _animationPoolKey,
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      
      // 透明度动画（渐入效果）- 使用池化的Tween和CurvedAnimation
      final opacityTween = PerformanceOptimizer.getTween<double>(
        '${_animationPoolKey}_opacity_tween',
        0.0,
        1.0,
      );
      final opacityCurve = PerformanceOptimizer.getCurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      );
      final opacityAnimation = opacityTween.animate(opacityCurve);
      
      // 位移动画（向上浮现效果）- 使用池化的Tween和CurvedAnimation
      final slideTween = PerformanceOptimizer.getTween<Offset>(
        '${_animationPoolKey}_slide_tween',
        Offset(0, widget.animationDistance / 20),
        Offset.zero,
      );
      final slideCurve = PerformanceOptimizer.getCurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      );
      final slideAnimation = slideTween.animate(slideCurve);
      
      _characterControllers.add(controller);
      _characterOpacityAnimations.add(opacityAnimation);
      _characterSlideAnimations.add(slideAnimation);
    }
  }
  
  /// 设置主动画控制器监听
  void _setupMainAnimationListener() {
    widget.animationController.addStatusListener((status) {
      if (_isDisposed) return; // 安全检查
      
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.completed) {
        _startCharacterAnimations();
      } else if (status == AnimationStatus.reverse ||
                 status == AnimationStatus.dismissed) {
        _resetCharacterAnimations();
      }
    });
    
    // 如果主控制器已经在运行，立即开始动画
    if (widget.animationController.isAnimating ||
        widget.animationController.isCompleted) {
      _startCharacterAnimations();
    }
  }
  
  /// 开始字符动画序列
  void _startCharacterAnimations() {
    if (_isDisposed) return; // 安全检查
    
    _animationTimer?.cancel();
    
    // 延迟开始动画 - 使用性能优化器Timer池
    PerformanceOptimizer.createTimer(
      poolKey: '${_animationPoolKey}_timers',
      duration: widget.animationDelay,
      callback: () {
        if (!mounted || _isDisposed) return;
        
        // 依次启动每个字符的动画
        for (int i = 0; i < _characterControllers.length; i++) {
          PerformanceOptimizer.createTimer(
            poolKey: '${_animationPoolKey}_timers',
            duration: widget.characterDelay * i,
            callback: () {
              if (mounted && !_isDisposed && 
                  i < _characterControllers.length &&
                  !_characterControllers[i].isAnimating) {
                try {
                  _characterControllers[i].forward();
                } catch (e) {
                  // 忽略已销毁控制器的错误
                }
              }
            },
          );
        }
      },
    );
  }
  
  /// 重置所有字符动画 - 添加安全检查
  void _resetCharacterAnimations() {
    if (_isDisposed) return; // 安全检查
    
    _animationTimer?.cancel();
    // 取消性能优化器Timer池中的定时器
    PerformanceOptimizer.cancelTimers('${_animationPoolKey}_timers');
    
    for (final controller in _characterControllers) {
      try {
        if (controller.isAnimating) {
          controller.stop();
        }
        controller.reset();
      } catch (e) {
        // 忽略已销毁控制器的错误
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty || _isDisposed) {
      return const SizedBox.shrink();
    }
    
    final characters = widget.text.split('');
    
    return Wrap(
      children: characters.asMap().entries.map((entry) {
        final index = entry.key;
        final character = entry.value;
        
        // 安全检查索引
        if (index >= _characterControllers.length || 
            index >= _characterOpacityAnimations.length ||
            index >= _characterSlideAnimations.length) {
          return OptimizedText(character, style: widget.style);
        }
        
        // 空格特殊处理
        if (character == ' ') {
          return SizedBox(
            width: _calculateSpaceWidth(widget.style),
          );
        }
        
        return AnimatedBuilder(
          animation: Listenable.merge([
            _characterOpacityAnimations[index],
            _characterSlideAnimations[index],
          ]),
          builder: (context, child) {
            return Transform.translate(
              offset: _characterSlideAnimations[index].value * widget.animationDistance,
              child: Opacity(
                opacity: _characterOpacityAnimations[index].value,
                child: OptimizedText(
                  character,
                  style: widget.style,
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
  
  /// 计算空格宽度 - 使用池化的TextPainter
  double _calculateSpaceWidth(TextStyle style) {
    final textPainter = PerformanceOptimizer.getTextPainter(
      textSpan: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final width = textPainter.width;
    PerformanceOptimizer.returnTextPainter(textPainter);
    return width;
  }
}