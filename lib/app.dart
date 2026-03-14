import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/output_display_screen.dart';

class BibleScreensApp extends StatelessWidget {
  const BibleScreensApp({
    super.key,
    this.forceDisplayMode = false,
  });

  final bool forceDisplayMode;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final isWebDisplayWindow = kIsWeb &&
        (uri.queryParameters['display'] == '1' ||
            uri.path.endsWith('/display') ||
            uri.fragment.contains('display=1') ||
            uri.fragment.endsWith('/display'));
    final isDisplayWindow = forceDisplayMode || isWebDisplayWindow;

    return MaterialApp(
      title: 'Bible Screens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: isDisplayWindow ? const OutputDisplayScreen() : const HomeScreen(),
    );
  }
}
