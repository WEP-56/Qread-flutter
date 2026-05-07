import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'content_renderer.dart';
import 'reader_theme.dart';

/// 翻页模式阅读器
///
/// 使用 PageView.builder 渲染预计算的页面。
/// 支持跨章节页面的无缝衔接。

class PagedReader extends StatelessWidget {
  final List<PageSlice> pages;
  final PageController pageController;
  final ReaderTheme theme;
  final double fontSize;
  final double lineHeight;
  final String chapterTitle;
  final int currentPage;
  final int totalPages;
  final int ttsParagraphIndex;
  final String timeLabel;
  final String batteryLabel;
  final ValueChanged<int> onPageChanged;
  final bool showTopBar;
  final bool showBottomBar;
  final bool showPageNumber;

  const PagedReader({
    Key? key,
    required this.pages,
    required this.pageController,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.chapterTitle,
    required this.currentPage,
    required this.totalPages,
    this.ttsParagraphIndex = -1,
    required this.timeLabel,
    required this.batteryLabel,
    required this.onPageChanged,
    this.showTopBar = true,
    this.showBottomBar = true,
    this.showPageNumber = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: pageController,
      itemCount: pages.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final page = pages[index];
        final currentDisplay = index + 1;

        return ContentRenderer.buildPage(
          page: page,
          theme: theme,
          fontSize: fontSize,
          lineHeight: lineHeight,
          chapterTitle: chapterTitle,
          pageIndicator: '$currentDisplay/$totalPages',
          timeLabel: timeLabel,
          batteryLabel: batteryLabel,
          ttsParagraphIndex: ttsParagraphIndex,
          showTopBar: showTopBar,
          showBottomBar: showBottomBar,
          showPageNumber: showPageNumber,
        );
      },
    );
  }
}
