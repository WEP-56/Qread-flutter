import 'package:flutter/material.dart';

/// 文本测量工具
///
/// 封装 TextPainter，提供文本高度测量和行级信息获取。
/// 所有测量均考虑首行缩进、续行标记等排版要素。

class TextMeasurer {
  /// 测量文本渲染高度
  static double measureHeight(
    String text, {
    required double fontSize,
    required double lineHeight,
    required double maxWidth,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  /// 获取文本的逐行信息
  ///
  /// 返回每行的 [startIndex, endIndex) 和高度。
  /// 这是最关键的测量方法——把段落拆成行，供行级分页使用。
  static List<LineInfo> computeLines({
    required String text,
    required double fontSize,
    required double lineHeight,
    required double maxWidth,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final result = <LineInfo>[];
    final lineCount = painter.computeLineMetrics().length;

    // 使用 getLineBoundary 获取每行的字符范围
    // 注意：getLineBoundary 需要 TextPosition，不是直接按行号
    // 我们遍历文本位置，逐步获取行边界
    if (lineCount == 0 || text.isEmpty) {
      return result;
    }

    int currentOffset = 0;
    for (int i = 0; i < lineCount; i++) {
      // 对于首行或文本中间位置，使用 getLineBoundary 获取行范围
      final position = TextPosition(offset: currentOffset);
      final boundary = painter.getLineBoundary(position);

      final start = boundary.start;
      final end = boundary.end;

      if (start >= end || start >= text.length) break;

      final clampedEnd = end.clamp(0, text.length);
      final lineText = text.substring(start, clampedEnd);
      final lineHeightValue = fontSize * lineHeight;

    result.add(LineInfo(
      text: lineText,
      startOffset: start,
      endOffset: clampedEnd,
      height: lineHeightValue,
    ));

      currentOffset = clampedEnd;
      if (currentOffset >= text.length) break;
    }

    return result;
  }

  /// 测量带首行缩进的文本块高度
  ///
  /// [isContinuation] 为 false 时添加两个全角空格缩进。
  static double measureBlockHeight(
    String text, {
    required bool isTitle,
    required bool isContinuation,
    required double fontSize,
    required double lineHeight,
    required double maxWidth,
  }) {
    final displayText =
        isTitle ? text : '${isContinuation ? '' : '\u3000\u3000'}$text';
    return measureHeight(
      displayText,
      fontSize: isTitle ? fontSize + 4 : fontSize,
      lineHeight: isTitle ? 1.45 : lineHeight,
      maxWidth: maxWidth,
      fontWeight: isTitle ? FontWeight.w600 : FontWeight.normal,
    );
  }
}

/// 行信息
class LineInfo {
  const LineInfo({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.height,
  });

  final String text;
  final int startOffset;
  final int endOffset;
  final double height;
}
