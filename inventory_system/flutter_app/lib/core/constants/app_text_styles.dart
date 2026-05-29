import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const _fontFamily = 'Inter';

  static const displayLarge = TextStyle(
    fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.w800,
    color: Color(0xFFF8FAFC), height: 1.2,
  );
  static const displayMedium = TextStyle(
    fontFamily: _fontFamily, fontSize: 24, fontWeight: FontWeight.w700,
    color: Color(0xFFF1F5F9), height: 1.2,
  );
  static const headingLarge = TextStyle(
    fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600,
    color: Color(0xFFF1F5F9), height: 1.2,
  );
  static const headingMedium = TextStyle(
    fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600,
    color: Color(0xFFE2E8F0), height: 1.2,
  );
  static const headingSmall = TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600,
    color: Color(0xFFCBD5E1), height: 1.2,
  );
  static const bodyLarge = TextStyle(
    fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w400,
    color: Color(0xFFE2E8F0), height: 1.5,
  );
  static const bodyMedium = TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400,
    color: Color(0xFFCBD5E1), height: 1.5,
  );
  static const bodySmall = TextStyle(
    fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400,
    color: Color(0xFF94A3B8), height: 1.5,
  );
  static const labelLarge = TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500,
    color: Color(0xFFE2E8F0), height: 1.2,
  );
  static const labelMedium = TextStyle(
    fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500,
    color: Color(0xFFCBD5E1), height: 1.2,
  );
  static const labelSmall = TextStyle(
    fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w500,
    color: Color(0xFF94A3B8), height: 1.2, letterSpacing: 0.5,
  );
}
