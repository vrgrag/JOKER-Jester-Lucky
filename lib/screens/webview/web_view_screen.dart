import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_theme.dart';
import '../../widgets/jester_button.dart';

class WebViewScreenArgs {
  const WebViewScreenArgs({required this.title, required this.url});

  final String title;
  final String url;
}

/// Generic in-app browser used for Privacy Policy / Support links.
///
/// The core game never needs a network connection; this screen is the
/// only place that does, so it fails gracefully with a friendly message
/// (instead of a blank page or crash) when there is no connectivity --
/// important for app-review devices that may be offline.
class WebViewScreen extends StatefulWidget {
  static const route = '/web';

  const WebViewScreen({super.key, required this.args});

  final WebViewScreenArgs args;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.ink)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _loading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) => setState(() {
            _loading = false;
            _hasError = true;
          }),
        ),
      )
      ..loadRequest(Uri.parse(widget.args.url));
  }

  void _retry() {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    _controller.loadRequest(Uri.parse(widget.args.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.purpleDeep,
        foregroundColor: AppColors.goldLight,
        title: Text(widget.args.title, style: jesterTextStyle(size: 20)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _controller),
          if (_loading && !_hasError)
            const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: AppColors.gold, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load this page.\nPlease check your internet connection.',
                      textAlign: TextAlign.center,
                      style: jesterTextStyle(size: 16, color: AppColors.parchment),
                    ),
                    const SizedBox(height: 24),
                    JesterButton(label: 'RETRY', onTap: _retry, fontSize: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
