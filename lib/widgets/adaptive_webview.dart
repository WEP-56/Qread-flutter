import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

typedef CustomSchemeHandler = Future<void> Function(String url);

class AdaptiveWebView extends StatefulWidget {
  final String url;
  final bool enableJs;
  final String? injectJs;
  final Map<String, String> headers;
  final CustomSchemeHandler? onCustomScheme;

  const AdaptiveWebView({
    Key? key,
    required this.url,
    required this.enableJs,
    this.injectJs,
    this.headers = const {},
    this.onCustomScheme,
  }) : super(key: key);

  @override
  State<AdaptiveWebView> createState() => _AdaptiveWebViewState();
}

class _AdaptiveWebViewState extends State<AdaptiveWebView> {
  WebViewController? _mobileController;
  win.WebviewController? _windowsController;
  StreamSubscription? _windowsLoadingSub;
  StreamSubscription? _windowsMessageSub;
  bool _loading = true;
  String? _error;
  String? _webView2Version;

  bool get _isWindows => Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_isWindows) {
      _initWindows();
    } else {
      _initMobile();
    }
  }

  @override
  void dispose() {
    _windowsLoadingSub?.cancel();
    _windowsMessageSub?.cancel();
    final controller = _windowsController;
    _windowsController = null;
    controller?.dispose();
    super.dispose();
  }

  Future<void> _initMobile() async {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initWindows() async {
    try {
      final version = await win.WebviewController.getWebViewVersion();
      if (version == null) {
        if (!mounted) return;
        setState(() {
          _error = '当前系统未安装 WebView2 Runtime';
          _loading = false;
        });
        return;
      }

      final controller = win.WebviewController();
      await controller.initialize();
      await controller.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.sameWindow);

      final userAgent = widget.headers['User-Agent'] ?? widget.headers['user-agent'];
      if (userAgent != null && userAgent.isNotEmpty) {
        await controller.setUserAgent(userAgent);
      }

      final bridgeScript = _windowsBridgeScript();
      if (bridgeScript.isNotEmpty) {
        await controller.addScriptToExecuteOnDocumentCreated(bridgeScript);
      }
      if (widget.injectJs != null && widget.injectJs!.isNotEmpty) {
        await controller.addScriptToExecuteOnDocumentCreated(widget.injectJs!);
      }

      _windowsLoadingSub = controller.loadingState.listen((state) async {
        if (!mounted) return;
        if (state == win.LoadingState.loading) {
          setState(() => _loading = true);
        } else if (state == win.LoadingState.navigationCompleted) {
          setState(() => _loading = false);
          final js = widget.injectJs;
          if (js != null && js.isNotEmpty) {
            try {
              await controller.executeScript(js);
            } catch (_) {}
          }
        }
      });

      _windowsMessageSub = controller.webMessage.listen((message) async {
        final text = message?.toString() ?? '';
        if (text.isEmpty) return;
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map && decoded['type'] == 'customScheme') {
            final url = decoded['url']?.toString();
            if (url != null && _isCustomScheme(url)) {
              await widget.onCustomScheme?.call(url);
            }
          }
        } catch (_) {}
      });

      controller.url.listen((url) async {
        if (_isCustomScheme(url)) {
          await widget.onCustomScheme?.call(url);
        }
      });

      await controller.loadUrl(widget.url);

      if (!mounted) return;
      setState(() {
        _windowsController = controller;
        _webView2Version = version;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isCustomScheme(String url) {
    return url.startsWith('yuedu://') || url.startsWith('legado://');
  }

  String _windowsBridgeScript() {
    if (widget.onCustomScheme == null) return '';
    return '''
      (function() {
        document.addEventListener('click', function(event) {
          var node = event.target;
          while (node && node.tagName !== 'A') {
            node = node.parentElement;
          }
          if (!node) return;
          var href = node.getAttribute('href') || '';
          if (href.startsWith('yuedu://') || href.startsWith('legado://')) {
            event.preventDefault();
            if (window.chrome && window.chrome.webview) {
              window.chrome.webview.postMessage(JSON.stringify({type: 'customScheme', url: href}));
            }
          }
        }, true);
      })();
    ''';
  }

  Future<void> _openWebView2Download() async {
    final uri = Uri.parse('https://developer.microsoft.com/microsoft-edge/webview2/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildError();
    }

    final body = _isWindows
        ? (_windowsController == null
            ? const SizedBox.shrink()
            : win.Webview(_windowsController!))
        : WebView(
            initialUrl: 'about:blank',
            javascriptMode: widget.enableJs ? JavascriptMode.unrestricted : JavascriptMode.disabled,
            gestureNavigationEnabled: true,
            navigationDelegate: (request) async {
              final url = request.url;
              if (_isCustomScheme(url)) {
                await widget.onCustomScheme?.call(url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onWebViewCreated: (controller) async {
              _mobileController = controller;
              try {
                await controller.loadUrl(widget.url, headers: widget.headers);
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _error = e.toString();
                    _loading = false;
                  });
                }
              }
            },
            onPageStarted: (_) {
              if (mounted) setState(() => _loading = true);
            },
            onPageFinished: (_) async {
              final js = widget.injectJs;
              if (js != null && js.isNotEmpty && _mobileController != null) {
                try {
                  await _mobileController!.runJavascript(js);
                } catch (_) {}
              }
              if (mounted) setState(() => _loading = false);
            },
          );

    return Stack(
      children: [
        Positioned.fill(child: body),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildError() {
    final runtimeMissing = _error == '当前系统未安装 WebView2 Runtime';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            if (_webView2Version != null) ...[
              const SizedBox(height: 8),
              Text(
                'WebView2: $_webView2Version',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            if (runtimeMissing)
              ElevatedButton(
                onPressed: _openWebView2Download,
                child: const Text('安装 WebView2 Runtime'),
              ),
          ],
        ),
      ),
    );
  }
}
