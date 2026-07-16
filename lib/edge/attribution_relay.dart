import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../pact/manifest.dart';
import '../pact/veiled_strings.dart';
import 'agent_forge.dart';

/// AppsFlyer wrapper.
///
/// Collects the install-conversion payload, the deep-link callback and
/// any app-open attribution the SDK emits, then folds them into the
/// gateway body. Organic-false-positive path re-queries the GCD
/// endpoint if AppsFlyer initially reports `af_status == "Organic"`.
///
/// When no Dev Key is packed yet (fresh project), the relay short-
/// circuits: both futures resolve immediately so the loading pipeline
/// does not stall for 30 seconds before falling back to the game.
class AttributionRelay {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installPayload;
  Map<String, dynamic>? _deepLinkPayload;
  Map<String, dynamic>? _resumePayload;

  final Completer<Map<String, dynamic>> _installGate =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkGate = Completer<void>();

  bool _armed = false;

  Future<void> ignite() async {
    if (_armed) return;
    _armed = true;

    final String devKey = JesterManifest.attributionKey;
    if (devKey.isEmpty) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: JesterManifest.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> payload = _flatten(raw);

      // AppsFlyer GCD can fail with {"status":"failure","data":"Launch
      // status code: 400"} when the dev key is not yet enabled for GCD
      // or the device is not registered. Forward an empty payload in
      // that case — leaking the error envelope into the gateway body
      // causes the backend to read `status=failure` and reject the
      // session, locking the user into native forever.
      final String? sdkStatus = payload['status']?.toString();
      if (sdkStatus == 'failure') {
        if (kDebugMode) {
          debugPrint('[AttributionRelay] GCD failure — ${payload['data']}; '
              'forwarding empty install payload');
        }
        _finishInstall(<String, dynamic>{});
        return;
      }

      final String? afStatus = payload['af_status']?.toString();
      if (afStatus == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: JesterManifest.organicRecheckDelaySeconds),
        );
        final Map<String, dynamic>? recheck = await _gcdRecheck();
        _installPayload = recheck ?? payload;
      } else {
        _installPayload = payload;
      }
      if (kDebugMode) {
        debugPrint('[AttributionRelay] install=$_installPayload');
      }
      _finishInstall(_installPayload ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic raw) {
      _resumePayload = _flatten(raw);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkPayload = Map<String, dynamic>.from(click);
      }
      _finishDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
    }
  }

  Future<Map<String, dynamic>> awaitInstallPayload({int seconds = 30}) {
    return _installGate.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> awaitDeepLink() {
    return _deepLinkGate.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  /// Whether an AppsFlyer OneLink click delivered a payload for this
  /// session (independent of whether it carries a usable destination).
  bool get hasDeepLink =>
      _deepLinkPayload != null && _deepLinkPayload!.isNotEmpty;

  /// Snapshot of the OneLink click event (media_source, campaign,
  /// deep_link_value, custom params, …). Empty map if none arrived.
  Map<String, dynamic> get deepLinkPayload =>
      _deepLinkPayload == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.unmodifiable(_deepLinkPayload!);

  /// Destination URL encoded inside the OneLink click event, if any.
  ///
  /// OneLinks configured for the gray flow put the partner URL under
  /// one of the well-known keys below (order = priority). Anything that
  /// does not start with `http`/`https` is treated as a token, not a
  /// URL, and rejected so we never try to `loadRequest` on garbage.
  String? deepLinkTargetUrl() {
    final Map<String, dynamic>? p = _deepLinkPayload;
    if (p == null || p.isEmpty) return null;
    const List<String> keys = <String>[
      'deep_link_value',
      'af_dp',
      'af_web_dp',
      'url',
      'target_url',
      'dp',
      'link',
      'af_link',
    ];
    for (final String key in keys) {
      final Object? raw = p[key];
      if (raw is! String) continue;
      final String v = raw.trim();
      if (v.isEmpty) continue;
      if (v.startsWith('http://') || v.startsWith('https://')) {
        return v;
      }
    }
    return null;
  }

  Future<String?> deviceUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Builds the merged gateway body per the config contract in
  /// `.cursor/rules/android_gray_guide.md §"Config Request Contract"`.
  Future<Map<String, dynamic>> assembleBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installPayload != null) body.addAll(_installPayload!);
    _deepLinkPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _resumePayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceUid() ?? '';
    body['bundle_id'] = JesterManifest.packageId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = JesterManifest.marketId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
      final String project = JesterManifest.messagingProject;
      if (project.isNotEmpty) {
        body['firebase_project_id'] = project;
      }
    }

    if (kDebugMode) {
      debugPrint('[GatewayRelay] request: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRecheck() async {
    try {
      final String? deviceId = await deviceUid();
      if (deviceId == null) return null;
      final String appId = Platform.isIOS
          ? JesterManifest.storeNumericId
          : JesterManifest.packageId;
      final String url = unveilGcdUrl(appId, deviceId);
      if (url.isEmpty) return null;

      final response = await jesterNet.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${JesterManifest.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall(Map<String, dynamic> data) {
    if (!_installGate.isCompleted) _installGate.complete(data);
  }

  void _finishDeepLink() {
    if (!_deepLinkGate.isCompleted) _deepLinkGate.complete();
  }

  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map(
        (dynamic k, dynamic v) =>
            MapEntry<String, dynamic>(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }
}
