import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../signals/portal_kind.dart';

/// Persistence layer for the shell.
///
/// Plain flags live in [SharedPreferences]. URLs and the pending push
/// link go through [FlutterSecureStorage] because they carry partner
/// domains we would rather not have visible in a plain prefs dump.
///
/// All prefs keys start with `jd_` (short for "jester depot") to avoid
/// clashing with any dependency's own storage. The literal short keys
/// also read as noise instead of intent to a curious reviewer.
class Depot {
  Depot({FlutterSecureStorage? secure})
      : _vault = secure ?? const FlutterSecureStorage();

  static const String _kPortal = 'jd_portal_kind';
  static const String _kCachedLink = 'jd_cached_link';
  static const String _kLinkExpiry = 'jd_link_expiry';
  static const String _kInviteResumeAt = 'jd_invite_resume_at';
  static const String _kBeaconGranted = 'jd_beacon_granted';
  static const String _kBeaconOsBlocked = 'jd_beacon_os_blocked';
  static const String _kPendingLink = 'jd_pending_link';

  final FlutterSecureStorage _vault;
  SharedPreferences? _prefs;

  Future<void> warmUp() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    final SharedPreferences? p = _prefs;
    if (p == null) {
      throw StateError('Depot.warmUp() must be awaited before use.');
    }
    return p;
  }

  // ── Portal kind ──────────────────────────────────────────
  PortalKind readPortalKind() => PortalKind.decode(_p.getString(_kPortal));

  Future<void> writePortalKind(PortalKind kind) =>
      _p.setString(_kPortal, kind.encode());

  // ── Cached content link (secure) ─────────────────────────
  Future<String?> readCachedDestination() => _vault.read(key: _kCachedLink);

  Future<void> writeCachedDestination(String link) =>
      _vault.write(key: _kCachedLink, value: link);

  // ── Link expiry ──────────────────────────────────────────
  int? readLinkExpiry() => _p.getInt(_kLinkExpiry);

  Future<void> writeLinkExpiry(int unixSeconds) =>
      _p.setInt(_kLinkExpiry, unixSeconds);

  bool isLinkStale() {
    final int? expiry = readLinkExpiry();
    if (expiry == null) return true;
    return _nowSeconds() >= expiry;
  }

  // ── Beacon permission state ──────────────────────────────
  bool isBeaconGranted() => _p.getBool(_kBeaconGranted) ?? false;

  Future<void> setBeaconGranted(bool granted) =>
      _p.setBool(_kBeaconGranted, granted);

  bool isBeaconOsBlocked() => _p.getBool(_kBeaconOsBlocked) ?? false;

  Future<void> markBeaconOsBlocked() =>
      _p.setBool(_kBeaconOsBlocked, true);

  int? readInviteResumeAt() => _p.getInt(_kInviteResumeAt);

  Future<void> writeInviteResumeAt(int unixSeconds) =>
      _p.setInt(_kInviteResumeAt, unixSeconds);

  /// Whether the beacon-invite screen should be shown before the WebView.
  bool shouldRaiseBeaconInvite() {
    if (isBeaconGranted()) return false;
    if (isBeaconOsBlocked()) return false;
    final int? resume = readInviteResumeAt();
    if (resume == null) return true;
    return _nowSeconds() >= resume;
  }

  // ── Pending push link (secure, one-shot) ─────────────────
  Future<void> stashPendingLink(String? link) async {
    if (link == null) {
      await _vault.delete(key: _kPendingLink);
    } else {
      await _vault.write(key: _kPendingLink, value: link);
    }
  }

  Future<String?> takePendingLink() async {
    final String? link = await _vault.read(key: _kPendingLink);
    if (link != null) await _vault.delete(key: _kPendingLink);
    return link;
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
