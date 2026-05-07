import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'content_renderer.dart';
import 'reader_theme.dart';

/// 滚动模式阅读器

class ScrollReader extends StatelessWidget {
  final List<ReaderParagraph> paragraphs;
  final ScrollController scrollController;
  final ReaderTheme theme;
  final double fontSize;
  final double lineHeight;
  final String chapterTitle;
  final int ttsParagraphIndex;
  final String pageIndicator;
  final String timeLabel;
  final String batteryLabel;

  const ScrollReader({
    Key? key,
    required this.paragraphs,
    required this.scrollController,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.chapterTitle,
    this.ttsParagraphIndex = -1,
    required this.pageIndicator,
    required this.timeLabel,
    required this.batteryLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (paragraphs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentRenderer.buildParagraph(
            paragraph: ReaderParagraph(
              index: -1,
              text: chapterTitle,
              startPosition: 0,
              endPosition: 0,
              isTitle: true,
            ),
            theme: theme,
            fontSize: fontSize,
            lineHeight: lineHeight,
            ttsParagraphIndex: ttsParagraphIndex,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.zero,
              itemCount: paragraphs.length,
              itemBuilder: (context, index) {
                return ContentRenderer.buildParagraph(
                  paragraph: paragraphs[index],
                  theme: theme,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                  ttsParagraphIndex: ttsParagraphIndex,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFooter() {
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
