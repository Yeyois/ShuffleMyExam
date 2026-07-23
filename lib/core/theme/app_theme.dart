import 'package:flutter/material.dart';

import 'motion.dart';

/// Material 3 light/dark themes for the app.
abstract final class AppTheme {
  static const _seed = Color(0xFF00639B);

  static ThemeData get light => _base(Brightness.light);

  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    const transitions = PageTransitionsTheme(builders: {
      TargetPlatform.android: _PlayfulPageTransitionsBuilder(),
      TargetPlatform.iOS: _PlayfulPageTransitionsBuilder(),
      TargetPlatform.linux: _PlayfulPageTransitionsBuilder(),
      TargetPlatform.macOS: _PlayfulPageTransitionsBuilder(),
      TargetPlatform.windows: _PlayfulPageTransitionsBuilder(),
    });
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      pageTransitionsTheme: transitions,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: const CardThemeData(
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// A springy fade-through + scale-up page transition, applied to every route.
class _PlayfulPageTransitionsBuilder extends PageTransitionsBuilder {
  const _PlayfulPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Motion.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
