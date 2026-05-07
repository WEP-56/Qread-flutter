import 'package:flutter/material.dart';

import 'models.dart';

/// 行级分页引擎 v3
///
/// 核心设计参照 legado 的 TextChapterLayout：
/// 1. 将段落文本通过 TextPainter 拆成行
/// 2. 逐行累加高度，当累计高度 + 下一行高度 > 可用高度时换页
/// 3. 段落自然在行边界处跨页，无需段中截断的特殊处理
///
/// v3 修复：
/// - 精确测量章节头/页脚高度，消除 32px 溢出
/// - 移除孤字检测逻辑（过于激进导致段落异常分段）
/// - 使用 TextPainter 实测行高而非 fontSize*lineHeight 估算
/// - 增加安全余量确保内容不溢出

class PaginationEngine {
  /// 页面布局常量
  static const double horizontalPadding = 24.0;
  static const double topPadding = 18.0;
  static const double bottomPadding = 10.0;
  static const double headerBottomSpacing = 14.0;
  static const double paragraphSpacing = 10.0;
  static const double lineSpacing = 2.0;

  /// 安全余量：防止浮点累积误差导致的溢出
  static const double safetyMargin = 4.0;

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

    // 2. 计算可用区域
    final availableWidth = viewportSize.width - horizontalPadding * 2;

    // 用 TextPainter 精确测量章节头和页脚高度
    final headerHeight = _measureHeaderHeight(chapterTitle ?? '', fontSize);
    final footerHeight = _measureFooterHeight(fontSize);

    final availableHeight = viewportSize.height -
        safeTop -
        safeBottom -
        topPadding -
        bottomPadding -
        headerHeight -
        footerHeight -
        headerBottomSpacing -
        safetyMargin;

    // 3. 逐段落 → 逐行 → 分页
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
      // 3a. 将段落拆成行
      final lines = _splitParagraphToLines(
        paragraph: paragraph,
        fontSize: fontSize,
        lineHeight: lineHeight,
        maxWidth: availableWidth,
      );

      // 3b. 逐行添加到当前页
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 行实际占用高度 = line.height（TextPainter 实测） + 间距
        final isLastLine = line.isLastLineOfParagraph;
        final lineMarginBottom = isLastLine ? paragraphSpacing : lineSpacing;
        final lineTotalHeight = line.height + lineMarginBottom;

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

  /// 用 TextPainter 精确测量章节头高度
  double _measureHeaderHeight(String chapterTitle, double fontSize) {
    if (chapterTitle.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(
        text: chapterTitle,
        style: TextStyle(fontSize: 12, height: 1.2),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    return painter.height;
  }

  /// 用 TextPainter 精确测量页脚高度
  double _measureFooterHeight(double fontSize) {
    // 页脚包含时间和电池信息，字号 11
    final painter = TextPainter(
      text: TextSpan(
        text: '00:00  1/1  100%',
        style: TextStyle(fontSize: 11, height: 1.2),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    // 加上电池图标的高度（约 13px）
    return painter.height > 13 ? painter.height : 13.0;
  }

  /// 将段落拆分为 TextLine 列表
  ///
  /// 核心方法：使用 TextPainter 的 computeLineMetrics 获取行数，
  /// 然后用 getLineBoundary 逐行获取字符范围。
  /// 行文本直接使用 fullText 的子串，在渲染时根据 isFirstLineOfParagraph
  /// 决定是否加缩进前缀，避免偏移映射错误。
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

    if (lineMetrics.isEmpty || paragraph.text.isEmpty) {
      return [];
    }

    // 逐行获取边界
    int currentOffset = 0;
    final textLength = fullText.length;
    final result = <TextLine>[];

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

      // 使用 TextPainter 实测的行高（更精确）
      final measuredHeight = lineMetrics[lineIndex].height;

      result.add(TextLine(
        paragraphIndex: paragraph.index,
        text: displayText,
        startOffset: originalStart,
        endOffset: originalEnd,
        isTitle: isTitle,
        isFirstLineOfParagraph: lineIndex == 0,
        isLastLineOfParagraph: isLastLine,
        height: measuredHeight,
      ));

      currentOffset = lineEnd;
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
