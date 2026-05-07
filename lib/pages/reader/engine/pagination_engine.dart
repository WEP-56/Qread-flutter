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

class PaginationEngine {
  /// 页面布局常量
  static const double horizontalPadding = 24.0;
  static const double topPadding = 18.0;
  static const double bottomPadding = 10.0;
  static const double chapterHeaderHeight = 30.0;
  static const double footerHeight = 22.0;
  static const double headerBottomSpacing = 14.0;
  static const double lineSpacing = 10.0;
  static const double paragraphSpacing = 10.0;

  /// 计算章节的完整分页布局
  ///
  /// [content] 章节正文
  /// [chapterTitle] 章节标题
  /// [chapterIndex] 章节索引
  /// [fontSize] 字号
  /// [lineHeight] 行高倍率
  /// [viewportSize] 视口尺寸
  /// [safeTop] 安全区顶部
  /// [safeBottom] 安全区底部
  /// [targetPosition] 目标阅读位置（字符偏移），用于确定初始页码
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
    final availableHeight = viewportSize.height -
        safeTop -
        safeBottom -
        topPadding -
        bottomPadding -
        chapterHeaderHeight -
        footerHeight -
        headerBottomSpacing;

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
        final lineTotalHeight = line.height + lineSpacing;

        // 如果加上这行会超出可用高度，先提交当前页
        if (currentLines.isNotEmpty &&
            currentHeight + lineTotalHeight > availableHeight) {
          commitPage();
        }

        // 如果当前页为空且单行就超高（极端情况），仍然加入
        currentLines.add(line);
        currentHeight += lineTotalHeight;
      }

      // 段落间距（非标题段落之间）
      if (!paragraph.isTitle) {
        currentHeight += paragraphSpacing - lineSpacing;
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
  /// 核心方法：使用 TextPainter 获取文本的真实行拆分结果，
  /// 每行带位置信息，实现"段落自然跨页"。
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

    // 首行加缩进
    final fullText =
        isTitle ? paragraph.text : '\u3000\u3000${paragraph.text}';

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
    final result = <TextLine>[];

    if (lineMetrics.isEmpty || paragraph.text.isEmpty) {
      return result;
    }

    // 通过 getLineBoundary 逐行获取字符范围
    int currentOffset = 0;
    final textLength = fullText.length;
    final indentLength = isTitle ? 0 : 2; // \u3000\u3000 占2个字符

    for (int lineIndex = 0; lineIndex < lineMetrics.length; lineIndex++) {
      if (currentOffset >= textLength) break;

      final position = TextPosition(offset: currentOffset);
      final boundary = painter.getLineBoundary(position);

      final lineStart = boundary.start;
      final lineEnd = boundary.end.clamp(0, textLength);

      if (lineStart >= lineEnd) break;

      // 计算在原文中的偏移（去掉缩进前缀的偏移量）
      int effectiveOriginalStart;
      int effectiveOriginalEnd;

      if (isTitle) {
        effectiveOriginalStart = lineStart;
        effectiveOriginalEnd = lineEnd;
      } else {
        // 有缩进前缀，需要减去缩进长度
        effectiveOriginalStart =
            (lineStart - indentLength).clamp(0, paragraph.text.length);
        effectiveOriginalEnd =
            (lineEnd - indentLength).clamp(0, paragraph.text.length);
      }

      // 跳过纯缩进行（不应发生，但防御性处理）
      if (effectiveOriginalStart >= effectiveOriginalEnd &&
          lineIndex == 0 &&
          !isTitle) {
        currentOffset = lineEnd;
        continue;
      }

      final lineText = paragraph.text.substring(
        effectiveOriginalStart.clamp(0, paragraph.text.length),
        effectiveOriginalEnd.clamp(0, paragraph.text.length),
      );

      if (lineText.trimLeft().isEmpty && lineIndex > 0) {
        currentOffset = lineEnd;
        continue;
      }

      result.add(TextLine(
        paragraphIndex: paragraph.index,
        text: lineText,
        startOffset: effectiveOriginalStart,
        endOffset: effectiveOriginalEnd,
        isTitle: isTitle,
        isFirstLineOfParagraph: lineIndex == 0,
        isLastLineOfParagraph: lineIndex == lineMetrics.length - 1,
        height: lineHeightPx,
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
