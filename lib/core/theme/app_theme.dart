import 'package:flutter/material.dart';

// Color palette extracted from the reference design
const kNavy = Color(0xFF152037); // Header, primary button, heading text
const kAmber = Color(0xFFF0A500); // Selected role / accent
const kBg = Color(0xFFF0EBE1); // Warm cream background
const kSurface = Color(0xFFFFFFFF); // Input fields, white areas
const kTextMain = Color(0xFF152037); // Primary text
const kTextSub = Color(0xFF8A8A8A); // Subtitle / hint text
const kBorder = Color(0xFFE0D9CF); // Input border
const kDanger = Color(0xFFB04A38); // Cancel / destructive buttons and warnings
const kDangerSurface = Color(0xFFF4DAD6); // Warning banner background

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: kBg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kNavy,
    brightness: Brightness.light,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _border(),
    enabledBorder: _border(),
    focusedBorder: _border(color: kNavy, width: 2),
    errorBorder: _border(color: Colors.redAccent),
    focusedErrorBorder: _border(color: Colors.redAccent, width: 2),
    hintStyle: const TextStyle(color: kTextSub, fontSize: 15),
    errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
  ),
);

OutlineInputBorder _border({Color color = kBorder, double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
