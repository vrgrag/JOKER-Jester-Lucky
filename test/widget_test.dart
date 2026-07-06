// Basic smoke test making sure the app boots into the splash screen
// without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jesterlucky/app.dart';

void main() {
  testWidgets('App boots and shows the loading screen', (tester) async {
    await tester.pumpWidget(const JesterLuckyApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
  });
}
