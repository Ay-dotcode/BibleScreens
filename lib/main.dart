import 'package:flutter/material.dart';

import 'app.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final forceDisplayMode =
      args.contains('--display-window') || args.contains('--display');
  runApp(ChurchDisplayApp(forceDisplayMode: forceDisplayMode));
}

