import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/providers.dart';
import 'package:jct_mixexam/core/constants/app_strings.dart';
import 'package:jct_mixexam/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app boots to the home screen with global RTL', (tester) async {
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

    expect(find.text(AppStrings.homeTitle), findsOneWidget);

    final context = tester.element(find.text(AppStrings.homeTitle));
    expect(Directionality.of(context), TextDirection.rtl);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(materialApp.darkTheme, isNotNull);
  });
}
