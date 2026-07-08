import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import 'carnival_pill.dart';

/// Full-screen "No Signal" veil.
///
/// Shown when either:
///   • the very first launch has no internet at all, or
///   • the WebStage detects a connectivity drop mid-session.
///
/// Tapping Retry rebuilds whatever caller-supplied widget picks the
/// pipeline back up. The button is capped in width and its position is
/// gated by orientation so it never covers the artwork's illustration
/// on either portrait or landscape (see gray_part_pitfalls.md §18).
class NoSignalStage extends StatefulWidget {
  const NoSignalStage({super.key, required this.retryBuilder});

  final WidgetBuilder retryBuilder;

  @override
  State<NoSignalStage> createState() => _NoSignalStageState();
}

class _NoSignalStageState extends State<NoSignalStage> {
  bool _busy = false;

  Future<void> _handleRetry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.retryBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final Size size = mq.size;
    final String bg = landscape
        ? AppAssets.noSignalHorizontal
        : AppAssets.noSignalVertical;

    // Cutout-safe padding — landscape needs BOTH sides padded because
    // the camera notch may sit on the long edge (§14).
    final EdgeInsets safe = landscape
        ? EdgeInsets.only(
            left: mq.viewPadding.left,
            right: mq.viewPadding.right,
            top: mq.viewPadding.top,
          )
        : EdgeInsets.only(top: mq.viewPadding.top);

    final double buttonWidth = landscape
        ? (size.width * 0.30).clamp(200.0, 420.0)
        : (size.width * 0.66).clamp(220.0, 380.0);

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
                  colors: <Color>[Colors.transparent, Color(0xAA000000)],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * (landscape ? 0.09 : 0.10),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFC94D),
                          ),
                        ),
                      )
                    : CarnivalPill(
                        label: 'RETRY',
                        width: buttonWidth,
                        onTap: _handleRetry,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
