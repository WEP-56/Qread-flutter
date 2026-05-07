import 'package:flutter/material.dart';

import 'models.dart';

/// 行级分页引擎
///
/// 核心设计参照 legado 的 TextChapterLayout：
/// 1. 将段落文本通过 TextPainter 拆成行
/// 2. 逐行累加高度，当累计高度 + 下一行高度 > 可用高度时换页
/// 3. 段落自然在行边界处跨页，无需段中截断的特殊处理
///
/// 解决的问题：
/// - 旧版段落级分页在"页面有内容但新段落放不下"时直接提交空底页
/// - 旧版只在段落独占整页时才触发二分截断，导致大段文字推到下页
/// - 新版行级分页天然解决这些问题，每页都填到最满
///
/// v2 修复：
/// - 严格限制文字区域不超出可用高度（解决滑轨和溢出问题）
/// - 中文断行优化：避免单字独占一行（widow/orphan 控制）
/// - 精确的行高和间距计算，确保排版引擎与渲染引擎一致

class PaginationEngine {
  /// 页面布局常量
  static const double horizontalPadding = 24.0;
  static const double topPadding = 18.0;
  static const double bottomPadding = 10.0;
  static const double chapterHeaderHeight = 30.0;
  static const double footerHeight = 22.0;
  static const double headerBottomSpacing = 14.0;
  static const double paragraphSpacing = 10.0;

  /// 计算章节的完整分页布局
  ChapterLayout paginate({
    required String content,
    required String? chapterTitle,
    required int chapterIndex,
    required double fontSize,
    required double lineHeight,
    required Size viewportSize,
    required double safeTop,
    required double safeBottom,
    int targetPosition = 0,
  }) {
    // 1. 提取段落
    final paragraphs = _extractParagraphs(content, chapterTitle: chapterTitle);

    if (paragraphs.isEmpty) {
      return ChapterLayout(
        paragraphs: [],
        pages: [],
        paragraphPageLookup: {},
        chapterIndex: chapterIndex,
        contentHash: content.hashCode,
      );
    }

    // 2. 计算可用区域（严格计算，与 content_renderer.dart 保持一致）
    final availableWidth = viewportSize.width - horizontalPadding * 2;
    final availableHeight = viewportSize.height -
        safeTop -
        safeBottom -
        topPadding -
        bottomPadding -
        chapterHeaderHeight -
        footerHeight -
        headerBottomSpacing;

    // 3. 计算精确行高（与渲染端 TextStyle 一致）
    final bodyLineHeightPx = fontSize * lineHeight;
    final titleLineHeightPx = (fontSize + 4) * 1.45;

    // 4. 逐段落 → 逐行 → 分页
    final pages = <PageSlice>[];
    final lookup = <int, int>{};
    var currentLines = <TextLine>[];
    var currentHeight = 0.0;

    void commitPage() {
      if (currentLines.isEmpty) return;
      final pageIndex = pages.length;

      // 计算页面起止位置
      int startPos = 0;
      int endPos = 0;
      for (final line in currentLines) {
        final para = paragraphs[line.paragraphIndex];
        if (startPos == 0 ||
            para.startPosition + line.startOffset < startPos) {
          startPos = para.startPosition + line.startOffset;
        }
        if (para.startPosition + line.endOffset > endPos) {
          endPos = para.startPosition + line.endOffset;
        }
      }

      pages.add(PageSlice(
        lines: List.of(currentLines),
        startPosition: startPos,
        endPosition: endPos,
        chapterIndex: chapterIndex,
      ));

      for (final line in currentLines) {
        lookup.putIfAbsent(line.paragraphIndex, () => pageIndex);
      }

      currentLines = [];
      currentHeight = 0.0;
    }

    for (final paragraph in paragraphs) {
      // 4a. 将段落拆成行
      final lines = _splitParagraphToLines(
        paragraph: paragraph,
        fontSize: fontSize,
        lineHeight: lineHeight,
        maxWidth: availableWidth,
      );

      // 4b. 逐行添加到当前页
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 行实际占用高度 = fontSize * lineHeight（与渲染端一致）
        final lineHeightPx =
            line.isTitle ? titleLineHeightPx : bodyLineHeightPx;
        // 行间距：段内行间距 2px，段尾用 paragraphSpacing
        final isLastLine = line.isLastLineOfParagraph;
        final lineMarginBottom = isLastLine ? paragraphSpacing : 2.0;
        final lineTotalHeight = lineHeightPx + lineMarginBottom;

        // 如果加上这行会超出可用高度，先提交当前页
        if (currentLines.isNotEmpty &&
            currentHeight + lineTotalHeight > availableHeight) {
          commitPage();
        }

        // 如果当前页为空且单行就超高（极端情况），仍然加入
        currentLines.add(line);
        currentHeight += lineTotalHeight;
      }
    }

