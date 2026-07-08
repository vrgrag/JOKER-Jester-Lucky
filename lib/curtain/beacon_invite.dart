import 'package:flutter/material.dart';

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
class BeaconInvite extends StatelessWidget {
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

  Future<void> _accept(BuildContext context) async {
    final bool granted = await beacon.askForPermission();
    if (!granted) {
      await depot.writeInviteResumeAt(_cooldownExpiry());
    }
    if (context.mounted) _forwardToReader(context);
  }

  Future<void> _skip(BuildContext context) async {
    await depot.writeInviteResumeAt(_cooldownExpiry());
    if (context.mounted) _forwardToReader(context);
  }

  int _cooldownExpiry() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      JesterManifest.beaconInviteCooldownSeconds;

  void _forwardToReader(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReaderStage(
          destination: destination,
          depot: depot,
          beacon: beacon,
          linkProbe: linkProbe,
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

    // Cutout-safe padding for landscape notch (§14).
    final EdgeInsets safe = landscape
        ? EdgeInsets.only(
            left: mq.viewPadding.left,
            right: mq.viewPadding.right,
            top: mq.viewPadding.top,
          )
        : EdgeInsets.only(top: mq.viewPadding.top);

    final double acceptWidth = landscape
        ? (size.width * 0.34).clamp(220.0, 440.0)
        : (size.width * 0.70).clamp(220.0, 420.0);
    final double skipWidth = landscape
        ? acceptWidth * 0.7
        : acceptWidth * 0.55;

    return Scaffold(
      backgroundColor: const Color(0xFF120521),
      body: Padding(
        padding: safe,
        child: Stack(
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
                    onTap: () => _accept(context),
                  ),
                  SizedBox(height: landscape ? 10 : 16),
                  CarnivalGhostChip(
                    label: 'SKIP',
                    width: skipWidth,
                    compact: landscape,
                    onTap: () => _skip(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
