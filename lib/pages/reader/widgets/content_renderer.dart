import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'reader_theme.dart';

/// 阅读页面内容渲染器
///
/// 负责将 PageSlice 渲染为可显示的 Widget，
/// 包括章节头、文本行、页脚等。
///
/// 关键：分页引擎已经精确计算了每页的行数，
/// 渲染端必须严格适配，不能超出可用区域。

class ContentRenderer {
  /// 渲染一个完整页面
  static Widget buildPage({
    required PageSlice page,
    required ReaderTheme theme,
    required double fontSize,
    required double lineHeight,
    required String chapterTitle,
    required String pageIndicator,
    required String timeLabel,
    required String batteryLabel,
    required int ttsParagraphIndex,
    bool showTopBar = true,
    bool showBottomBar = true,
    bool showPageNumber = true,
    double horizontalPadding = 24.0,
    double topPadding = 18.0,
    double paragraphSpacing = 10.0,
    double firstLineIndent = 2.0,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding,
          horizontalPadding, showBottomBar ? 10.0 : 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTopBar) _buildChapterHeader(chapterTitle, theme),
          if (showTopBar) const SizedBox(height: 14),
          // 使用 Expanded 限制文字区域高度，内部用 ClipRect 裁剪
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in page.lines)
                      _buildTextLine(
                        line: line,
                        theme: theme,
                        fontSize: fontSize,
                        lineHeight: lineHeight,
                        ttsParagraphIndex: ttsParagraphIndex,
                        paragraphSpacing: paragraphSpacing,
                        firstLineIndent: firstLineIndent,
                      ),
                  ],
                ),
              ),
            ),
          ),
          // 页脚固定在底部
          if (showBottomBar)
            _buildFooter(
              theme: theme,
              pageIndicator: showPageNumber ? pageIndicator : '',
              timeLabel: timeLabel,
              batteryLabel: batteryLabel,
            ),
        ],
      ),
    );
  }

  /// 渲染章节头
  static Widget _buildChapterHeader(String title, ReaderTheme theme) {
    if (title.isEmpty) return const SizedBox.shrink();
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1.2,
        color: theme.secondaryText,
      ),
    );
  }

  /// 渲染单行文本
  static Widget _buildTextLine({
    required TextLine line,
    required ReaderTheme theme,
    required double fontSize,
    required double lineHeight,
    required int ttsParagraphIndex,
    double paragraphSpacing = 10.0,
    double firstLineIndent = 2.0,
  }) {
    final isHighlighted = line.paragraphIndex == ttsParagraphIndex;
    final effectiveFontSize = line.isTitle ? fontSize + 4 : fontSize;
    final effectiveLineHeight = line.isTitle ? 1.45 : lineHeight;
    final fontWeight = line.isTitle ? FontWeight.w600 : FontWeight.normal;
    final effectiveColor = isHighlighted ? theme.highlight : theme.text;

    // 首行缩进
    final indentChars = line.isTitle ? 0 : firstLineIndent.round();
    final indentStr = line.isFirstLineOfParagraph ? '\u3000' * indentChars : '';
    final displayText = line.isTitle ? line.text : '$indentStr${line.text}';

    // 段落间距：段尾行用 paragraphSpacing，段内行 2px
    final marginBottom = line.isLastLineOfParagraph ? paragraphSpacing : 2.0;

    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: effectiveFontSize,
          color: effectiveColor,
          height: effectiveLineHeight,
          fontWeight: fontWeight,
        ),
      ),
    );
  }

  /// 渲染滚动模式的段落
  static Widget buildParagraph({
    required ReaderParagraph paragraph,
    required ReaderTheme theme,
    required double fontSize,
    required double lineHeight,
    required int ttsParagraphIndex,
  }) {
    final isHighlighted = paragraph.index == ttsParagraphIndex;
    final isTitle = paragraph.isTitle;
    final effectiveFontSize = isTitle ? fontSize + 4 : fontSize;
    final effectiveLineHeight = isTitle ? 1.45 : lineHeight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlighted ? theme.highlight : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isTitle ? paragraph.text : '\u3000\u3000${paragraph.text}',
        style: TextStyle(
          fontSize: effectiveFontSize,
          color: theme.text,
          height: effectiveLineHeight,
          fontWeight: isTitle ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  /// 渲染页脚
  static Widget _buildFooter({
    required ReaderTheme theme,
    required String pageIndicator,
    required String timeLabel,
    required String batteryLabel,
  }) {
    return Row(
      children: [
        Text(
          timeLabel,
          style:
              TextStyle(fontSize: 11, height: 1.2, color: theme.secondaryText),
        ),
        const Spacer(),
        Text(
          pageIndicator,
          style:
              TextStyle(fontSize: 11, height: 1.2, color: theme.secondaryText),
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_std, size: 13, color: theme.secondaryText),
            const SizedBox(width: 4),
            Text(
              batteryLabel,
              style: TextStyle(
                  fontSize: 11, height: 1.2, color: theme.secondaryText),
            ),
          ],
        ),
      ],
    );
  }
}
