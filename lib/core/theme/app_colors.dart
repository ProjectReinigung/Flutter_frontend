import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.cleanBlue,
    required this.mint,
  });

  final Color success;
  final Color warning;
  final Color info;
  final Color cleanBlue;
  final Color mint;

  static const light = AppColors(
    success: Color(0xFF16856B),
    warning: Color(0xFFB7791F),
    info: Color(0xFF2563EB),
    cleanBlue: Color(0xFF0E7490),
    mint: Color(0xFF14B8A6),
  );

  static const dark = AppColors(
    success: Color(0xFF5EEAD4),
    warning: Color(0xFFFACC15),
    info: Color(0xFF93C5FD),
    cleanBlue: Color(0xFF67E8F9),
    mint: Color(0xFF2DD4BF),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? cleanBlue,
    Color? mint,
  }) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      cleanBlue: cleanBlue ?? this.cleanBlue,
      mint: mint ?? this.mint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      cleanBlue: Color.lerp(cleanBlue, other.cleanBlue, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
    );
  }
}
