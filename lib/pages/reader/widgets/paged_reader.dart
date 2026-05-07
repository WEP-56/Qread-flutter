import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../engine/models.dart';
import '../reader_state.dart';
import 'content_renderer.dart';
import 'reader_theme.dart';

class PagedReaderController extends ChangeNotifier {
  _PagedReaderCommand? _command;

  void animateToPage(int page) {
    _command = _PagedReaderCommand(page: page, animated: true);
    notifyListeners();
  }

  void jumpToPage(int page) {
    _command = _PagedReaderCommand(page: page, animated: false);
    notifyListeners();
  }

  _PagedReaderCommand? _takeCommand() {
    final command = _command;
    _command = null;
    return command;
  }
}

class _PagedReaderCommand {
  final int page;
  final bool animated;

  const _PagedReaderCommand({
    required this.page,
    required this.animated,
  });
}

/// 翻页模式阅读器
class PagedReader extends StatefulWidget {
  final List<PageSlice> pages;
  final PageController pageController;
  final PagedReaderController manualController;
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
  final double horizontalPadding;
  final double topPadding;
  final double paragraphSpacing;
  final double firstLineIndent;
  final PageAnimType animType;

  const PagedReader({
    Key? key,
    required this.pages,
    required this.pageController,
    required this.manualController,
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
    this.horizontalPadding = 24.0,
    this.topPadding = 18.0,
    this.paragraphSpacing = 10.0,
    this.firstLineIndent = 2.0,
    this.animType = PageAnimType.cover,
  }) : super(key: key);

  @override
  State<PagedReader> createState() => _PagedReaderState();
}

