import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../pact/manifest.dart';
import '../pact/veiled_strings.dart';

/// Outgoing HTTP client + shared User-Agent forger.
///
/// The stock Dart HTTP client advertises `Dart/…` in its default UA
/// which is an instant "this is not a browser" tell. We overwrite it
/// with a device-authentic Chrome-on-Android string, sourced from
/// `device_info_plus` so two installs on different phones do NOT emit
/// identical UAs.
///
/// Jester Lucky is a slot-family theme (playing-card / lucky-coin), so
/// per `.cursor/rules/gray_user_agent.mdc` §2 we append the slot
/// identity suffix `appid/… appname/…`.
class MaskedNetClient extends http.BaseClient {
  MaskedNetClient({http.Client? delegate}) : _delegate = delegate ?? http.Client();

  final http.Client _delegate;

  // GAME THEME CATEGORY: slot (per .cursor/rules/gray_user_agent.mdc).
  // The appid/appname suffix has been intentionally disabled for this
  // build via `JesterManifest.appendSlotIdentity`.
  String _userAgent = 'Mozilla/5.0';

  /// Read-only accessor for the WebView so it can mirror the UA.
  String get userAgent => _userAgent;

  static const String _fallbackChrome = '149.0.7530.62';
  static const String _fallbackWebkit = '537.36';

  Future<void> prime() async {
    final String chrome = _pick(unveilChromeFragment(), _fallbackChrome);
    final String webkit = _pick(unveilWebkitFragment(), _fallbackWebkit);

    String core;
    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await plugin.androidInfo;
        final String tag = info.display.isNotEmpty ? info.display : info.id;
        core = 'Mozilla/5.0 (Linux; Android ${info.version.release}; '
            '${info.brand} ${info.model} Build/$tag) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await plugin.iosInfo;
        final String os = info.systemVersion.replaceAll('.', '_');
        core = 'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${info.systemVersion} Mobile/15E148 Safari/$webkit';
      } else {
        core = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UD1A) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      }
    } catch (_) {
      core = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UD1A) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit';
    }

    if (JesterManifest.appendSlotIdentity) {
      final String pascal = JesterManifest.displayName.replaceAll(' ', '');
      core = '$core appid/${JesterManifest.packageId} appname/$pascal';
    }
    _userAgent = core;
  }

  static String _pick(String value, String fallback) =>
      value.isNotEmpty ? value : fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _userAgent);
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Singleton net client shared by every edge module.
final MaskedNetClient jesterNet = MaskedNetClient();
