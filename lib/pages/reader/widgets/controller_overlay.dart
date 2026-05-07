import 'package:flutter/material.dart';

import '../../../services/tts_service.dart';

/// 阅读器控制面板覆盖层 v2
///
/// 按 controller.md 文档拆为四层：
/// - TopInfoBar：返回、书名/章节/来源、刷新、更多
/// - FloatingCapsule：自动翻页/朗读/主题切换（普通/TTS/自动翻页三模式）
/// - ProgressStrip：上一章、章节滑杆、下一章
/// - BottomActionBar：目录、设置

// ============================================================
// 数据收口对象
// ============================================================

/// 胶囊模式枚举
enum ControllerCapsuleMode { normal, tts, autoPage }

/// 控制器视图数据——所有展示所需字段
class ReaderControllerViewData {
  final String bookName;
  final String chapterTitle;
  final String sourceName;
  final bool hasBookmark;
  final bool replaceRuleEnabled;
  final String themeName;
  final ControllerCapsuleMode capsuleMode;
  final TtsState ttsState;
  final double ttsRate;
  final double autoPageInterval;
  final int chapterIndex;
  final int totalChapters;
  final double? chapterSliderValue;
  final int ttsParagraphIndex;
  final int totalParagraphs;

  const ReaderControllerViewData({
    required this.bookName,
    required this.chapterTitle,
    required this.sourceName,
    required this.hasBookmark,
    required this.replaceRuleEnabled,
    required this.themeName,
    required this.capsuleMode,
    required this.ttsState,
    required this.ttsRate,
    required this.autoPageInterval,
    required this.chapterIndex,
    required this.totalChapters,
    this.chapterSliderValue,
    this.ttsParagraphIndex = -1,
    this.totalParagraphs = 0,
  });
}

/// 控制器回调——所有用户操作
class ReaderControllerCallbacks {
  final VoidCallback onBack;
  final VoidCallback onShowMore;
  final VoidCallback onRefresh;
  final VoidCallback onToggleBookmark;
  final VoidCallback onStartAutoPage;
  final VoidCallback onStartTts;
  final VoidCallback onToggleTheme;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<double> onChapterSliderChanged;
  final ValueChanged<double> onChapterSliderEnd;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowSettings;
  final VoidCallback onStopTts;
  final VoidCallback onPauseTts;
  final VoidCallback onResumeTts;
  final VoidCallback onShowTtsTimer;
  final VoidCallback onShowTtsSettings;
  final VoidCallback onStopAutoPage;
  final VoidCallback onDecreaseAutoPageInterval;
  final VoidCallback onIncreaseAutoPageInterval;

  const ReaderControllerCallbacks({
    required this.onBack,
    required this.onShowMore,
    required this.onRefresh,
    required this.onToggleBookmark,
    required this.onStartAutoPage,
    required this.onStartTts,
    required this.onToggleTheme,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onChapterSliderChanged,
    required this.onChapterSliderEnd,
    required this.onShowChapterList,
    required this.onShowSettings,
    required this.onStopTts,
    required this.onPauseTts,
    required this.onResumeTts,
    required this.onShowTtsTimer,
    required this.onShowTtsSettings,
    required this.onStopAutoPage,
    required this.onDecreaseAutoPageInterval,
    required this.onIncreaseAutoPageInterval,
  });
}

// ============================================================
// 主组件
// ============================================================

class ControllerOverlay extends StatelessWidget {
  final ReaderControllerViewData data;
  final ReaderControllerCallbacks callbacks;

