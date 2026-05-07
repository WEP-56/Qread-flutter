import 'package:flutter/material.dart';

import '../../../providers/reader_provider.dart';
import '../../../services/tts_service.dart';

/// 阅读器控制面板覆盖层
///
/// 将原 reader_page.dart 中散布的 _buildControllerChrome /
/// _buildNormalController / _buildTtsController / _buildAutoPageOverlay
/// 等方法集中到此组件。

class ControllerOverlay extends StatelessWidget {
  final ReaderProvider provider;
  final String bookName;
  final String chapterTitle;
  final String sourceName;
  final bool hasBookmark;
  final bool useReplaceRule;
  final bool isTtsActive;
  final TtsState ttsState;
  final double ttsRate;
  final bool autoPageRunning;
  final double autoPageInterval;
  final int chapterIndex;
  final int totalChapters;
  final double? chapterSliderValue;
  final int ttsParagraphIndex;
  final int totalParagraphs;

  final VoidCallback onBack;
  final VoidCallback onToggleBookmark;
  final VoidCallback onShowChangeType;
  final VoidCallback onStartAutoPage;
  final VoidCallback onStartTts;
  final VoidCallback onToggleTheme;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<double> onChapterSliderChanged;
  final ValueChanged<double> onChapterSliderEnd;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowSettings;
  final VoidCallback onShowBookmarks;
  final VoidCallback onSwitchSource;
  final VoidCallback onApplyReplaceRules;

  // TTS 控件
  final VoidCallback onStopTts;
  final VoidCallback onPauseTts;
  final VoidCallback onResumeTts;
  final VoidCallback onShowTtsTimer;
  final VoidCallback onShowTtsSettings;

  // 自动翻页控件
  final VoidCallback onStopAutoPage;
  final VoidCallback onDecreaseAutoPageInterval;
  final VoidCallback onIncreaseAutoPageInterval;

  const ControllerOverlay({
    Key? key,
    required this.provider,
    required this.bookName,
    required this.chapterTitle,
    required this.sourceName,
    required this.hasBookmark,
    required this.useReplaceRule,
    required this.isTtsActive,
    required this.ttsState,
    required this.ttsRate,
    required this.autoPageRunning,
    required this.autoPageInterval,
    required this.chapterIndex,
    required this.totalChapters,
    this.chapterSliderValue,
    this.ttsParagraphIndex = -1,
    this.totalParagraphs = 0,
    required this.onBack,
    required this.onToggleBookmark,
    required this.onShowChangeType,
    required this.onStartAutoPage,
    required this.onStartTts,
    required this.onToggleTheme,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onChapterSliderChanged,
    required this.onChapterSliderEnd,
    required this.onShowChapterList,
    required this.onShowSettings,
    required this.onShowBookmarks,
    required this.onSwitchSource,
    required this.onApplyReplaceRules,
    required this.onStopTts,
    required this.onPauseTts,
    required this.onResumeTts,
    required this.onShowTtsTimer,
    required this.onShowTtsSettings,
    required this.onStopAutoPage,
    required this.onDecreaseAutoPageInterval,
    required this.onIncreaseAutoPageInterval,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 顶部栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: onBack,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      hasBookmark ? Icons.bookmark : Icons.bookmark_border,
                      color: hasBookmark
                          ? const Color(0xFF00A88F)
                          : Colors.white,
                    ),
                    onPressed: onToggleBookmark,
                  ),
                  PopupMenuButton<String>(
                    color: const Color(0xFF1B232B),
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (action) {
                      if (action == 'type') onShowChangeType();
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'type',
                        child: Text('更改类型',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 底部控制栏
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: autoPageRunning
                  ? _buildAutoPageOverlay()
                  : isTtsActive || ttsState == TtsState.paused
                      ? _buildTtsController()
                      : _buildNormalController(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalController() {
    return Container(
      key: const ValueKey('normal-controller'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xE61A222B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControllerInfo(),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAction(
                icon: Icons.auto_awesome_motion_outlined,
                label: '自动翻页',
                onTap: onStartAutoPage,
              ),
              _buildAction(
                icon: Icons.play_circle_outline,
                label: '朗读',
                onTap: onStartTts,
              ),
              _buildAction(
                icon: useReplaceRule
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: useReplaceRule ? '浅色' : '深色',
                onTap: onToggleTheme,
              ),
              const SizedBox(width: 72),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton(
                onPressed: chapterIndex > 0 ? onPrevChapter : null,
                child: const Text('上一章'),
              ),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 2,
                    thumbShape:
                        RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: (chapterSliderValue ?? chapterIndex.toDouble())
                        .clamp(0, (totalChapters - 1).toDouble()),
                    min: 0,
                    max: totalChapters <= 1
                        ? 1
                        : (totalChapters - 1).toDouble(),
                    onChanged: onChapterSliderChanged,
                    onChangeEnd: onChapterSliderEnd,
                  ),
                ),
              ),
              TextButton(
                onPressed: chapterIndex < totalChapters - 1
                    ? onNextChapter
                    : null,
                child: const Text('下一章'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.list_alt_outlined,
                  label: '目录',
                  onTap: onShowChapterList,
                ),
              ),
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.tune_outlined,
                  label: '设置',
                  onTap: onShowSettings,
                ),
              ),
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.bookmark_outline,
                  label: '书签',
                  onTap: onShowBookmarks,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTtsController() {
    final total = totalParagraphs <= 0 ? 1 : totalParagraphs;
    final current =
        ttsParagraphIndex < 0 ? 0 : (ttsParagraphIndex + 1).clamp(1, total);
    return Container(
      key: const ValueKey('tts-controller'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xE61A222B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControllerInfo(),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: total <= 0 ? 0 : (current / total).clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.12),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF00A88F)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '段落 $current / $total',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '语速 ${ttsRate.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onStopTts,
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed:
                    ttsState == TtsState.paused ? onResumeTts : onPauseTts,
                icon: Icon(
                  ttsState == TtsState.paused
                      ? Icons.play_circle_fill
                      : Icons.pause_circle_filled,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.timer_outlined,
                  label: '定时',
                  onTap: onShowTtsTimer,
                ),
              ),
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.list_alt_outlined,
                  label: '目录',
                  onTap: onShowChapterList,
                ),
              ),
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.settings_voice_outlined,
                  label: '听书设置',
                  onTap: onShowTtsSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoPageOverlay() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xD91A222B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onDecreaseAutoPageInterval,
            icon: const Icon(Icons.remove, color: Colors.white),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '自动翻页',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${autoPageInterval.toStringAsFixed(0)} 秒',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onIncreaseAutoPageInterval,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onStopAutoPage,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('停止'),
            style:
                TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildControllerInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bookName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                sourceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          splashRadius: 20,
          onPressed: onSwitchSource,
          icon: const Icon(Icons.travel_explore_outlined,
              color: Colors.white),
        ),
        IconButton(
          splashRadius: 20,
          onPressed: onApplyReplaceRules,
          icon: Icon(
            Icons.refresh,
            color: useReplaceRule
                ? const Color(0xFF00A88F)
                : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetEntry({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