class _PagedReaderState extends State<PagedReader>
    with SingleTickerProviderStateMixin {
  static const _dragTrigger = 8.0;
  static const _commitThreshold = 0.35;
  static const _commitVelocity = 320.0;

  late final AnimationController _animationController;
  final GlobalKey _captureKey = GlobalKey();

  double _animationFrom = 0.0;
  double _animationTo = 0.0;
  bool _commitOnAnimationEnd = false;

  int _basePage = 0;
  int? _targetPage;
  int _turnDirection = 0;
  double _progress = 0.0;
  double _dragStartX = 0.0;
  bool _dragging = false;
  ui.Image? _capturedCurrentImage;
  Object? _captureSignature;
  Object? _capturedImageSignature;
  bool _captureScheduled = false;

  bool get _usesManualPaging =>
      widget.animType == PageAnimType.cover ||
      widget.animType == PageAnimType.simulation ||
      widget.animType == PageAnimType.none;

  bool get _isTurning =>
      _targetPage != null &&
      (_dragging || _animationController.isAnimating || _progress > 0.0);

  @override
  void initState() {
    super.initState();
    _basePage = widget.currentPage;
    _animationController = AnimationController(vsync: this)
      ..addListener(_handleAnimationTick)
      ..addStatusListener(_handleAnimationStatus);
    widget.manualController.addListener(_handleManualCommand);
  }

  @override
  void didUpdateWidget(covariant PagedReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manualController != widget.manualController) {
      oldWidget.manualController.removeListener(_handleManualCommand);
      widget.manualController.addListener(_handleManualCommand);
    }
    if (!_isTurning) {
      _basePage = widget.currentPage;
    }
  }

  @override
  void dispose() {
    widget.manualController.removeListener(_handleManualCommand);
    _animationController.dispose();
    _capturedCurrentImage?.dispose();
    super.dispose();
  }

  void _handleManualCommand() {
    final command = widget.manualController._takeCommand();
    if (command == null || !_usesManualPaging) return;
    if (command.page == widget.currentPage) return;

    final currentPage = widget.currentPage;
    final pageDelta = command.page - currentPage;
    if (pageDelta.abs() != 1) {
      widget.onPageChanged(command.page.clamp(0, widget.pages.length - 1));
      return;
    }

    _animationController.stop();
    _dragging = false;
    _basePage = currentPage;
    _targetPage = command.page;
    _turnDirection = pageDelta > 0 ? 1 : -1;
    _progress = command.animated ? 0.0 : 1.0;

    if (!command.animated) {
      widget.onPageChanged(command.page);
      _resetTurnState();
      return;
    }

    _startAnimation(1.0, commit: true);
  }

  Object _buildCaptureSignature() {
    return Object.hash(
      widget.currentPage,
      widget.chapterTitle,
      widget.theme.name,
      widget.fontSize,
      widget.lineHeight,
      widget.showTopBar,
      widget.showBottomBar,
      widget.showPageNumber,
    );
  }

  void _scheduleCaptureIfNeeded() {
    if (widget.animType != PageAnimType.simulation || _isTurning) return;
    final signature = _buildCaptureSignature();
    if (_capturedCurrentImage != null && _captureSignature == signature) return;
    if (_capturedImageSignature == signature && _capturedCurrentImage != null) {
      return;
    }
    _captureSignature = signature;
    if (_captureScheduled) return;
    _captureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      _captureCurrentPageImage(signature);
    });
  }

  Future<void> _captureCurrentPageImage(Object signature) async {
    if (!mounted ||
        widget.animType != PageAnimType.simulation ||
        _isTurning ||
        _captureSignature != signature) {
      return;
    }
    final context = _captureKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary ||
        renderObject.debugNeedsPaint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _captureCurrentPageImage(signature);
      });
      return;
    }

    final pixelRatio = MediaQuery.of(this.context).devicePixelRatio.clamp(
          1.0,
          2.2,
        );
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    if (!mounted || _captureSignature != signature) {
      image.dispose();
      return;
    }

    final oldImage = _capturedCurrentImage;
    setState(() {
      _capturedCurrentImage = image;
      _capturedImageSignature = signature;
    });
    oldImage?.dispose();
  }

  void _handleAnimationTick() {
    final eased = Curves.easeOutCubic.transform(_animationController.value);
    setState(() {
      _progress =
          lerpDouble(_animationFrom, _animationTo, eased) ?? _animationTo;
    });
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final targetPage = _targetPage;
    final shouldCommit = _commitOnAnimationEnd && targetPage != null;
    _commitOnAnimationEnd = false;
    if (shouldCommit) {
      widget.onPageChanged(targetPage);
    }
    _resetTurnState();
  }

  void _resetTurnState() {
    if (!mounted) return;
    setState(() {
      _progress = 0.0;
      _turnDirection = 0;
      _targetPage = null;
      _dragging = false;
      _basePage = widget.currentPage;
    });
  }

  void _startAnimation(double target, {required bool commit}) {
    _animationFrom = _progress;
    _animationTo = target;
    _commitOnAnimationEnd = commit;
    final distance = (_animationTo - _animationFrom).abs();
    _animationController.duration =
        Duration(milliseconds: (180 + 140 * distance).round());
    _animationController.forward(from: 0.0);
  }

  Widget _buildPageBody(int index) {
    final page = widget.pages[index];
    final currentDisplay = index + 1;
    return ColoredBox(
      color: widget.theme.background,
      child: ContentRenderer.buildPage(
        page: page,
        theme: widget.theme,
        fontSize: widget.fontSize,
        lineHeight: widget.lineHeight,
        chapterTitle: widget.chapterTitle,
        pageIndicator: '$currentDisplay/${widget.totalPages}',
        timeLabel: widget.timeLabel,
        batteryLabel: widget.batteryLabel,
        ttsParagraphIndex: widget.ttsParagraphIndex,
        showTopBar: widget.showTopBar,
        showBottomBar: widget.showBottomBar,
        showPageNumber: widget.showPageNumber,
        horizontalPadding: widget.horizontalPadding,
        topPadding: widget.topPadding,
        paragraphSpacing: widget.paragraphSpacing,
        firstLineIndent: widget.firstLineIndent,
      ),
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_usesManualPaging || widget.pages.length <= 1) return;
    _animationController.stop();
    _basePage = widget.currentPage;
    _dragStartX = details.localPosition.dx;
    _dragging = true;
    _turnDirection = 0;
    _targetPage = null;
    _progress = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double width) {
    if (!_dragging || width <= 0) return;
    final dx = details.localPosition.dx - _dragStartX;

    if (_turnDirection == 0 && dx.abs() >= _dragTrigger) {
      final direction = dx < 0 ? 1 : -1;
      final targetPage = _basePage + direction;
      if (targetPage < 0 || targetPage >= widget.pages.length) {
        _dragging = false;
        return;
      }
      _turnDirection = direction;
      _targetPage = targetPage;
      if (widget.animType == PageAnimType.simulation) {
        _scheduleCaptureIfNeeded();
      }
    }

    if (_turnDirection == 0 || _targetPage == null) return;

    final rawProgress = _turnDirection > 0 ? -dx / width : dx / width;
    setState(() {
      _progress = rawProgress.clamp(0.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    if (_turnDirection == 0 || _targetPage == null) {
      _resetTurnState();
      return;
    }

    final velocity = details.primaryVelocity ?? 0.0;
    final velocityCommits = _turnDirection > 0
        ? velocity < -_commitVelocity
        : velocity > _commitVelocity;
    final shouldCommit = velocityCommits || _progress >= _commitThreshold;
    _startAnimation(shouldCommit ? 1.0 : 0.0, commit: shouldCommit);
  }

  void _onHorizontalDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    if (_targetPage == null) {
      _resetTurnState();
      return;
    }
    _startAnimation(0.0, commit: false);
  }

  Widget _buildPageViewMode() {
    return PageView.builder(
      controller: widget.pageController,
      scrollDirection: widget.animType.axis,
      physics: const ClampingScrollPhysics(),
      itemCount: widget.pages.length,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) => _buildPageBody(index),
    );
  }

  Widget _buildManualMode() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final currentIndex = _isTurning ? _basePage : widget.currentPage;
        final baseCurrentChild = _buildPageBody(currentIndex);
        final currentChild =
            widget.animType == PageAnimType.simulation && !_isTurning
                ? RepaintBoundary(key: _captureKey, child: baseCurrentChild)
                : baseCurrentChild;
        _scheduleCaptureIfNeeded();
        if (!_isTurning || _targetPage == null || _turnDirection == 0) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: (details) =>
                _onHorizontalDragUpdate(details, size.width),
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onHorizontalDragCancel: _onHorizontalDragCancel,
            child: currentChild,
          );
        }

        final targetChild = _buildPageBody(_targetPage!);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: (details) =>
              _onHorizontalDragUpdate(details, size.width),
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onHorizontalDragCancel: _onHorizontalDragCancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildTargetLayer(size, targetChild),
              if (widget.animType == PageAnimType.cover)
                _buildCoverCurrentLayer(size, currentChild)
              else if (widget.animType == PageAnimType.simulation)
                _buildSimulationLayer(size, currentChild)
              else
                currentChild,
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetLayer(Size size, Widget targetChild) {
    if (widget.animType == PageAnimType.none) {
      return const SizedBox.expand();
    }

    if (widget.animType == PageAnimType.simulation) {
      return targetChild;
    }

    if (_turnDirection > 0) {
      final revealWidth = size.width * _progress;
      return ClipRect(
        clipper: _RevealClipper(
          left: size.width - revealWidth,
          top: 0,
          right: size.width,
          bottom: size.height,
        ),
        child: targetChild,
      );
    }

    final revealWidth = size.width * _progress;
    return ClipRect(
      clipper: _RevealClipper(
        left: 0,
        top: 0,
        right: revealWidth,
        bottom: size.height,
      ),
      child: targetChild,
    );
  }

  Widget _buildCoverCurrentLayer(Size size, Widget currentChild) {
    final dx =
        _turnDirection > 0 ? -size.width * _progress : size.width * _progress;
    final shadow = (_progress * 0.22).clamp(0.0, 0.22);
    return Transform.translate(
      offset: Offset(dx, 0),
      child: _edgeShadow(
        child: currentChild,
        opacity: shadow,
        alignAtTrailingEdge: _turnDirection > 0,
      ),
    );
  }

  Widget _buildSimulationLayer(Size size, Widget currentChild) {
    final signature = _buildCaptureSignature();
    final image =
        _capturedImageSignature == signature ? _capturedCurrentImage : null;
    if (image == null) {
      return _buildCoverCurrentLayer(size, currentChild);
    }

    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _SimulationCurlPainter(
          image: image,
          progress: _progress,
          fromRightEdge: _turnDirection > 0,
          backgroundColor: widget.theme.background,
        ),
      ),
    );
  }

  Widget _edgeShadow({
    required Widget child,
    required double opacity,
    required bool alignAtTrailingEdge,
  }) {
    if (opacity <= 0) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: alignAtTrailingEdge
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                end: alignAtTrailingEdge
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: opacity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return _usesManualPaging ? _buildManualMode() : _buildPageViewMode();
  }
}

