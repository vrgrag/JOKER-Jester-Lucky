import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../curtain/beacon_invite.dart';
import '../curtain/no_signal_stage.dart';
import '../curtain/reader_stage.dart';
import '../edge/attribution_relay.dart';
import '../edge/beacon_hub.dart';
import '../edge/depot.dart';
import '../edge/gateway_relay.dart';
import '../edge/insight.dart';
import '../edge/link_probe.dart';
import '../pact/manifest.dart';
import '../screens/menu/main_menu_screen.dart';
import '../services/storage_service.dart';
import '../signals/gate_verdict.dart';
import '../signals/portal_kind.dart';
import '../widgets/gold_progress_bar.dart';

/// Loading screen + gray/native routing brain.
///
/// State machine follows `.cursor/rules/android_gray_guide.md
/// §"Gray Flow State Machine"`. Deviations are called out inline.
///
/// The white part of the app (native game) MUST launch even without
/// internet — the requirement is enforced by two branches:
///   1. If no gateway endpoint has been packed yet, the pipeline
///      commits `PortalKind.native` immediately without touching the
///      network — the app is shippable for review before the manager
///      delivers config credentials.
///   2. On any returning launch already flagged `native`, we skip the
///      whole attribution / gate loop and warm the game assets.
class PortalNavigator extends StatefulWidget {
  const PortalNavigator({
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
  State<PortalNavigator> createState() => _PortalNavigatorState();
}

class _PortalNavigatorState extends State<PortalNavigator>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  bool _committed = false;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    widget.beacon.onTokenRotated = _rebroadcastToken;
    // Re-assert immersive mode each time this screen builds — covers the
    // case where the game or a previous route restored the system bars.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Insight.screen('loading');
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    widget.beacon.onTokenRotated = null;
    _dots.dispose();
    super.dispose();
  }

  void _bumpProgress(double next) {
    if (!mounted) return;
    if (next <= _progress) return;
    setState(() => _progress = next);
  }

  Future<void> _drive() async {
    _bumpProgress(0.12);
    await widget.beacon.prime();
    _bumpProgress(0.22);

    // In debug builds always re-run the gateway pipeline. A single prior
    // test session that got explicitly rejected by the server (Organic
    // status, blocked, etc.) permanently commits `PortalKind.native` —
    // after that the app boots straight into the game and gray is never
    // reachable again. That is desired in production but murder while
    // iterating on the gray flow locally.
    PortalKind kind = widget.depot.readPortalKind();
    if (kDebugMode && kind == PortalKind.native) {
      await widget.depot.writePortalKind(PortalKind.pending);
      kind = PortalKind.pending;
    }

    switch (kind) {
      case PortalKind.native:
        // Returning "committed native" install — skip the whole
        // attribution / gateway loop. Tag the run mode so drop-off
        // analysis can exclude native sessions from the offer funnel.
        Insight.tag('run_mode', 'native');
        Insight.event('route_native');
        await _openGame(initialLift: 0.4);
        break;
      case PortalKind.web:
        await _resumeGrayFlow();
        break;
      case PortalKind.pending:
        await _boot();
        break;
    }
  }

  Future<void> _boot() async {
    // "White part must launch even without internet." If credentials
    // are still empty (fresh template / pre-launch), skip the whole
    // pipeline and go straight to the game.
    if (JesterManifest.gatewayEndpoint.isEmpty) {
      await widget.depot.writePortalKind(PortalKind.native);
      Insight.tag('run_mode', 'native');
      Insight.event('route_native');
      await _openGame(initialLift: 0.4);
      return;
    }

    if (!await widget.linkProbe.isReachable()) {
      _routeToNoSignal();
      return;
    }
    _bumpProgress(0.42);

    await widget.attribution.ignite();
    await Future.wait<void>(<Future<void>>[
      widget.attribution.awaitInstallPayload(),
      widget.attribution.awaitDeepLink(),
    ]);
    _bumpProgress(0.68);

    // OneLink short-circuit — if AppsFlyer delivered a click event with
    // a usable destination URL, we ALREADY know this session must go
    // gray. Skip the gateway round-trip entirely and load the OneLink
    // target directly; the gateway is only there to make the routing
    // decision for cold organic installs.
    if (await _tryRouteFromOneLink()) return;

    final GateVerdict verdict = await _askGateway();
    if (verdict.granted && verdict.hasDestination) {
      await widget.depot.writePortalKind(PortalKind.web);
      Insight.tag('run_mode', 'web');
      Insight.event('route_web');
      _bumpProgress(1.0);
      await _settle();
      _routeToGray(verdict.destination!);
    } else if (verdict.isTransportError) {
      // Server unreachable (404, timeout, DNS failure) — do NOT lock the
      // user into native permanently. Keep PortalKind.pending so the next
      // launch retries. Show the game for this session only.
      Insight.tag('run_mode', 'native');
      Insight.tag('route_reason', 'gateway_transport_error');
      Insight.event('route_native');
      await _openGame(initialLift: 0.86);
    } else {
      // Server explicitly rejected (organic, blocked, etc.) — commit native.
      await widget.depot.writePortalKind(PortalKind.native);
      Insight.tag('run_mode', 'native');
      Insight.tag('route_reason', 'gateway_rejected');
      Insight.event('route_native');
      await _openGame(initialLift: 0.86);
    }
  }

