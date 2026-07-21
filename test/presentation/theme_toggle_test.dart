import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/providers.dart';
import 'package:jct_mixexam/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          examRepositoryProvider.overrideWithValue(InMemoryExamRepository()),
          imagesRootDirProvider.overrideWithValue('/tmp/images'),
        ],
        child: const MixExamApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  ThemeMode currentMode(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode ??
      ThemeMode.system;

  testWidgets('toggle flips to dark, persists, and flips back',
      (tester) async {
    await pumpApp(tester);
    expect(currentMode(tester), ThemeMode.system);

    // Test platform brightness is light -> first toggle goes dark.
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    expect(currentMode(tester), ThemeMode.dark);

    // Persisted for the next launch.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');

    // In dark mode the icon switches and toggles back to light.
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();
    expect(currentMode(tester), ThemeMode.light);
    expect(prefs.getString('theme_mode'), 'light');
  });

  testWidgets('stored preference is restored on startup', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    await pumpApp(tester);
    expect(currentMode(tester), ThemeMode.dark);
  });
}