class _SimulationCurlPainter extends CustomPainter {
  final ui.Image image;
  final double progress;
  final bool fromRightEdge;
  final Color backgroundColor;

  const _SimulationCurlPainter({
    required this.image,
    required this.progress,
    required this.fromRightEdge,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        image.width <= 0 ||
        image.height <= 0) {
      return;
    }

    final turnProgress = progress.clamp(0.0, 1.0);
    final visibleWidth = size.width * (1 - turnProgress);
    if (visibleWidth <= 0) {
      return;
    }

    final curlRadius = size.width * math.sin(turnProgress * math.pi) * 0.12 +
        size.width * 0.04;
    const segments = 88;
    final segmentSize = visibleWidth / segments;

    for (var index = 0; index < segments; index++) {
      final start = index * segmentSize;
      final end = math.min(visibleWidth, (index + 1) * segmentSize);
      if (end <= start) continue;

      final normalized = end / size.width;
      final angle = (1 - normalized) * turnProgress * math.pi * 0.92;
      final bend = curlRadius * (1 - math.cos(angle));
      final depthScale = 1 + math.sin(angle) * 0.08;

      final srcLeftFactor =
          fromRightEdge ? 1 - (end / size.width) : start / size.width;
      final srcWidthFactor = (end - start) / size.width;
      final srcRect = Rect.fromLTWH(
        srcLeftFactor * image.width,
        0,
        srcWidthFactor * image.width,
        image.height.toDouble(),
      );

      final left = fromRightEdge ? size.width - end - bend : start + bend;
      final dstRect = Rect.fromLTWH(
        left,
        -(size.height * (depthScale - 1)) / 2,
        (end - start) * depthScale,
        size.height * depthScale,
      );

      canvas.drawImageRect(
        image,
        srcRect,
        dstRect,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.medium,
      );
    }

    final edgeX = fromRightEdge ? visibleWidth : size.width - visibleWidth;
    final shadowRect = fromRightEdge
        ? Rect.fromLTWH(edgeX, 0, size.width - edgeX, size.height)
        : Rect.fromLTWH(0, 0, edgeX, size.height);

    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: fromRightEdge ? Alignment.centerRight : Alignment.centerLeft,
        end: fromRightEdge ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.20 * turnProgress),
          Colors.black.withValues(alpha: 0.08 * turnProgress),
          backgroundColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(shadowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRect(shadowRect, shadowPaint);

    final edgeLine = Paint()
      ..color = Colors.black.withValues(alpha: 0.16 * turnProgress)
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawLine(Offset(edgeX, 0), Offset(edgeX, size.height), edgeLine);
  }

  @override
  bool shouldRepaint(covariant _SimulationCurlPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.progress != progress ||
        oldDelegate.fromRightEdge != fromRightEdge ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _RevealClipper({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      left.clamp(0.0, size.width),
      top.clamp(0.0, size.height),
      right.clamp(0.0, size.width),
      bottom.clamp(0.0, size.height),
    );
  }

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) {
    return left != oldClipper.left ||
        top != oldClipper.top ||
        right != oldClipper.right ||
        bottom != oldClipper.bottom;
  }
}
