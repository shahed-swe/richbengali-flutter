// Smoke test: the app boots to the splash route while the stored session is
// still hydrating, without throwing.
//
// The previous version asserted on a 'Welcome to RichBengali' string from a
// screen that no longer exists, so it had been failing for some time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:richbengali/app.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RichBengaliApp(),
      ),
    );

    // The router holds on /splash until auth hydration completes, so a cold
    // start never flashes /login.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
