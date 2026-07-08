import 'civic_links.dart';
import 'veiled_strings.dart';

/// Single access point for app-wide constants.
///
/// Identity fields are plain because they must match the platform-level
/// declarations (AndroidManifest, google-services.json). Endpoints /
/// keys resolve lazily through the scrambler.
class JesterManifest {
  JesterManifest._();

  // ── Identity ────────────────────────────────────────────────
  static const String packageId = 'com.joker.jesterlucky';
  static const String marketId = 'com.joker.jesterlucky';
  static const String displayName = 'Jester Lucky';

  // iOS App Store numeric id — unused for Android-only build. Kept for
  // interface symmetry with the shared gateway body.
  static const String storeNumericId = '';

  // ── Resolved endpoints / credentials ────────────────────────
  static String get gatewayEndpoint => unveilGatewayUrl();
  static String get attributionKey => unveilAttributionKey();
  static String get messagingProject => unveilMessagingProject();

  // ── Public links ────────────────────────────────────────────
  static const String privacyUrl = jesterPrivacyPolicy;
  static const String supportUrl = jesterSupportPortal;
  static const String homeUrl = jesterSiteHome;

  // ── Behaviour knobs ─────────────────────────────────────────
  /// Push-invite re-prompt cooldown after a Skip — 3 days (per TZ).
  static const int beaconInviteCooldownSeconds = 3 * 24 * 60 * 60;

  /// Delay before AppsFlyer GCD re-check when the first callback
  /// reports (possibly false) `Organic` status.
  static const int organicRecheckDelaySeconds = 5;

  /// Max time the shell waits for the loading bar to reach 100 %
  /// before the actual routing decision fires (visual only).
  static const int expectedBootMs = 4000;

  /// Suffix appended to the User-Agent when the game is slot-themed.
  /// Disabled on this build per project request — the plain Chrome UA
  /// is emitted from both the HTTP client and the WebView.
  static const bool appendSlotIdentity = false;
}