  Future<void> _resumeGrayFlow() async {
    if (!await widget.linkProbe.isReachable()) {
      _bumpProgress(1.0);
      _routeToNoSignal();
      return;
    }
    _bumpProgress(0.42);

    final String? pending = await widget.depot.takePendingLink();
    if (pending != null) {
      // Warm push tap during boot — user tapped a notification and we
      // have a hot link. Separate route event so push-driven sessions
      // can be sliced from organic web returns in the dashboard.
      Insight.tag('run_mode', 'web');
      Insight.event('route_push_link');
      _bumpProgress(1.0);
      await _settle();
      _routeToGray(pending);
      return;
    }

    final String? cached = await widget.depot.readCachedDestination();

    await widget.attribution.ignite();
    await Future.wait<void>(<Future<void>>[
      widget.attribution.awaitInstallPayload(seconds: 10),
      widget.attribution.awaitDeepLink(),
    ]);
    _bumpProgress(0.72);

    // OneLink short-circuit for a returning user — same logic as _boot:
    // a click with a valid destination URL forces gray regardless of
    // what the gateway would say for this device.
    if (await _tryRouteFromOneLink()) return;

    final GateVerdict verdict = await _askGateway();
    _bumpProgress(1.0);
    await _settle();

    if (verdict.granted && verdict.hasDestination) {
      Insight.tag('run_mode', 'web');
      Insight.event('route_web');
      _routeToGray(verdict.destination!);
    } else if (cached != null && cached.isNotEmpty) {
      // Server down or rejected but we have a cached URL — keep showing gray.
      Insight.tag('run_mode', 'web');
      Insight.event('route_cached_link');
      _routeToGray(cached);
    } else {
      _routeToNoSignal();
    }
  }

  /// Returns `true` when a OneLink click was detected and the user was
  /// routed to the gray flow (caller must `return` immediately).
  ///
  /// Two routing strategies:
  ///   1. OneLink carries a real `https://…` destination in
  ///      `deep_link_value` / `af_dp` etc. → load it directly.
  ///   2. OneLink click detected but no URL in the payload
  ///      (e.g. `deep_link_value=some_token`) → use the gateway verdict
  ///      instead, but FORCE it to succeed: if the gateway returns
  ///      `ok:true` we take the URL; otherwise we fall back to the last
  ///      cached URL so the user always ends up in gray on a OneLink tap.
  Future<bool> _tryRouteFromOneLink() async {
    if (!widget.attribution.hasDeepLink) return false;

    // Tag the OneLink session regardless of which path we take below.
    Insight.tag('gray_source', 'onelink');
    final Map<String, dynamic> click = widget.attribution.deepLinkPayload;
    final String? media = click['media_source']?.toString();
    final String? campaign = click['campaign']?.toString();
    if (media != null && media.isNotEmpty) Insight.tag('onelink_source', media);
    if (campaign != null && campaign.isNotEmpty) {
      Insight.tag('onelink_campaign', campaign);
    }

    // Strategy 1: OneLink embeds a real URL → use it directly.
    final String? directUrl = widget.attribution.deepLinkTargetUrl();
    if (directUrl != null && directUrl.isNotEmpty) {
      await widget.depot.writeCachedDestination(directUrl);
      await widget.depot.writePortalKind(PortalKind.web);
      Insight.tag('run_mode', 'web');
      Insight.event('route_web_onelink');
      _bumpProgress(1.0);
      await _settle();
      _routeToGray(directUrl);
      return true;
    }

    // Strategy 2: OneLink has no embedded URL — ask the gateway and
    // force the result to be gray. If gateway succeeds, use its URL.
    // If gateway fails, use the last cached URL (may be from a prior
    // session). If nothing is cached, fall through to normal routing.
    final GateVerdict verdict = await _askGateway();
    if (verdict.granted && verdict.hasDestination) {
      await widget.depot.writePortalKind(PortalKind.web);
      Insight.tag('run_mode', 'web');
      Insight.event('route_web_onelink');
      _bumpProgress(1.0);
      await _settle();
      _routeToGray(verdict.destination!);
      return true;
    }
    final String? cached = await widget.depot.readCachedDestination();
    if (cached != null && cached.isNotEmpty) {
      await widget.depot.writePortalKind(PortalKind.web);
      Insight.tag('run_mode', 'web');
      Insight.event('route_web_onelink_cached');
      _bumpProgress(1.0);
      await _settle();
      _routeToGray(cached);
      return true;
    }

    // No usable URL anywhere — let normal boot decide.
    return false;
  }