  const ControllerOverlay({
    Key? key,
    required this.data,
    required this.callbacks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 顶部信息栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TopInfoBar(data: data, callbacks: callbacks),
        ),

        // 中部悬浮胶囊
        Positioned(
          left: 0,
          right: 0,
          bottom: 136,
          child: _FloatingCapsule(data: data, callbacks: callbacks),
        ),

        // 底部区域：进度条 + 功能栏（几乎不透明）
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              color: Colors.black.withOpacity(0.88),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProgressStrip(data: data, callbacks: callbacks),
                  const SizedBox(height: 8),
                  _BottomActionBar(data: data, callbacks: callbacks),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 顶部信息栏
// ============================================================

class _TopInfoBar extends StatelessWidget {
  final ReaderControllerViewData data;
  final ReaderControllerCallbacks callbacks;

  const _TopInfoBar({required this.data, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
        ),
        child: Row(
          children: [
            // 返回
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              onPressed: callbacks.onBack,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            // 书名 / 章节 / 来源
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.bookName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${data.chapterTitle}  ·  ${data.sourceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            // 刷新
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: data.replaceRuleEnabled
                    ? const Color(0xFF00A88F)
                    : Colors.white,
                size: 20,
              ),
              onPressed: callbacks.onRefresh,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            // 更多
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
              onPressed: callbacks.onShowMore,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 中部悬浮胶囊
// ============================================================

class _FloatingCapsule extends StatelessWidget {
  final ReaderControllerViewData data;
  final ReaderControllerCallbacks callbacks;

  const _FloatingCapsule({required this.data, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(data.capsuleMode),
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildCapsuleContent(),
        ),
      ),
    );
  }

  Widget _buildCapsuleContent() {
    switch (data.capsuleMode) {
      case ControllerCapsuleMode.tts:
        return _buildTtsCapsule();
      case ControllerCapsuleMode.autoPage:
        return _buildAutoPageCapsule();
      case ControllerCapsuleMode.normal:
      return _buildNormalCapsule();
    }
  }

  /// 普通模式：自动翻页 / 朗读 / 深浅切换
  Widget _buildNormalCapsule() {
    final isLight = data.themeName == 'light';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CapsuleButton(
          icon: Icons.auto_awesome_motion_outlined,
          label: '自动',
          onTap: callbacks.onStartAutoPage,
        ),
        _CapsuleDivider(),
        _CapsuleButton(
          icon: Icons.play_circle_outline,
          label: '朗读',
          onTap: callbacks.onStartTts,
        ),
        _CapsuleDivider(),
        _CapsuleButton(
          icon: isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          label: isLight ? '深色' : '浅色',
          onTap: callbacks.onToggleTheme,
        ),
      ],
    );
  }

  /// TTS 模式：停止 / 暂停继续
  Widget _buildTtsCapsule() {
    final isPaused = data.ttsState == TtsState.paused;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CapsuleButton(
          icon: Icons.stop_circle_outlined,
          label: '停止',
          onTap: callbacks.onStopTts,
        ),
        _CapsuleDivider(),
        _CapsuleButton(
          icon: isPaused ? Icons.play_circle_filled : Icons.pause_circle_filled,
          label: isPaused ? '继续' : '暂停',
          onTap: isPaused ? callbacks.onResumeTts : callbacks.onPauseTts,
        ),
      ],
    );
  }

  /// 自动翻页模式：减速 / 秒数 / 加速 / 停止
  Widget _buildAutoPageCapsule() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CapsuleButton(
          icon: Icons.remove,
          label: '减速',
          onTap: callbacks.onDecreaseAutoPageInterval,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${data.autoPageInterval.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                '秒/页',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
        _CapsuleButton(
          icon: Icons.add,
          label: '加速',
          onTap: callbacks.onIncreaseAutoPageInterval,
        ),
        _CapsuleDivider(),
        _CapsuleButton(
          icon: Icons.stop_circle_outlined,
          label: '停止',
          onTap: callbacks.onStopAutoPage,
        ),
      ],
    );
  }
}

// ============================================================
// 进度条行
// ============================================================

class _ProgressStrip extends StatelessWidget {
  final ReaderControllerViewData data;
  final ReaderControllerCallbacks callbacks;

  const _ProgressStrip({required this.data, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // 上一章
          SizedBox(
            width: 56,
            child: TextButton(
              onPressed: data.chapterIndex > 0 ? callbacks.onPrevChapter : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('上一章', style: TextStyle(fontSize: 12)),
            ),
          ),
          // 滑杆
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: const Color(0xFF00A88F),
                thumbColor: const Color(0xFF00A88F),
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
              ),
              child: Slider(
                value: (data.chapterSliderValue ?? data.chapterIndex.toDouble())
                    .clamp(0, (data.totalChapters - 1).toDouble()),
                min: 0,
                max: data.totalChapters <= 1
                    ? 1
                    : (data.totalChapters - 1).toDouble(),
                onChanged: callbacks.onChapterSliderChanged,
                onChangeEnd: callbacks.onChapterSliderEnd,
              ),
            ),
          ),
          // 下一章
          SizedBox(
            width: 56,
            child: TextButton(
              onPressed: data.chapterIndex < data.totalChapters - 1
                  ? callbacks.onNextChapter
                  : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('下一章', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 底部功能栏
// ============================================================

class _BottomActionBar extends StatelessWidget {
  final ReaderControllerViewData data;
  final ReaderControllerCallbacks callbacks;

  const _BottomActionBar({required this.data, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    // TTS 模式下显示 TTS 专用底部
    if (data.capsuleMode == ControllerCapsuleMode.tts) {
      return _buildTtsBottom();
    }
    return _buildNormalBottom();
  }

  Widget _buildNormalBottom() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BottomEntry(
            icon: Icons.list_alt_outlined,
            label: '目录',
            onTap: callbacks.onShowChapterList,
          ),
          _BottomEntry(
            icon: Icons.tune_outlined,
            label: '设置',
            onTap: callbacks.onShowSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildTtsBottom() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BottomEntry(
            icon: Icons.timer_outlined,
            label: '定时',
            onTap: callbacks.onShowTtsTimer,
          ),
          _BottomEntry(
            icon: Icons.list_alt_outlined,
            label: '目录',
            onTap: callbacks.onShowChapterList,
          ),
          _BottomEntry(
            icon: Icons.settings_voice_outlined,
            label: '听书设置',
            onTap: callbacks.onShowTtsSettings,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 通用小组件
// ============================================================

/// 胶囊内按钮
class _CapsuleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CapsuleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF555555), size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// 胶囊内分隔线
class _CapsuleDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFE0E0E0),
    );
  }
}

/// 底部功能入口
class _BottomEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
