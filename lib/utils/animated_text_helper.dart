import 'package:flutter/material.dart';
import 'dart:async';

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
    for (final controller in _characterControllers) {
      try {
        controller.dispose();
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
      // 为每个字符创建独立的动画控制器
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      
      // 透明度动画（渐入效果）
      final opacityAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
      
      // 位移动画（向上浮现效果）
      final slideAnimation = Tween<Offset>(
        begin: Offset(0, widget.animationDistance / 20), // 转换为相对偏移
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
      
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
    
    // 延迟开始动画
    _animationTimer = Timer(widget.animationDelay, () {
      if (!mounted || _isDisposed) return;
      
      // 依次启动每个字符的动画
      for (int i = 0; i < _characterControllers.length; i++) {
        Timer(widget.characterDelay * i, () {
          if (mounted && !_isDisposed && 
              !_characterControllers[i].isAnimating) {
            try {
              _characterControllers[i].forward();
            } catch (e) {
              // 忽略已销毁控制器的错误
            }
          }
        });
      }
    });
  }
  
  /// 重置所有字符动画 - 添加安全检查
  void _resetCharacterAnimations() {
    if (_isDisposed) return; // 安全检查
    
    _animationTimer?.cancel();
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
          return Text(character, style: widget.style);
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
                child: Text(
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
  
  /// 计算空格宽度
  double _calculateSpaceWidth(TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width;
  }
}