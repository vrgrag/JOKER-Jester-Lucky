import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_assets.dart';
import '../edge/beacon_hub.dart';
import '../edge/depot.dart';
import '../edge/link_probe.dart';
import '../pact/manifest.dart';
import 'carnival_pill.dart';
import 'reader_stage.dart';

/// Push-permission promo shown once (per cooldown) before the WebView.
///
/// The "Accept" button raises the OS permission dialog; "Skip" arms a
/// cooldown so we do not badger the same user every launch. Either way
/// the user then continues to the actual content in [ReaderStage].
class BeaconInvite extends StatefulWidget {
  const BeaconInvite({
    super.key,
    required this.depot,
    required this.beacon,
    required this.linkProbe,
    required this.destination,
  });

  final Depot depot;
  final BeaconHub beacon;
  final LinkProbe linkProbe;
  final String destination;

  @override
  State<BeaconInvite> createState() => _BeaconInviteState();
}

class _BeaconInviteState extends State<BeaconInvite>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _accept() async {
    final bool granted = await widget.beacon.askForPermission();
    if (!granted) {
      await widget.depot.writeInviteResumeAt(_cooldownExpiry());
    }
    if (mounted) _forwardToReader();
  }

  Future<void> _skip() async {
    await widget.depot.writeInviteResumeAt(_cooldownExpiry());
    if (mounted) _forwardToReader();
  }

  int _cooldownExpiry() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      JesterManifest.beaconInviteCooldownSeconds;

  void _forwardToReader() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReaderStage(
          destination: widget.destination,
          depot: widget.depot,
          beacon: widget.beacon,
          linkProbe: widget.linkProbe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size size = mq.size;
    final bool landscape = mq.orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.beaconHorizontal
        : AppAssets.beaconVertical;

    final double acceptWidth = landscape
        ? (size.width * 0.34).clamp(220.0, 440.0)
        : (size.width * 0.70).clamp(220.0, 420.0);
    final double skipWidth = landscape
        ? acceptWidth * 0.7
        : acceptWidth * 0.55;

    return Scaffold(
      backgroundColor: const Color(0xFF120521),
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
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.07 : 0.08),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CarnivalPill(
                  label: 'ACCEPT',
                  width: acceptWidth,
                  compact: landscape,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 10 : 16),
                CarnivalGhostChip(
                  label: 'SKIP',
                  width: skipWidth,
                  compact: landscape,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
