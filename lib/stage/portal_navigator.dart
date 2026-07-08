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
  final List<String> _diagLog = <String>[];

  void _stamp(String line) {
    // ignore: avoid_print
    debugPrint('[Jester][Portal] $line');
    if (!mounted) return;
    setState(() {
      _diagLog.add(line);
      if (_diagLog.length > 8) _diagLog.removeAt(0);
    });
  }

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    widget.beacon.onTokenRotated = _rebroadcastToken;
    // Gray splash screens are portrait-only. ReaderStage unlocks all
    // orientations when it opens; the game locks back to portrait itself.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
    _stamp('drive: priming beacon');
    await widget.beacon.prime();
    _bumpProgress(0.22);

    PortalKind kind = widget.depot.readPortalKind();
    _stamp('stored kind=${kind.name}');
    _stamp('endpoint present=${JesterManifest.gatewayEndpoint.isNotEmpty}');

    if (kind == PortalKind.native &&
        JesterManifest.gatewayEndpoint.isNotEmpty) {
      _stamp('resetting stale native -> pending');
      await widget.depot.writePortalKind(PortalKind.pending);
      kind = PortalKind.pending;
    }

    switch (kind) {
      case PortalKind.native:
        _stamp('-> native (game)');
        await _openGame(initialLift: 0.4);
        break;
      case PortalKind.web:
        _stamp('-> resumeGray');
        await _resumeGrayFlow();
        break;
      case PortalKind.pending:
        _stamp('-> boot');
        await _boot();
        break;
    }
  }

  Future<void> _boot() async {
    if (JesterManifest.gatewayEndpoint.isEmpty) {
      _stamp('boot: endpoint EMPTY -> game');
      await widget.depot.writePortalKind(PortalKind.native);
      await _openGame(initialLift: 0.4);
      return;
    }

    _stamp('boot: probing internet');
    final bool online = await widget.linkProbe.isReachable();
    _stamp('boot: online=$online');
    if (!online) {
      _stamp('boot: no internet -> NoSignal');
      _routeToNoSignal();
      return;
    }
    _bumpProgress(0.42);

    _stamp('boot: igniting AppsFlyer');
    await widget.attribution.ignite();
    _stamp('boot: waiting install+deeplink');
    await Future.wait<void>(<Future<void>>[
      widget.attribution.awaitInstallPayload(),
      widget.attribution.awaitDeepLink(),
    ]);
    _stamp('boot: attribution ready');
    _bumpProgress(0.68);

    _stamp('boot: calling gateway');
    final GateVerdict verdict = await _askGateway();
    _stamp('boot: verdict granted=${verdict.granted} '
        'hasDest=${verdict.hasDestination} remark=${verdict.remark}');

    if (verdict.granted && verdict.hasDestination) {
      _stamp('boot: -> gray ${verdict.destination}');
      await widget.depot.writePortalKind(PortalKind.web);
      _bumpProgress(1.0);
      await _settle();
      _routeToGray(verdict.destination!);
      return;
    }

    final String? cached = await widget.depot.readCachedDestination();
    _stamp('boot: cached=${cached ?? "<none>"}');
    if (cached != null && cached.isNotEmpty) {
      _stamp('boot: -> gray via cache');
      await widget.depot.writePortalKind(PortalKind.web);
      _bumpProgress(1.0);
      await _settle();
      _routeToGray(cached);
      return;
    }

    _stamp('boot: no cache -> NoSignal');
    _routeToNoSignal();
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

    final GateVerdict verdict = await _askGateway();
    _bumpProgress(1.0);
    await _settle();

    if (verdict.granted && verdict.hasDestination) {
      _routeToGray(verdict.destination!);
    } else if (cached != null && cached.isNotEmpty) {
      _routeToGray(cached);
    } else {
      _routeToNoSignal();
    }
  }

  Future<GateVerdict> _askGateway() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.attribution.assembleBody(
      locale: locale,
      pushToken: widget.beacon.token,
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
    final Size size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            IgnorePointer(
              child: Image.asset(
                AppAssets.loadingVertical,
                fit: BoxFit.cover,
                width: size.width,
                height: size.height,
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Color(0xAA000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 32,
              right: 32,
              bottom: size.height * 0.14,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _dots,
                      builder: (BuildContext context, _) {
                        final int n = (_dots.value * 4).floor() % 4;
                        return Text(
                          'Loading${'.' * n}',
                          style: jesterTextStyle(size: 22, color: AppColors.goldLight),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    GoldProgressBar(progress: _progress),
                  ],
                ),
              ),
            ),
            // Diagnostic panel — visible in release too. Tap to copy the
            // log to the clipboard for support.
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () async {
                  final String text = _diagLog.join('\n');
                  await Clipboard.setData(ClipboardData(text: text));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Log copied. Send it to support.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'DIAG (long-press to copy)',
                        style: TextStyle(
                          color: Color(0xFFFFC94D),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      for (final String line in _diagLog)
                        Text(
                          line,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.15,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
