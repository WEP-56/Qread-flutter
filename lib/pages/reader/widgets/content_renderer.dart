import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'reader_theme.dart';

/// 阅读页面内容渲染器
///
/// 负责将 PageSlice 渲染为可显示的 Widget，
/// 包括章节头、文本行、页脚等。

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
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChapterHeader(chapterTitle, theme),
          const SizedBox(height: 14),
          // 使用 Expanded + overflow: Clip 嚴格限制文字區域
          Expanded(
            child: ClipRect(
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
                    ),
                ],
              ),
            ),
          ),
          _buildFooter(
            theme: theme,
            pageIndicator: pageIndicator,
            timeLabel: timeLabel,
            batteryLabel: batteryLabel,
          ),
        ],
      ),
    );
  }

  /// 渲染章节头
  static Widget _buildChapterHeader(String title, ReaderTheme theme) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
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
  }) {
    final isHighlighted = line.paragraphIndex == ttsParagraphIndex;
    final effectiveFontSize = line.isTitle ? fontSize + 4 : fontSize;
    final effectiveColor = isHighlighted ? theme.highlight : theme.text;
    final effectiveLineHeight = line.isTitle ? 1.45 : lineHeight;
    final fontWeight =
        line.isTitle ? FontWeight.w600 : FontWeight.normal;

    // 首行缩进
    final displayText =
        line.isTitle ? line.text : '${line.isFirstLineOfParagraph ? '\u3000\u3000' : ''}${line.text}';

    return Container(
      margin: EdgeInsets.only(
        bottom: line.isLastLineOfParagraph ? 10 : 2,
      ),
      child: Text(
        displayText,
        softWrap: true,
        overflow: TextOverflow.visible,
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
          style: TextStyle(fontSize: 11, color: theme.secondaryText),
        ),
        const Spacer(),
        Text(
          pageIndicator,
          style: TextStyle(fontSize: 11, color: theme.secondaryText),
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_std, size: 13, color: theme.secondaryText),
            const SizedBox(width: 4),
            Text(
              batteryLabel,
              style: TextStyle(fontSize: 11, color: theme.secondaryText),
            ),
          ],
        ),
      ],
    );
  }
}
