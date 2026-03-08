import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';

class ChurchDisplayApp extends StatelessWidget {
  const ChurchDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Display',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
