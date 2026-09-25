import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/fate_wheel/fate_wheel_catalog.dart';
import '../../core/platform/android_bridge.dart';

/// Bundles the author's original machine, CSS and animations instead of
/// approximating its seven-reel layout in Flutter.
class FateWheelPage extends StatefulWidget {
  const FateWheelPage({super.key});

  @override
  State<FateWheelPage> createState() => _FateWheelPageState();
}

class _FateWheelPageState extends State<FateWheelPage> {
  late final WebViewController _webView;
  List<FateWheelDimension>? _catalog;
  bool _resultAccepted = false;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final catalog = await FateWheelCatalog.load();
      await _webView.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _webView.setBackgroundColor(const Color(0xFF070504));
      final platform = _webView.platform;
      if (platform is AndroidWebViewController) {
        await platform.setOverScrollMode(WebViewOverScrollMode.never);
        await platform.setVerticalScrollBarEnabled(false);
        await platform.setHorizontalScrollBarEnabled(false);
      }
      await _webView.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final url = request.url;
          if (url == 'https://github.com/29-Cu/Ruota-della-Fortuna') {
            unawaited(AndroidBridge.instance.openExternalHttpsUrl(url));
            return NavigationDecision.prevent;
          }
          // The original HTML is a trusted bundled asset. Neither an external
          // site nor arbitrary file content may acquire its JS bridge.
          return url == 'about:blank' ||
                  url == 'file:///android_asset/flutter_assets/assets/fate_wheel/index.html'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ));
      await _webView.addJavaScriptChannel(
        'FateWheelBridge',
        onMessageReceived: (message) {
          unawaited(_onConfirmedResult(message.message));
        },
      );
      if (!mounted) return;
      _catalog = catalog;
      await _webView.loadFlutterAsset('assets/fate_wheel/index.html');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingError = '轮盘页面加载失败，请稍后再试。');
    }
  }

  Future<void> _onConfirmedResult(String message) async {
    if (!mounted || _resultAccepted || _catalog == null) return;
    final result = FateWheelResult.fromBridgeMessage(message, _catalog!);
    if (result == null) return;
    _resultAccepted = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070504),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070504),
          foregroundColor: const Color(0xFFE7C463),
          title: const Text('命运之轮', style: TextStyle(fontSize: 16)),
          toolbarHeight: 45,
        ),
        body: _loadingError == null
            ? WebViewWidget(controller: _webView)
            : Center(
                child: Text(_loadingError!,
                    style: const TextStyle(color: Color(0xFFE7C463))),
              ),
      );
}
