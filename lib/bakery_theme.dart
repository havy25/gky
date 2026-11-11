import 'package:flutter/material.dart';

// Bảng màu tiệm bánh: kem - nâu - caramel
const Color kCream = Color(0xFFFFF8F0);
const Color kBrown = Color(0xFF6D4C41);
const Color kDarkBrown = Color(0xFF8D5524);
const Color kCaramel = Color(0xFFD98324);
const Color kHoney = Color(0xFFF2B05E);
const Color kGreen = Color(0xFF3E9B5F);
const Color kRed = Color(0xFFD64545);
const Color kOrange = Color(0xFFE0902B);

ThemeData bakeryTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kCaramel,
    brightness: Brightness.light,
  ).copyWith(primary: kDarkBrown);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kCream,
  );
}
