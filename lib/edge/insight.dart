import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/foundation.dart';

import '../pact/insight_env.dart';

// ============================================================
// INSIGHT — crash-safe facade over Microsoft Clarity
// ============================================================
// Session replay captures the native Flutter surface (loading, beacon
// invite, menu, game, and the WebView CONTAINER). The partner site's
// DOM inside the WebView is NOT recorded — the funnel signals below
// are what actually answer "where did the paid user drop off?".
//
// Every call is guarded: a Clarity error must NEVER bubble into the
// gray flow. See .cursor/rules/clarity_analytics.mdc (mirrored from
// gray_part_flow — same event/tag vocabulary, same dashboard slices).
//
// Do NOT call the Clarity SDK directly anywhere else in the app — go
// through this facade so guards + string clipping stay centralized.
// ============================================================

class Insight {
  const Insight._();

  static ClarityConfig get config => ClarityConfig(
        projectId: kJesterClarityProjectId,
        // Verbose only while wiring a new project (dashboard can take
        // ~2h to show the first session). Stays silent in release.
        logLevel: kDebugMode ? LogLevel.Verbose : LogLevel.None,
      );

  /// Group the session by AppsFlyer id + attach attribution tags.
  /// Never wipes a good user id with an empty one — the af_id can
  /// arrive on a later launch and it must stitch to the same user.
  static void identify(String? aid, {Map<String, String> tags = const {}}) {
    if (aid != null && aid.isNotEmpty) {
      _guard(() => Clarity.setCustomUserId(_clip(aid, 255)));
      tag('aid', aid);
    }
    tags.forEach(tag);
  }

  /// Native screen: sets the label AND emits a stable per-screen event.
  static void screen(String name) {
    screenName(name);
    event('screen_$name');
  }

  /// Sets the current screen label + mirrors it into the persistent
  /// `last_screen` tag. Clarity keeps the LAST tag value per session,
  /// so filtering by `last_screen` instantly shows the drop-off screen.
  static void screenName(String name) => _guard(() {
        Clarity.setCurrentScreenName(_clip(name, 255));
        Clarity.setCustomTag('last_screen', _clip(name, 255));
      });

  static void event(String name) =>
      _guard(() => Clarity.sendCustomEvent(_clip(name, 254)));

  static void tag(String key, String value) {
    if (value.isEmpty) return;
    _guard(() => Clarity.setCustomTag(key, _clip(value, 255)));
  }

  static String _clip(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);

  static void _guard(void Function() body) {
    try {
      body();
    } catch (_) {}
  }
}
