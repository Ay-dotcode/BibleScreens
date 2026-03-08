// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

extension ColorCompat on Color {
  Color withValues({
    double? alpha,
    double? red,
    double? green,
    double? blue,
  }) {
    final nextAlpha = ((alpha ?? opacity).clamp(0.0, 1.0) * 255).round();
    final nextRed = ((red ?? (this.red / 255)).clamp(0.0, 1.0) * 255).round();
    final nextGreen =
        ((green ?? (this.green / 255)).clamp(0.0, 1.0) * 255).round();
    final nextBlue =
        ((blue ?? (this.blue / 255)).clamp(0.0, 1.0) * 255).round();

    return Color.fromARGB(nextAlpha, nextRed, nextGreen, nextBlue);
  }

  int toARGB32() => value;
}
