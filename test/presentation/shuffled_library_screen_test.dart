import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/providers.dart';
import 'package:jct_mixexam/core/constants/app_strings.dart';
import 'package:jct_mixexam/domain/models/shuffled_pdf.dart';
import 'package:jct_mixexam/presentation/screens/shuffled_library_screen.dart';

import '../test_helpers.dart';

ShuffledPdf sample(String id, {DateTime? createdAt}) => ShuffledPdf(
      id: id,
      examTitle: 'מבחן $id',
      filePath: '/tmp/$id.pdf',
      sizeBytes: 2048,
      createdAt: createdAt ?? DateTime(2026, 7, 23, 10),
    );

void main() {
  testWidgets('shows empty state when the library is empty', (tester) async {
    await pumpScreen(
      tester,
      home: const ShuffledLibraryScreen(),
      overrides: [
        shuffledPdfRepositoryProvider
            .overrideWithValue(InMemoryShuffledPdfRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.emptyLibrary), findsOneWidget);
  });

  testWidgets('lists saved shuffles newest first', (tester) async {
    final repo = InMemoryShuffledPdfRepository();
    await repo.save(sample('old', createdAt: DateTime(2026, 1, 1)));
    await repo.save(sample('new', createdAt: DateTime(2026, 7, 1)));

    await pumpScreen(
      tester,
      home: const ShuffledLibraryScreen(),
      overrides: [shuffledPdfRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    expect(find.text('מבחן new'), findsOneWidget);
    expect(find.text('מבחן old'), findsOneWidget);

    final newPos = tester.getTopLeft(find.text('מבחן new')).dy;
    final oldPos = tester.getTopLeft(find.text('מבחן old')).dy;
    expect(newPos, lessThan(oldPos));
  });

  testWidgets('delete flow removes a file after confirmation', (tester) async {
    final repo = InMemoryShuffledPdfRepository();
    await repo.save(sample('s1'));

    await pumpScreen(
      tester,
      home: const ShuffledLibraryScreen(),
      overrides: [shuffledPdfRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.deleteFileConfirm), findsOneWidget);

    await tester.tap(find.text(AppStrings.delete));
    await tester.pumpAndSettle();

    expect(find.text('מבחן s1'), findsNothing);
    expect(find.text(AppStrings.emptyLibrary), findsOneWidget);
    expect(await repo.getShuffledPdfs(), isEmpty);
  });
}
