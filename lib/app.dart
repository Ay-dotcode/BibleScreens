import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class ChurchDisplayApp extends StatelessWidget {
  const ChurchDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Display',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6B4EFF),
          secondary: Color(0xFF03DAC5),
          surface: Color(0xFF1A1A2E),
        ),
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.onDrag,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
