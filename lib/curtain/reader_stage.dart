import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../edge/agent_forge.dart';
import '../edge/beacon_hub.dart';
import '../edge/depot.dart';
import '../edge/link_probe.dart';
import 'no_signal_stage.dart';

/// Immersive full-screen WebView shell (gray content).
///
/// Features:
///   • forged device User-Agent (see `agent_forge.dart`),
///   • both orientations enabled,
///   • immersive system UI (status + nav bar hidden),
///   • external URI schemes handed off to the OS,
///   • redirect-loop recovery (up to 3 retries),
///   • live connectivity guard → No-Signal on drop (no DNS probe),
///   • warm push link hot-load,
///   • file uploads routed through MainActivity method channel,
///   • third-party cookies + media autoplay enabled for Android,
///   • JS injections for safe-area CSS + keyboard scroll.
class ReaderStage extends StatefulWidget {
  const ReaderStage({
    super.key,
    required this.destination,
    required this.depot,
    required this.beacon,
    required this.linkProbe,
  });

  final String destination;
  final Depot depot;
  final BeaconHub beacon;
  final LinkProbe linkProbe;

  @override
  State<ReaderStage> createState() => _ReaderStageState();
}

class _ReaderStageState extends State<ReaderStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _leftForOffline = false;
  String? _lastMainFrame;
  int _redirectRetries = 0;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _offlineDebounce;

  // [FINGERPRINT] project-unique channel name (mirrored in MainActivity.kt).
  static const MethodChannel _pickChannel = MethodChannel('jester/pick');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _goImmersive();
    _buildWebController();

    widget.beacon.onLinkReady = (String link) {
      if (mounted) _web.loadRequest(Uri.parse(link));
    };

    // Debounced connectivity guard — VPN toggling briefly emits
    // `none` even on a healthy connection (§3).
    _connSub = widget.linkProbe.changes
        .listen((List<ConnectivityResult> results) {
      final bool allNone =
          results.isNotEmpty && results.every((r) => r == ConnectivityResult.none);
      if (!allNone) {
        _offlineDebounce?.cancel();
        return;
      }
      _offlineDebounce?.cancel();
      _offlineDebounce = Timer(const Duration(milliseconds: 700), () {
        _routeToNoSignal();
      });
    });
  }

  void _goImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _goImmersive();
  }

  void _buildWebController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(jesterNet.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _redirectRetries = 0;
          _injectSafeAreaReset();
          _injectKeyboardScroll();
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          final String desc = err.description.toLowerCase();

          // Redirect loop → retry the last known main-frame URL.
          final bool loop = desc.contains('too_many_redirects') ||
              desc.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (loop && _lastMainFrame != null && _redirectRetries < 3) {
            _redirectRetries++;
            _web.loadRequest(Uri.parse(_lastMainFrame!));
            return;
          }

          // Cover the WebView's native error page IMMEDIATELY (§4).
          if (mounted) setState(() => _spinner = true);

          final bool isDnsOrDown = desc.contains('name_not_resolved') ||
              desc.contains('err_name_not_resolved') ||
              desc.contains('internet_disconnected') ||
              desc.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (isDnsOrDown) {
            _routeToNoSignal();
          } else {
            _probeAndRouteIfOffline();
          }
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          const Set<String> inApp = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inApp.contains(uri.scheme)) {
            if (req.isMainFrame) _lastMainFrame = req.url;
            return NavigationDecision.navigate;
          }
          _openExternally(uri);
          return NavigationDecision.prevent;
        },
      ));

    _tuneAndroid();
    _web.loadRequest(Uri.parse(widget.destination));
  }

  void _tuneAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController controller =
        _web.platform as AndroidWebViewController;

    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );
    controller.setOnShowFileSelector(_openNativePicker);

    // Third-party cookies for OAuth / payment redirects.
    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _openNativePicker(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _pickChannel
          .invokeMethod<List<Object?>>('choose', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _probeAndRouteIfOffline() async {
    if (_leftForOffline) return;
    final bool online = await widget.linkProbe.isReachable();
    if (online) return;
    _routeToNoSignal();
  }

  void _routeToNoSignal() {
    if (_leftForOffline || !mounted) return;
    _leftForOffline = true;
    final String resumeAt = _lastMainFrame ?? widget.destination;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalStage(
          retryBuilder: (_) => ReaderStage(
            destination: resumeAt,
            depot: widget.depot,
            beacon: widget.beacon,
            linkProbe: widget.linkProbe,
          ),
        ),
      ),
    );
  }

  // Scrolls focused inputs above the keyboard using `visualViewport`
  // and `scrollIntoView({behavior:'auto'})` — smooth scroll fights the
  // keyboard animator and produces jitter (§3 in pitfalls).
  void _injectKeyboardScroll() {
    _web.runJavaScript(r'''
(function(){
  if (window.__jlKb) return; window.__jlKb = true;
  function isField(el){return el && (el.tagName==='INPUT' || el.tagName==='TEXTAREA' || el.isContentEditable);}
  function bring(){
    var el = document.activeElement; if (!isField(el)) return;
    var vp = window.visualViewport;
    if (vp) {
      var r = el.getBoundingClientRect();
      var bottom = vp.offsetTop + vp.height;
      if (r.bottom > bottom - 20 || r.top < vp.offsetTop) {
        el.scrollIntoView({behavior:'auto', block:'nearest'});
      }
    } else {
      el.scrollIntoView({behavior:'auto', block:'nearest'});
    }
  }
  document.addEventListener('focusin', function(e){
    if (isField(e.target)) setTimeout(bring, 350);
  });
  if (window.visualViewport) {
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if (h < prev) setTimeout(bring, 120);
      prev = h;
    });
  }
})();
''');
  }

  // Neutralises the site's safe-area CSS variables + narrow decorative
  // header top padding. Deliberately does NOT touch html/body/#app/#root
  // padding — that squashes the partner site's own gutters
  // (see `.cursor/rules/webview_safe_area_injection.mdc`).
  void _injectSafeAreaReset() {
    _web.runJavaScript(r'''
(function(){
  if (window.__jlSa) return; window.__jlSa = true;
  var ID = '__jl_sa_style';
  var CSS =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
      '--safe-top:0px!important;--safe-bottom:0px!important;' +
      '--safe-left:0px!important;--safe-right:0px!important;' +
    '}' +
    '.gameview-mobile-header,.app-header,.js-safe-top,.safe-area-top{' +
      'padding-top:0!important;margin-top:0!important;' +
    '}';
  function kbOpen(){ if(!window.visualViewport) return false; return window.visualViewport.height < window.innerHeight * 0.75; }
  function apply(){
    if (kbOpen()) return;
    var head = document.head || document.documentElement; if (!head) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content')||'')) {
      var c = (meta.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      meta.setAttribute('content', c + (c?', ':'') + 'viewport-fit=contain');
    }
    var s = document.getElementById(ID);
    if (!s) { s = document.createElement('style'); s.id = ID; head.appendChild(s); }
    if (s.textContent !== CSS) s.textContent = CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o = history[fn];
    history[fn] = function(){ var r = o.apply(this, arguments); setTimeout(apply, 80); setTimeout(apply, 400); return r; };
  });
  window.addEventListener('popstate', function(){ setTimeout(apply, 80); });
  setInterval(apply, 2500);
})();
''');
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _offlineDebounce?.cancel();
    widget.beacon.onLinkReady = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // Keyboard inset is handled by the JS scroll fix — see the
        // three-layer keyboard fix in `.cursor/rules/gray_part_pitfalls.md`.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Safe zone around the display cutout in BOTH orientations
            // — top in portrait, side in landscape. Bottom stays flush
            // so the WebView keeps every pixel of drawing area.
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _web),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFC94D),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
