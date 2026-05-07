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
  Offset _touchPoint = Offset.zero;
  Offset _animationTouchBegin = Offset.zero;
  Offset _animationTouchEnd = Offset.zero;
  Size? _lastViewportSize;

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

    if (widget.animType == PageAnimType.simulation) {
      final size = _lastViewportSize ?? MediaQuery.sizeOf(context);
      _touchPoint = _defaultSimulationTouch(size);
    }

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
    if (widget.animType == PageAnimType.simulation && _targetPage != null) {
      final size = _lastViewportSize ?? MediaQuery.sizeOf(context);
      setState(() {
        _touchPoint = _normalizeSimulationTouch(
          Offset.lerp(_animationTouchBegin, _animationTouchEnd, eased) ??
              _animationTouchEnd,
          size,
        );
        _progress = _simulationProgressForTouch(_touchPoint, size);
      });
      return;
    }

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
    if (widget.animType == PageAnimType.simulation) {
      final size = _lastViewportSize ?? MediaQuery.sizeOf(context);
      final endTouch = target >= 1
          ? _simulationConfirmTouch(size)
          : _simulationCancelTouch(size);
      _startSimulationTouchAnimation(endTouch, commit: commit);
      return;
    }

    _animationFrom = _progress;
    _animationTo = target;
    _commitOnAnimationEnd = commit;
    final distance = (_animationTo - _animationFrom).abs();
    _animationController.duration =
        Duration(milliseconds: (180 + 140 * distance).round());
    _animationController.forward(from: 0.0);
  }

  void _startSimulationTouchAnimation(
    Offset endTouch, {
    required bool commit,
  }) {
    _animationTouchBegin = _touchPoint;
    _animationTouchEnd = endTouch;
    _commitOnAnimationEnd = commit;
    _animationController.duration = const Duration(milliseconds: 320);
    _animationController.forward(from: 0.0);
  }

  Offset _defaultSimulationTouch(Size size) {
    final x = _turnDirection > 0 ? size.width * 0.88 : size.width * 0.12;
    final y = size.height * 0.88;
    return _normalizeSimulationTouch(Offset(x, y), size);
  }

  Offset _simulationConfirmTouch(Size size) {
    final cornerY = _touchPoint.dy <= size.height / 2 ? 1.0 : size.height - 1;
    final x = _turnDirection > 0 ? -size.width / 2 : size.width * 1.5;
    return Offset(x, cornerY);
  }

  Offset _simulationCancelTouch(Size size) {
    final x = _turnDirection > 0 ? size.width - 1 : 1.0;
    final y = _touchPoint.dy <= size.height / 2 ? 1.0 : size.height - 1;
    return Offset(x, y);
  }

  Offset _normalizeSimulationTouch(Offset touch, Size size) {
    return Offset(
      touch.dx.clamp(-size.width * 0.6, size.width * 1.6),
      touch.dy.clamp(1.0, math.max(1.0, size.height - 1.0)),
    );
  }

  double _simulationProgressForTouch(Offset touch, Size size) {
    if (size.width <= 0) return _progress;
    if (_turnDirection > 0) {
      return ((size.width - touch.dx) / (size.width * 1.5)).clamp(0.0, 1.0);
    }
    return (touch.dx / (size.width * 1.5)).clamp(0.0, 1.0);
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
    _touchPoint = _normalizeSimulationTouch(
      details.localPosition,
      _lastViewportSize ?? MediaQuery.sizeOf(context),
    );
    _dragging = true;
    _turnDirection = 0;
    _targetPage = null;
    _progress = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double width) {
    if (!_dragging || width <= 0) return;
    final dx = details.localPosition.dx - _dragStartX;
    final size = _lastViewportSize ?? MediaQuery.sizeOf(context);

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
        _touchPoint = _normalizeSimulationTouch(details.localPosition, size);
        _scheduleCaptureIfNeeded();
      }
    }

    if (_turnDirection == 0 || _targetPage == null) return;

    final rawProgress = _turnDirection > 0 ? -dx / width : dx / width;
    setState(() {
      _progress = rawProgress.clamp(0.0, 1.0);
      if (widget.animType == PageAnimType.simulation) {
        _touchPoint = _normalizeSimulationTouch(details.localPosition, size);
      }
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
        _lastViewportSize = size;

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

    return CustomPaint(
      size: size,
      painter: _SimulationTurnPainter(
        image: image,
        geometry: _SimulationTurnGeometry.compute(
          size: size,
          touchPoint: _touchPoint,
          fromNext: _turnDirection > 0,
        ),
        backgroundColor: widget.theme.background,
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

class _SimulationTurnPainter extends CustomPainter {
  final ui.Image image;
  final _SimulationTurnGeometry geometry;
  final Color backgroundColor;

  const _SimulationTurnPainter({
    required this.image,
    required this.geometry,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image.width <= 0 || image.height <= 0) return;

    final fullImageRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final fullCanvasRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.save();
    canvas.clipPath(geometry.areaAPath);
    canvas.drawImageRect(
      image,
      fullImageRect,
      fullCanvasRect,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.medium,
    );
    _drawAreaAShadow(canvas);
    canvas.restore();

    canvas.save();
    canvas.clipPath(geometry.areaCPath);
    canvas.drawPaint(Paint()..color = backgroundColor);

    canvas.save();
    canvas.translate(geometry.controlPoint1.dx, geometry.controlPoint1.dy);
    canvas.transform(geometry.reflectionMatrix.storage);
    canvas.translate(-geometry.controlPoint1.dx, -geometry.controlPoint1.dy);
    canvas.drawImageRect(
      image,
      fullImageRect,
      fullCanvasRect,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.medium,
    );
    canvas.drawPaint(
      Paint()..color = backgroundColor.withValues(alpha: 0.55),
    );
    canvas.restore();

    _drawAreaCShadow(canvas);
    canvas.restore();

    _drawAreaBShadow(canvas);
  }

  void _drawAreaAShadow(Canvas canvas) {
    _drawAreaALeftShadow(canvas);
    _drawAreaARightShadow(canvas);
  }

  void _drawAreaALeftShadow(Canvas canvas) {
    final shadowWidth = geometry.leftShadowWidth;
    if (shadowWidth <= 0) return;

    final maxShadowWidth = math.max(
      geometry.leftShadowWidth,
      geometry.rightShadowWidth,
    );
    final helperPath = Path()
      ..moveTo(
          geometry.touchPoint.dx - maxShadowWidth / 2, geometry.touchPoint.dy)
      ..lineTo(geometry.vertexPoint1.dx, geometry.vertexPoint1.dy)
      ..lineTo(geometry.controlPoint1.dx, geometry.controlPoint1.dy)
      ..lineTo(geometry.touchPoint.dx, geometry.touchPoint.dy)
      ..close();

    final left = geometry.isTopRight
        ? geometry.controlPoint1.dx - shadowWidth / 2
        : geometry.controlPoint1.dx;
    final right = geometry.isTopRight
        ? geometry.controlPoint1.dx
        : geometry.controlPoint1.dx + shadowWidth / 2;
    final gradient = geometry.isTopRight
        ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x01333333), Color(0x33333333)],
          )
        : const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x33333333), Color(0x01333333)],
          );

    canvas.save();
    canvas.clipPath(geometry.areaAPath);
    canvas.clipPath(helperPath);
    canvas.translate(geometry.controlPoint1.dx, geometry.controlPoint1.dy);
    canvas.rotate(
      math.atan2(
        geometry.controlPoint1.dx - geometry.touchPoint.dx,
        geometry.touchPoint.dy - geometry.controlPoint1.dy,
      ),
    );
    canvas.translate(-geometry.controlPoint1.dx, -geometry.controlPoint1.dy);
    final rect = Rect.fromLTRB(
      left,
      geometry.controlPoint1.dy,
      right,
      geometry.controlPoint1.dy + geometry.viewportHeight,
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    canvas.restore();
  }

  void _drawAreaARightShadow(Canvas canvas) {
    final shadowWidth = geometry.rightShadowWidth;
    if (shadowWidth <= 0) return;

    final maxShadowWidth = math.max(
      geometry.leftShadowWidth,
      geometry.rightShadowWidth,
    );
    final helperPath = Path()
      ..moveTo(
          geometry.touchPoint.dx - maxShadowWidth / 2, geometry.touchPoint.dy)
      ..lineTo(geometry.controlPoint2.dx, geometry.controlPoint2.dy)
      ..lineTo(geometry.touchPoint.dx, geometry.touchPoint.dy)
      ..close();

    final rect = Rect.fromLTRB(
      geometry.controlPoint2.dx,
      geometry.isTopRight
          ? geometry.controlPoint2.dy - shadowWidth / 2
          : geometry.controlPoint2.dy,
      geometry.controlPoint2.dx + geometry.maxLength,
      geometry.isTopRight
          ? geometry.controlPoint2.dy
          : geometry.controlPoint2.dy + shadowWidth / 2,
    );
    final gradient = geometry.isTopRight
        ? const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0x22333333), Color(0x01333333), Color(0x01333333)],
            stops: [0.0, 0.65, 1.0],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x22333333), Color(0x01333333), Color(0x01333333)],
            stops: [0.0, 0.65, 1.0],
          );

    canvas.save();
    canvas.clipPath(geometry.areaAPath);
    canvas.clipPath(helperPath);
    canvas.translate(geometry.controlPoint2.dx, geometry.controlPoint2.dy);
    canvas.rotate(
      math.atan2(
        geometry.touchPoint.dy - geometry.controlPoint2.dy,
        geometry.touchPoint.dx - geometry.controlPoint2.dx,
      ),
    );
    canvas.translate(-geometry.controlPoint2.dx, -geometry.controlPoint2.dy);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    canvas.restore();
  }

  void _drawAreaBShadow(Canvas canvas) {
    canvas.save();
    canvas.clipPath(geometry.areaBPath);
    canvas.translate(geometry.startPoint1.dx, geometry.startPoint1.dy);
    canvas.rotate(
      math.atan2(
        geometry.controlPoint1.dx - geometry.cornerX,
        geometry.controlPoint2.dy - geometry.cornerY,
      ),
    );
    final left = geometry.isRtAndLb ? 0.0 : -geometry.touchToCornerDistance / 4;
    final right = geometry.isRtAndLb ? geometry.touchToCornerDistance / 4 : 0.0;
    final rect = Rect.fromLTRB(left, 0, right, geometry.maxLength);
    final gradient = geometry.isRtAndLb
        ? const LinearGradient(
            colors: [Color(0x33111111), Color(0x00111111)],
          )
        : const LinearGradient(
            colors: [Color(0x00111111), Color(0x33111111)],
          );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = gradient.createShader(rect)
        ..isAntiAlias = false,
    );
    canvas.restore();
  }

  void _drawAreaCShadow(Canvas canvas) {
    final midCe = (geometry.startPoint1.dx + geometry.controlPoint1.dx) / 2;
    final f1 = (midCe - geometry.controlPoint1.dx).abs();
    final midJh = (geometry.startPoint2.dy + geometry.controlPoint2.dy) / 2;
    final f2 = (midJh - geometry.controlPoint2.dy).abs();
    final width = math.min(f1, f2) + 1;

    final left = geometry.isTopRight ? 30.0 : -(width + 1);
    final right = geometry.isTopRight ? width + 1 : -30.0;

    canvas.save();
    canvas.clipPath(geometry.areaCPath);
    canvas.translate(geometry.startPoint1.dx, geometry.startPoint1.dy);
    canvas.rotate(
      math.atan2(
        geometry.controlPoint1.dx - geometry.cornerX,
        geometry.controlPoint2.dy - geometry.cornerY,
      ),
    );
    canvas.translate(-geometry.startPoint1.dx, -geometry.startPoint1.dy);
    final rect = Rect.fromLTRB(
      geometry.startPoint1.dx + left,
      geometry.startPoint1.dy,
      geometry.startPoint1.dx + right,
      geometry.startPoint1.dy + geometry.maxLength,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00333333), Color(0x55333333)],
        ).createShader(rect)
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SimulationTurnPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.geometry != geometry ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _SimulationTurnGeometry {
  final Offset touchPoint;
  final double cornerX;
  final double cornerY;
  final bool isRtAndLb;
  final Offset controlPoint1;
  final Offset controlPoint2;
  final Offset startPoint1;
  final Offset startPoint2;
  final Offset endPoint1;
  final Offset endPoint2;
  final Offset vertexPoint1;
  final Offset vertexPoint2;
  final Path areaAPath;
  final Path areaBPath;
  final Path areaCPath;
  final Matrix4 reflectionMatrix;
  final double touchToCornerDistance;
  final double maxLength;
  final double leftShadowWidth;
  final double rightShadowWidth;
  final double viewportHeight;
  final bool isTopRight;

  const _SimulationTurnGeometry({
    required this.touchPoint,
    required this.cornerX,
    required this.cornerY,
    required this.isRtAndLb,
    required this.controlPoint1,
    required this.controlPoint2,
    required this.startPoint1,
    required this.startPoint2,
    required this.endPoint1,
    required this.endPoint2,
    required this.vertexPoint1,
    required this.vertexPoint2,
    required this.areaAPath,
    required this.areaBPath,
    required this.areaCPath,
    required this.reflectionMatrix,
    required this.touchToCornerDistance,
    required this.maxLength,
    required this.leftShadowWidth,
    required this.rightShadowWidth,
    required this.viewportHeight,
    required this.isTopRight,
  });

  static _SimulationTurnGeometry compute({
    required Size size,
    required Offset touchPoint,
    required bool fromNext,
  }) {
    var touch = touchPoint;
    final cornerX = fromNext ? size.width : 0.0;
    final cornerY = touch.dy <= size.height / 2 ? 0.0 : size.height;
    final isRtAndLb = (cornerX == 0 && cornerY == size.height) ||
        (cornerX == size.width && cornerY == 0);

    Offset middle = Offset((touch.dx + cornerX) / 2, (touch.dy + cornerY) / 2);
    Offset controlPoint1 = Offset(
      middle.dx -
          (cornerY - middle.dy) *
              (cornerY - middle.dy) /
              _safeDivisor(cornerX - middle.dx),
      cornerY,
    );
    Offset controlPoint2 = Offset(
      cornerX,
      middle.dy -
          (cornerX - middle.dx) *
              (cornerX - middle.dx) /
              _safeDivisor(cornerY - middle.dy),
    );
    Offset startPoint1 = Offset(
      controlPoint1.dx - (cornerX - controlPoint1.dx) / 2,
      cornerY,
    );

    if (touch.dx > 0 && touch.dx < size.width) {
      if (startPoint1.dx < 0 || startPoint1.dx > size.width) {
        if (startPoint1.dx < 0) {
          startPoint1 = Offset(size.width - startPoint1.dx, startPoint1.dy);
        }

        final f1 = (cornerX - touch.dx).abs();
        final f2 = size.width * f1 / _safeDivisor(startPoint1.dx);
        touch = Offset((cornerX - f2).abs(), touch.dy);

        final f3 = (cornerX - touch.dx).abs() *
            (cornerY - touch.dy).abs() /
            _safeDivisor(f1);
        touch = Offset((cornerX - f2).abs(), (cornerY - f3).abs());

        middle = Offset((touch.dx + cornerX) / 2, (touch.dy + cornerY) / 2);
        controlPoint1 = Offset(
          middle.dx -
              (cornerY - middle.dy) *
                  (cornerY - middle.dy) /
                  _safeDivisor(cornerX - middle.dx),
          cornerY,
        );
        controlPoint2 = Offset(
          cornerX,
          middle.dy -
              (cornerX - middle.dx) *
                  (cornerX - middle.dx) /
                  _safeDivisor(cornerY - middle.dy),
        );
        startPoint1 = Offset(
          controlPoint1.dx - (cornerX - controlPoint1.dx) / 2,
          startPoint1.dy,
        );
      }
    }

    final startPoint2 = Offset(
      cornerX,
      controlPoint2.dy - (cornerY - controlPoint2.dy) / 2,
    );

    final touchToCornerDistance = math.sqrt(
      math.pow(touch.dx - cornerX, 2) + math.pow(touch.dy - cornerY, 2),
    );

    final endPoint1 = _getIntersectionPoint(
      touch,
      controlPoint1,
      startPoint1,
      startPoint2,
    );
    final endPoint2 = _getIntersectionPoint(
      touch,
      controlPoint2,
      startPoint1,
      startPoint2,
    );

    final vertexPoint1 = Offset(
      (startPoint1.dx + 2 * controlPoint1.dx + endPoint1.dx) / 4,
      (2 * controlPoint1.dy + startPoint1.dy + endPoint1.dy) / 4,
    );
    final vertexPoint2 = Offset(
      (startPoint2.dx + 2 * controlPoint2.dx + endPoint2.dx) / 4,
      (2 * controlPoint2.dy + startPoint2.dy + endPoint2.dy) / 4,
    );

    final areaAPath = Path()
      ..moveTo(cornerX == 0 ? size.width : 0, cornerY)
      ..lineTo(startPoint1.dx, startPoint1.dy)
      ..quadraticBezierTo(
        controlPoint1.dx,
        controlPoint1.dy,
        endPoint1.dx,
        endPoint1.dy,
      )
      ..lineTo(touch.dx, touch.dy)
      ..lineTo(endPoint2.dx, endPoint2.dy)
      ..quadraticBezierTo(
        controlPoint2.dx,
        controlPoint2.dy,
        startPoint2.dx,
        startPoint2.dy,
      )
      ..lineTo(cornerX, cornerY == 0 ? size.height : 0)
      ..lineTo(cornerX == 0 ? size.width : 0, cornerY == 0 ? size.height : 0)
      ..close();

    final areaBottomPath = Path()
      ..moveTo(cornerX, cornerY)
      ..lineTo(startPoint1.dx, startPoint1.dy)
      ..quadraticBezierTo(
        controlPoint1.dx,
        controlPoint1.dy,
        endPoint1.dx,
        endPoint1.dy,
      )
      ..lineTo(touch.dx, touch.dy)
      ..lineTo(endPoint2.dx, endPoint2.dy)
      ..quadraticBezierTo(
        controlPoint2.dx,
        controlPoint2.dy,
        startPoint2.dx,
        startPoint2.dy,
      )
      ..close();

    final backTrianglePath = Path()
      ..moveTo(vertexPoint1.dx, vertexPoint1.dy)
      ..lineTo(vertexPoint2.dx, vertexPoint2.dy)
      ..lineTo(touch.dx, touch.dy)
      ..close();

    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final clippedAreaA = Path.combine(
      PathOperation.intersect,
      screenPath,
      areaAPath,
    );
    final clippedAreaC = Path.combine(
      PathOperation.intersect,
      screenPath,
      Path.combine(
        PathOperation.intersect,
        backTrianglePath,
        areaBottomPath,
      ),
    );
    final areaBPath = Path.combine(
      PathOperation.difference,
      screenPath,
      Path.combine(
        PathOperation.union,
        clippedAreaA,
        clippedAreaC,
      ),
    );

    final distance = math.sqrt(
      math.pow(cornerX - controlPoint1.dx, 2) +
          math.pow(controlPoint2.dy - cornerY, 2),
    );
    final sinAngle = (cornerX - controlPoint1.dx) / _safeDivisor(distance);
    final cosAngle = (controlPoint2.dy - cornerY) / _safeDivisor(distance);
    final leftA = touch.dy - controlPoint1.dy;
    final leftB = controlPoint1.dx - touch.dx;
    final leftC = touch.dx * controlPoint1.dy - controlPoint1.dx * touch.dy;
    final leftShadowWidth =
        ((leftA * vertexPoint1.dx + leftB * vertexPoint1.dy + leftC) /
                    math.sqrt(leftA * leftA + leftB * leftB))
                .abs() *
            2;
    final rightA = touch.dy - controlPoint2.dy;
    final rightB = controlPoint2.dx - touch.dx;
    final rightC = touch.dx * controlPoint2.dy - controlPoint2.dx * touch.dy;
    final rightShadowWidth =
        ((rightA * vertexPoint2.dx + rightB * vertexPoint2.dy + rightC) /
                    math.sqrt(rightA * rightA + rightB * rightB))
                .abs() *
            2;
    final reflectionMatrix = Matrix4.identity();
    reflectionMatrix.setValues(
      -(1 - 2 * sinAngle * sinAngle),
      2 * sinAngle * cosAngle,
      0,
      0,
      2 * sinAngle * cosAngle,
      1 - 2 * sinAngle * sinAngle,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    );

    return _SimulationTurnGeometry(
      touchPoint: touch,
      cornerX: cornerX,
      cornerY: cornerY,
      isRtAndLb: isRtAndLb,
      controlPoint1: controlPoint1,
      controlPoint2: controlPoint2,
      startPoint1: startPoint1,
      startPoint2: startPoint2,
      endPoint1: endPoint1,
      endPoint2: endPoint2,
      vertexPoint1: vertexPoint1,
      vertexPoint2: vertexPoint2,
      areaAPath: clippedAreaA,
      areaBPath: areaBPath,
      areaCPath: clippedAreaC,
      reflectionMatrix: reflectionMatrix,
      touchToCornerDistance: touchToCornerDistance,
      maxLength: math.sqrt(
        math.pow(size.width, 2) + math.pow(size.height, 2),
      ),
      leftShadowWidth: leftShadowWidth,
      rightShadowWidth: rightShadowWidth,
      viewportHeight: size.height,
      isTopRight: cornerX == size.width && cornerY == 0,
    );
  }

  static Offset _getIntersectionPoint(
    Offset p1,
    Offset p2,
    Offset p3,
    Offset p4,
  ) {
    final x1 = p1.dx;
    final y1 = p1.dy;
    final x2 = p2.dx;
    final y2 = p2.dy;
    final x3 = p3.dx;
    final y3 = p3.dy;
    final x4 = p4.dx;
    final y4 = p4.dy;

    final pointX =
        ((x1 - x2) * (x3 * y4 - x4 * y3) - (x3 - x4) * (x1 * y2 - x2 * y1)) /
            ((x3 - x4) * (y1 - y2) - (x1 - x2) * (y3 - y4));
    final pointY =
        ((y1 - y2) * (x3 * y4 - x4 * y3) - (x1 * y2 - x2 * y1) * (y3 - y4)) /
            ((y1 - y2) * (x3 - x4) - (x1 - x2) * (y3 - y4));

    return Offset(pointX, pointY);
  }

  static double _safeDivisor(double value) {
    if (value.abs() < 0.1) {
      return value.isNegative ? -0.1 : 0.1;
    }
    return value;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _SimulationTurnGeometry &&
        other.touchPoint == touchPoint &&
        other.cornerX == cornerX &&
        other.cornerY == cornerY;
  }

  @override
  int get hashCode => Object.hash(touchPoint, cornerX, cornerY);
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
