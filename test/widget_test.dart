// Smoke test: the shell boots into the loading portal without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jester_lucky_shell/edge/attribution_relay.dart';
import 'package:jester_lucky_shell/edge/beacon_hub.dart';
import 'package:jester_lucky_shell/edge/depot.dart';
import 'package:jester_lucky_shell/edge/gateway_relay.dart';
import 'package:jester_lucky_shell/edge/link_probe.dart';
import 'package:jester_lucky_shell/stage/portal_shell.dart';

void main() {
  testWidgets('Shell renders the initial loading screen', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final Depot depot = Depot();
    // In-memory prefs are provided by the test binding; warmUp is safe.
    await depot.warmUp();
    final LinkProbe linkProbe = LinkProbe();
    final AttributionRelay attribution = AttributionRelay();
    final GatewayRelay gateway = GatewayRelay(depot);
    final BeaconHub beacon = BeaconHub(depot);

    await tester.pumpWidget(PortalShell(
      depot: depot,
      linkProbe: linkProbe,
      attribution: attribution,
      gateway: gateway,
      beacon: beacon,
    ));
    await tester.pump();

    expect(find.byType(Scaffold), findsWidgets);
  });
}
