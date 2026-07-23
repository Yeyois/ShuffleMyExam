import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'application/providers.dart';
import 'application/theme_mode_controller.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'data/local/hive_exam_repository.dart';
import 'data/local/hive_shuffled_pdf_repository.dart';
import 'presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final repository = await HiveExamRepository.open();
  final shuffledPdfRepository = await HiveShuffledPdfRepository.open();
  final documentsDir = await getApplicationDocumentsDirectory();

  runApp(
    ProviderScope(
      overrides: [
        examRepositoryProvider.overrideWithValue(repository),
        shuffledPdfRepositoryProvider.overrideWithValue(shuffledPdfRepository),
        imagesRootDirProvider
            .overrideWithValue('${documentsDir.path}/exam_images'),
        shuffledLibraryDirProvider
            .overrideWithValue('${documentsDir.path}/shuffled_pdfs'),
      ],
      child: const MixExamApp(),
    ),
  );
}

class MixExamApp extends ConsumerWidget {
  const MixExamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Global RTL: the whole app is Hebrew-first.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