  Future<GateVerdict> _askGateway() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.attribution.assembleBody(
      locale: locale,
      pushToken: widget.beacon.token,
    );
    // Attribution + af_id are only known AFTER assembleBody — stitch the
    // Clarity session to the AppsFlyer user id here so every subsequent
    // event (route_*, screen_*, web_*) lands on the correct user in the
    // dashboard. Empty af_id must NOT overwrite a good id (guarded in
    // Insight.identify).
    Insight.identify(
      body['af_id']?.toString(),
      tags: <String, String>{
        'af_status': body['af_status']?.toString() ?? '',
        'media_source': body['media_source']?.toString() ?? '',
        'campaign': body['campaign']?.toString() ?? '',
        'os': body['os']?.toString() ?? '',
        'locale': body['locale']?.toString() ?? '',
      },
    );
    return widget.gateway.query(body);
  }

  void _rebroadcastToken(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.attribution.assembleBody(
      locale: locale,
      pushToken: token,
    );
    widget.gateway.query(body);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  Future<void> _openGame({required double initialLift}) async {
    _bumpProgress(initialLift);
    // Portrait-only gameplay.
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Warm up the shared storage + every game asset before the menu
    // appears so the first frame of MainMenuScreen has no jank.
    await StorageService.getInstance();
    _bumpProgress(initialLift + 0.05);
    if (mounted) await _precacheGameArt();
    _bumpProgress(1.0);
    await _settle();
    if (_committed || !mounted) return;
    _committed = true;
    Navigator.of(context).pushReplacementNamed(MainMenuScreen.route);
  }

  Future<void> _precacheGameArt() async {
    final int total = AppAssets.gameArt.length;
    int done = 0;
    for (final String path in AppAssets.gameArt) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
      done++;
      // Ramp the progress from wherever we started up to 0.98 as art
      // decodes complete.
      final double target =
          _progress + ((0.98 - _progress) * (done / total)).clamp(0.0, 1.0);
      _bumpProgress(target);
    }
  }

  void _routeToGray(String destination) {
    if (_committed || !mounted) return;
    _committed = true;
    if (widget.depot.shouldRaiseBeaconInvite()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BeaconInvite(
            depot: widget.depot,
            beacon: widget.beacon,
            linkProbe: widget.linkProbe,
            destination: destination,
          ),
        ),
      );
    } else {
      // Returning user skipping the invite — classify notif state now so
      // the `notif_permission` tag is never blank for these sessions.
      // (BeaconInvite tags this itself when it IS shown; the two paths
      // are mutually exclusive.)
      final String state = widget.depot.isBeaconGranted()
          ? 'granted'
          : widget.depot.isBeaconOsBlocked()
              ? 'os_denied'
              : 'snoozed';
      Insight.tag('notif_permission', state);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReaderStage(
            destination: destination,
            depot: widget.depot,
            beacon: widget.beacon,
            linkProbe: widget.linkProbe,
          ),
        ),
      );
    }
  }

  void _routeToNoSignal() {
    if (_committed || !mounted) return;
    _committed = true;
    Insight.event('route_offline');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalStage(
          retryBuilder: (_) => PortalNavigator(
            depot: widget.depot,
            linkProbe: widget.linkProbe,
            attribution: widget.attribution,
            gateway: widget.gateway,
            beacon: widget.beacon,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final Size size = mq.size;
    final String bg =
        landscape ? AppAssets.loadingHorizontal : AppAssets.loadingVertical;

    return IgnorePointer(
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.ink,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                bg,
                fit: BoxFit.cover,
                width: size.width,
                height: size.height,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Color(0xAA000000)],
                  ),
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                bottom: size.height * (landscape ? 0.12 : 0.14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _dots,
                      builder: (BuildContext context, _) {
                        final int n = (_dots.value * 4).floor() % 4;
                        return Text(
                          'Loading${'.' * n}',
                          style: jesterTextStyle(
                            size: landscape ? 20 : 22,
                            color: AppColors.goldLight,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: landscape ? 12 : 16),
                    GoldProgressBar(progress: _progress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
