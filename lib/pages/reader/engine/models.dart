/// 阅读器分页引擎数据模型
///
/// 层级结构：ChapterLayout → PageSlice → TextLine
/// 与旧版 Block 模型不同，新版采用行级分页，段落自然在行边界处跨页。

/// 段落（源文本级别，不跨页拆分）
class ReaderParagraph {
  const ReaderParagraph({
    required this.index,
    required this.text,
    required this.startPosition,
    required this.endPosition,
    this.isTitle = false,
  });

  final int index;
  final String text;
  final int startPosition;
  final int endPosition;
  final bool isTitle;
}

/// 单行文本（排版引擎输出，段落被拆为多行）
class TextLine {
  const TextLine({
    required this.paragraphIndex,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.isTitle,
    required this.isFirstLineOfParagraph,
    required this.height,
    this.isLastLineOfParagraph = false,
  });

  /// 所属段落的索引
  final int paragraphIndex;

  /// 本行显示的文本内容
  final String text;

  /// 在段落原文中的起始字符偏移
  final int startOffset;

  /// 在段落原文中的结束字符偏移
  final int endOffset;

  /// 是否标题行
  final bool isTitle;

  /// 是否段落首行（需要首行缩进）
  final bool isFirstLineOfParagraph;

  /// 是否段落末行
  final bool isLastLineOfParagraph;

  /// 行高（fontSize * lineHeight）
  final double height;
}

/// 页面（由多行 TextLine 组成）
class PageSlice {
  const PageSlice({
    required this.lines,
    required this.startPosition,
    required this.endPosition,
    required this.chapterIndex,
  });

  /// 页面内所有行
  final List<TextLine> lines;

  /// 章节内起始位置（字符偏移）
  final int startPosition;

  /// 章节内结束位置（字符偏移）
  final int endPosition;

  /// 所属章节索引
  final int chapterIndex;

  /// 段落 → 首次出现的页码 映射（用于 TTS 定位等）
  Map<int, int> buildParagraphLookup() {
    final lookup = <int, int>{};
    for (final line in lines) {
      lookup.putIfAbsent(line.paragraphIndex, () => 0);
    }
    return lookup;
  }
}

/// 章节排版结果
class ChapterLayout {
  const ChapterLayout({
    required this.paragraphs,
    required this.pages,
    required this.paragraphPageLookup,
    required this.chapterIndex,
    required this.contentHash,
  });

  final List<ReaderParagraph> paragraphs;
  final List<PageSlice> pages;
  final Map<int, int> paragraphPageLookup;
  final int chapterIndex;
  final int contentHash;

  /// 生成缓存 key
  static String cacheKey(
    int chapterIndex,
    int contentHash,
    double fontSize,
    double lineHeight,
    double width,
    double height,
    String pageMode,
  ) {
    return '$chapterIndex|$contentHash|'
        '${fontSize.toStringAsFixed(2)}|'
        '${lineHeight.toStringAsFixed(2)}|'
        '${width.toStringAsFixed(1)}|'
        '${height.toStringAsFixed(1)}|'
        '$pageMode';
  }
}
