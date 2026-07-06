import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/game/game_screen.dart';
import 'screens/menu/main_menu_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/webview/web_view_screen.dart';

class JesterLuckyApp extends StatelessWidget {
  const JesterLuckyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jester Lucky',
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
      initialRoute: SplashScreen.route,
      routes: {
        SplashScreen.route: (_) => const SplashScreen(),
        MainMenuScreen.route: (_) => const MainMenuScreen(),
        GameScreen.route: (_) => const GameScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == WebViewScreen.route) {
          final args = settings.arguments as WebViewScreenArgs;
          return MaterialPageRoute(
            builder: (_) => WebViewScreen(args: args),
          );
        }
        return null;
      },
    );
  }
}
