import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_assets.dart';
import '../../core/app_theme.dart';
import '../../services/storage_service.dart';
import '../../widgets/gold_progress_bar.dart';
import '../../widgets/loading_dots_text.dart';
import '../menu/main_menu_screen.dart';

/// First screen shown. Supports both portrait and landscape (the only
/// screen allowed to rotate) while it genuinely preloads every art asset
/// and local service the game needs, then locks the app to portrait.
class SplashScreen extends StatefulWidget {
  static const route = '/';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final steps = <Future<void> Function()>[
      () => StorageService.getInstance(),
      for (final path in AppAssets.all) () => precacheImage(AssetImage(path), context),
    ];

    final total = steps.length;
    var done = 0;

    // Each step must actually finish before progress advances - the bar
    // can only report real, completed work and therefore can never reach
    // 100% before the app is genuinely ready.
    for (final step in steps) {
      final stopwatch = Stopwatch()..start();
      await step();
      const minStepDuration = Duration(milliseconds: 70);
      if (stopwatch.elapsed < minStepDuration) {
        await Future.delayed(minStepDuration - stopwatch.elapsed);
      }
      done++;
      if (!mounted) return;
      setState(() => _progress = done / total);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _navigated) return;
    _navigated = true;

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(MainMenuScreen.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final asset = orientation == Orientation.portrait
              ? AppAssets.loadingVertical
              : AppAssets.loadingHorizontal;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    32,
                    28,
                    32,
                    orientation == Orientation.portrait ? 56 : 28,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GoldProgressBar(progress: _progress),
                        const SizedBox(height: 14),
                        LoadingDotsText(
                          style: jesterTextStyle(size: 20, color: AppColors.goldLight),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
