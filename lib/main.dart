import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'edge/agent_forge.dart';
import 'edge/attribution_relay.dart';
import 'edge/beacon_hub.dart';
import 'edge/depot.dart';
import 'edge/gateway_relay.dart';
import 'edge/insight.dart';
import 'edge/link_probe.dart';
import 'stage/portal_shell.dart';

// ============================================================
// Jester Lucky — entry point
// ============================================================
// Boot order:
//   1. WidgetsFlutterBinding — required before touching plugins.
//   2. Firebase + AppCheck — best-effort. If google-services.json is
//      absent (fresh scaffold before the manager ships credentials),
//      init fails silently and the shell degrades to the offline /
//      game path.
//   3. Every orientation is enabled — the loading + web stages need to
//      rotate. The game re-locks to portrait inside PortalNavigator.
//   4. Status bar transparent + light icons — the loading artwork
//      goes edge-to-edge.
//   5. `jesterNet.prime()` — builds the forged device UA used by BOTH
//      the config HTTP call and the WebView. See
//      `.cursor/rules/gray_user_agent.mdc`.
//   6. `Depot.warmUp()` — reads SharedPreferences into memory so the
//      first frame of the PortalNavigator can decide the route
//      synchronously.
//   7. Edge modules are constructed but not yet primed — PushHub /
//      AttributionRelay boot inside the navigator after the UI is up.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check are optional until credentials land — the
  // config path treats a missing key as a graceful "no gray flow yet".
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  // Hide status bar + nav bar for all gray screens (loading, no-signal,
  // beacon-invite). The game and ReaderStage re-call this themselves.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await jesterNet.prime();

  final Depot depot = Depot();
  await depot.warmUp();

  final LinkProbe linkProbe = LinkProbe();
  final AttributionRelay attribution = AttributionRelay();
  final GatewayRelay gateway = GatewayRelay(depot);
  final BeaconHub beacon = BeaconHub(depot);

  // ClarityWidget must wrap the app root so session replay + custom
  // events see every route in the tree. See
  // .cursor/rules/clarity_analytics.mdc §1 (project id lives in
  // pact/insight_env.dart, guarded facade in edge/insight.dart).
  runApp(ClarityWidget(
    clarityConfig: Insight.config,
    app: PortalShell(
      depot: depot,
      linkProbe: linkProbe,
      attribution: attribution,
      gateway: gateway,
      beacon: beacon,
    ),
  ));
}
