import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color backgroundPrimary = Color(0xFFF9FAFB);
  static const Color backgroundSecondary = Color(0xFFF3F4F6);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // Borders
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFFD1D5DB);

  // Primary Gradient Colors
  static const Color primaryTeal = Color(0xFF00C9A7);
  static const Color primaryCyan = Color(0xFF00E5FF);

  // Secondary
  static const Color secondaryBlueDark = Color(0xFF2563EB);
  static const Color secondaryBlueLight = Color(0xFF3B82F6);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textQuaternary = Color(0xFFD1D5DB);

  // States
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  // Specialized App Colors
  static const Color chatbotBg = Color(0xFFE6FFFA);
  static const Color securityBg = Color(0xFFEFF6FF);
  
  static const Color gradCamRed = Color(0xFFFF4D4D);
  static const Color gradCamOrange = Color(0xFFFF8A00);
  static const Color gradCamYellow = Color(0xFFFFD600);

  // UI Shadows & Overlays
  static const Color shadowLow = Color(0x0D000000); // rgba(0, 0, 0, 0.05)
  static const Color shadowMedium = Color(0x14000000); // rgba(0, 0, 0, 0.08)
  static const Color overlayLight = Color(0xB3FFFFFF); // rgba(255, 255, 255, 0.7)

  // Custom Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryTeal, primaryCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