    // 提交最后一页
    commitPage();

    return ChapterLayout(
      paragraphs: paragraphs,
      pages: pages,
      paragraphPageLookup: lookup,
      chapterIndex: chapterIndex,
      contentHash: content.hashCode,
    );
  }

  /// 将段落拆分为 TextLine 列表
  ///
  /// 核心方法：使用 TextPainter 的 computeLineMetrics 获取行数，
  /// 然后用 getLineBoundary 逐行获取字符范围。
  /// 行文本直接使用 fullText 的子串，在渲染时根据 isFirstLineOfParagraph
  /// 决定是否加缩进前缀，避免偏移映射错误。
  ///
  /// 中文断行优化（v2）：
  /// - 检测"孤字"情况（行尾只剩1个汉字），如果存在则将孤字移到下一行
  /// - 避免中文双字词被拆开（如"长老"拆成"长"+"老"）
  List<TextLine> _splitParagraphToLines({
    required ReaderParagraph paragraph,
    required double fontSize,
    required double lineHeight,
    required double maxWidth,
  }) {
    final isTitle = paragraph.isTitle;
    final effectiveFontSize = isTitle ? fontSize + 4 : fontSize;
    final effectiveLineHeight = isTitle ? 1.45 : lineHeight;
    final fontWeight = isTitle ? FontWeight.w600 : FontWeight.normal;
    final lineHeightPx = effectiveFontSize * effectiveLineHeight;

    // 首行加缩进——与渲染端保持一致
    final fullText =
        isTitle ? paragraph.text : '\u3000\u3000${paragraph.text}';
    final indentLength = isTitle ? 0 : 2; // \u3000\u3000 占2个字符

    // 使用 TextPainter 计算行拆分
    final painter = TextPainter(
      text: TextSpan(
        text: fullText,
        style: TextStyle(
          fontSize: effectiveFontSize,
          height: effectiveLineHeight,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final lineMetrics = painter.computeLineMetrics();
    final rawLines = <_RawLine>[];

    if (lineMetrics.isEmpty || paragraph.text.isEmpty) {
      return [];
    }

    // 逐行获取边界
    int currentOffset = 0;
    final textLength = fullText.length;

    for (int lineIndex = 0; lineIndex < lineMetrics.length; lineIndex++) {
      if (currentOffset >= textLength) break;

      final position = TextPosition(
        offset: currentOffset,
        affinity: TextAffinity.downstream,
      );
      final boundary = painter.getLineBoundary(position);

      final lineStart = boundary.start;
      final lineEnd = boundary.end;

      // 防御：跳过空行
      if (lineStart >= lineEnd || lineEnd <= currentOffset) {
        currentOffset++;
        continue;
      }

      // 从 fullText 中截取本行文本（含缩进前缀）
      final rawLineText =
          fullText.substring(lineStart.clamp(0, textLength), lineEnd.clamp(0, textLength));

      // 跳过纯空白行
      if (rawLineText.trim().isEmpty && lineIndex > 0) {
        currentOffset = lineEnd;
        continue;
      }

      // 计算在原文 paragraph.text 中的偏移
      final originalStart =
          (lineStart - indentLength).clamp(0, paragraph.text.length);
      final originalEnd =
          (lineEnd - indentLength).clamp(0, paragraph.text.length);

      // 行显示文本：去掉缩进前缀部分
      String displayText;
      if (isTitle) {
        displayText = rawLineText;
      } else {
        if (lineIndex == 0) {
          displayText = rawLineText.length > indentLength
              ? rawLineText.substring(indentLength)
              : '';
        } else {
          displayText = rawLineText;
        }
      }

      // 跳过截取后为空的行
      if (displayText.trim().isEmpty && lineIndex > 0) {
        currentOffset = lineEnd;
        continue;
      }

      final isLastLine = lineIndex == lineMetrics.length - 1;

      rawLines.add(_RawLine(
        displayText: displayText,
        originalStart: originalStart,
        originalEnd: originalEnd,
        isFirstLine: lineIndex == 0,
        isLastLine: isLastLine,
      ));

      currentOffset = lineEnd;
    }

    // 中文断行优化：处理孤字（orphan）问题
    // 如果一行末尾只有1个汉字，将它移到下一行开头
    // 这样可以避免"长老"被拆成"长"+"老"等情况
    if (rawLines.length > 1 && !isTitle) {
      for (int i = 0; i < rawLines.length - 1; i++) {
        final current = rawLines[i];
        final next = rawLines[i + 1];

        // 只处理非最后一行
        if (current.isLastLine) continue;

        final text = current.displayText;
        // 检测行尾是否只有1个CJK字符（孤字）
        if (text.length >= 2 && _isCjkChar(text.codeUnitAt(text.length - 1))) {
          // 检查行尾字符前一个字符是否也是CJK
          // 如果是，说明可能是双字词被拆开了
          final prevChar = text.codeUnitAt(text.length - 2);
          if (_isCjkChar(prevChar)) {
            // 检查下一行开头是否也是CJK字符
            // 只有当下一行也有内容时才做合并
            if (next.displayText.isNotEmpty) {
              // 将当前行最后一个字符移到下一行
              final orphanChar = text.substring(text.length - 1);
              final newCurrentText = text.substring(0, text.length - 1);
              final newNextText = orphanChar + next.displayText;

              rawLines[i] = _RawLine(
                displayText: newCurrentText,
                originalStart: current.originalStart,
                originalEnd: current.originalEnd - 1,
                isFirstLine: current.isFirstLine,
                isLastLine: false,
              );
              rawLines[i + 1] = _RawLine(
                displayText: newNextText,
                originalStart: next.originalStart - 1,
                originalEnd: next.originalEnd,
                isFirstLine: next.isFirstLine,
                isLastLine: next.isLastLine,
              );
            }
          }
        }
      }
    }

    // 转换为 TextLine 列表
    final result = <TextLine>[];
    for (int i = 0; i < rawLines.length; i++) {
      final raw = rawLines[i];
      result.add(TextLine(
        paragraphIndex: paragraph.index,
        text: raw.displayText,
        startOffset: raw.originalStart,
        endOffset: raw.originalEnd,
        isTitle: isTitle,
        isFirstLineOfParagraph: raw.isFirstLine,
        isLastLineOfParagraph: raw.isLastLine,
        height: lineHeightPx,
      ));
    }

    // 修正最后一行标记
    if (result.isNotEmpty) {
      result.last = TextLine(
        paragraphIndex: result.last.paragraphIndex,
        text: result.last.text,
        startOffset: result.last.startOffset,
        endOffset: result.last.endOffset,
        isTitle: result.last.isTitle,
        isFirstLineOfParagraph: result.last.isFirstLineOfParagraph,
        isLastLineOfParagraph: true,
        height: result.last.height,
      );
    }

    return result;
  }

  /// 判断是否为CJK字符
  static bool _isCjkChar(int codeUnit) {
    // CJK Unified Ideographs: 4E00-9FFF
    // CJK Unified Ideographs Extension A: 3400-4DBF
    // CJK Compatibility Ideographs: F900-FAFF
    // CJK Radicals Supplement: 2E80-2EFF
    // CJK Symbols and Punctuation: 3000-303F (含中文标点)
    return (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
        (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||
        (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) ||
        (codeUnit >= 0x2E80 && codeUnit <= 0x2EFF);
  }

  /// 将 HTML/混合内容清洗为纯文本段落
  List<ReaderParagraph> _extractParagraphs(
    String content, {
    String? chapterTitle,
  }) {
    final plain = content
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('\r', '');
    final lines = plain
        .split(RegExp(r'\n+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final paragraphs = <ReaderParagraph>[];
    final cleanTitle = (chapterTitle ?? '').trim();
    if (cleanTitle.isNotEmpty) {
      paragraphs.add(ReaderParagraph(
        index: 0,
        text: cleanTitle,
        startPosition: 0,
        endPosition: 0,
        isTitle: true,
      ));
    }

    var start = 0;
    for (var i = 0; i < lines.length; i++) {
      final text = lines[i];
      final end = start + text.length;
      paragraphs.add(ReaderParagraph(
        index: i + (cleanTitle.isNotEmpty ? 1 : 0),
        text: text,
        startPosition: start,
        endPosition: end,
      ));
      start = end + 1;
    }

    return paragraphs;
  }

  /// 根据位置查找页码
  int pageIndexForPosition(List<PageSlice> pages, int position) {
    if (pages.isEmpty) return 0;
    // 特殊值：表示跳到末尾
    if (position >= (1 << 29)) {
      return pages.length - 1;
    }
    for (var i = 0; i < pages.length; i++) {
      if (position <= pages[i].endPosition) {
        return i;
      }
    }
    return pages.length - 1;
  }

  /// 判断是否为 HTML/漫画内容
  static bool isHtmlContent(String content) {
    return RegExp(
      r'<\s*(img|p|div|br|a|span|table|video|source)',
      caseSensitive: false,
    ).hasMatch(content);
  }
}

/// 内部使用的行数据（用于断行优化处理）
class _RawLine {
  final String displayText;
  final int originalStart;
  final int originalEnd;
  final bool isFirstLine;
  final bool isLastLine;

  _RawLine({
    required this.displayText,
    required this.originalStart,
    required this.originalEnd,
    required this.isFirstLine,
    required this.isLastLine,
  });
}
