import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../edge/attribution_relay.dart';
import '../edge/beacon_hub.dart';
import '../edge/depot.dart';
import '../edge/gateway_relay.dart';
import '../edge/link_probe.dart';
import '../pact/manifest.dart';
import '../screens/game/game_screen.dart';
import '../screens/menu/main_menu_screen.dart';
import '../screens/webview/web_view_screen.dart';
import 'portal_navigator.dart';

/// Root widget. Owns the long-lived shell modules and hands them to the
/// [PortalNavigator]. Named routes are kept for the white part
/// (MainMenu, Game, in-app browser) so the existing game code does not
/// have to know anything about the gray-flow shell that wraps it.
class PortalShell extends StatelessWidget {
  const PortalShell({
    super.key,
    required this.depot,
    required this.linkProbe,
    required this.attribution,
    required this.gateway,
    required this.beacon,
  });

  final Depot depot;
  final LinkProbe linkProbe;
  final AttributionRelay attribution;
  final GatewayRelay gateway;
  final BeaconHub beacon;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: JesterManifest.displayName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
        ),
      ),
      home: PortalNavigator(
        depot: depot,
        linkProbe: linkProbe,
        attribution: attribution,
        gateway: gateway,
        beacon: beacon,
      ),
      routes: <String, WidgetBuilder>{
        MainMenuScreen.route: (_) => const MainMenuScreen(),
        GameScreen.route: (_) => const GameScreen(),
      },
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == WebViewScreen.route) {
          final WebViewScreenArgs args =
              settings.arguments as WebViewScreenArgs;
          return MaterialPageRoute<void>(
            builder: (_) => WebViewScreen(args: args),
          );
        }
        return null;
      },
    );
  }
}
