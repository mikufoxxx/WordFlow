import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import '../utils/app_theme.dart';

/// 响应式单词卡片组件
/// 根据设备类型自动调整尺寸和布局
class ResponsiveWordCard extends StatelessWidget {
  final String word;
  final String pronunciation;
  final String meaning;
  final VoidCallback? onTap;
  final bool showMeaning;

  const ResponsiveWordCard({
    Key? key,
    required this.word,
    required this.pronunciation,
    required this.meaning,
    this.onTap,
    this.showMeaning = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            margin: ResponsiveHelper.getResponsiveCardMargin(context),
            padding: ResponsiveHelper.getResponsiveCardPadding(context),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getResponsiveBorderRadius(context, 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: ResponsiveHelper.getResponsiveSpacing(context, 12),
                  offset: Offset(0, ResponsiveHelper.getResponsiveSpacing(context, 4)),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 单词
                _buildWordSection(context),
                
                // 音标
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                _buildPronunciationSection(context),
                
                // 释义（如果显示）
                if (showMeaning) ...[
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                  _buildMeaningSection(context),
                ],
                
                // 提示文本
                if (!showMeaning) ...[
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),
                  _buildHintSection(context),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建单词部分
  Widget _buildWordSection(BuildContext context) {
    return Text(
      word,
      style: TextStyle(
        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 32),
        fontWeight: FontWeight.bold,
        color: AppTheme.darkGray,
        letterSpacing: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// 构建音标部分
  Widget _buildPronunciationSection(BuildContext context) {
    return Text(
      pronunciation,
      style: TextStyle(
        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
        color: AppTheme.coolGray500,
        fontStyle: FontStyle.italic,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// 构建释义部分
  Widget _buildMeaningSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 16)),
      decoration: BoxDecoration(
        color: AppTheme.coolGray50,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.getResponsiveBorderRadius(context, 12),
        ),
      ),
      child: Text(
        meaning,
        style: TextStyle(
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 15),
          color: AppTheme.coolGray700,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 构建提示部分
  Widget _buildHintSection(BuildContext context) {
    return Text(
      '点击查看释义',
      style: TextStyle(
        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
        color: AppTheme.coolGray400,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// 响应式按钮组件
class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isOutlined;

  const ResponsiveButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isOutlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);
        final buttonPadding = ResponsiveHelper.getResponsiveButtonPadding(context);
        final fontSize = ResponsiveHelper.getResponsiveFontSize(context, 14);
        final iconSize = ResponsiveHelper.getResponsiveIconSize(context, 18);
        
        return SizedBox(
          height: buttonHeight,
          child: isOutlined
              ? OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: icon != null ? Icon(icon, size: iconSize) : const SizedBox.shrink(),
                  label: Text(
                    text,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? AppTheme.primaryGray,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: buttonPadding,
                    side: BorderSide(
                      color: backgroundColor ?? AppTheme.primaryGray,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.getResponsiveBorderRadius(context, 12),
                      ),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: icon != null ? Icon(icon, size: iconSize) : const SizedBox.shrink(),
                  label: Text(
                    text,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: backgroundColor ?? AppTheme.primaryGray,
                    padding: buttonPadding,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.getResponsiveBorderRadius(context, 12),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// 响应式网格布局组件
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        final columns = ResponsiveHelper.getResponsiveGridColumns(context);
        final crossAxisSpacing = ResponsiveHelper.getResponsiveGridCrossAxisSpacing(context);
        final mainAxisSpacing = ResponsiveHelper.getResponsiveGridMainAxisSpacing(context);
        
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          children: children,
        );
      },
    );
  }
}

/// 响应式卡片列表组件
class ResponsiveCardList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;
  final double spacing;

  const ResponsiveCardList({
    Key? key,
    required this.children,
    this.padding,
    this.spacing = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        final responsiveSpacing = ResponsiveHelper.getResponsiveSpacing(context, spacing);
        
        return ListView.separated(
          padding: padding ?? ResponsiveHelper.getResponsivePadding(context),
          itemCount: children.length,
          separatorBuilder: (context, index) => SizedBox(height: responsiveSpacing),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
} 