import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity helper.
///
/// The stock adapter state is not enough — captive portals report a
/// connected adapter without real internet. `isReachable()` follows the
/// adapter check with a DNS probe against a well-known host (Cloudflare
/// public resolver) with a 7 s ceiling.
///
/// The 7 s ceiling is deliberate: a genuinely offline device throws a
/// SocketException instantly (no route), so waiting longer only helps
/// VPN-tunnelled clients whose DNS is slow to warm up. Anything shorter
/// than that produces false negatives on VPN.
class LinkProbe {
  LinkProbe({Connectivity? connectivity})
      : _plugin = connectivity ?? Connectivity();

  final Connectivity _plugin;

  // Whitelisted adapter kinds. VPN, bluetooth and "other" are treated
  // as real connectivity — dropping them turns real users into false
  // negatives (see .cursor/rules/gray_part_pitfalls.md §3).
  static const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  static const List<String> _probeHosts = <String>[
    'cloudflare.com',
    'one.one.one.one',
  ];

  Future<bool> isReachable() async {
    final List<ConnectivityResult> results = await _plugin.checkConnectivity();
    final bool anyLive = results.any(_liveAdapters.contains);
    if (!anyLive) return false;

    for (final String host in _probeHosts) {
      try {
        final List<InternetAddress> probe = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 7));
        if (probe.isNotEmpty && probe.first.rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // Try the next host — a single-host DNS blackhole is still
        // reachable through the fallback.
      }
    }
    return false;
  }

  /// Live adapter changes. Consumers should debounce ~700 ms before
  /// reacting to bursts of `none` results, otherwise VPN toggling
  /// produces false-positive offline flashes.
  Stream<List<ConnectivityResult>> get changes =>
      _plugin.onConnectivityChanged;
}
