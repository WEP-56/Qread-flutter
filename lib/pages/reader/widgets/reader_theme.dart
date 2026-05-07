import 'package:flutter/material.dart';

/// 阅读器主题配置
class ReaderTheme {
  final String name;
  final Color background;
  final Color text;
  final Color secondaryText;
  final Color divider;
  final Color highlight;

  const ReaderTheme({
    required this.name,
    required this.background,
    required this.text,
    required this.secondaryText,
    required this.divider,
    required this.highlight,
  });

  static const light = ReaderTheme(
    name: 'light',
    background: Color(0xFFF7F1E6),
    text: Color(0xFF2D2D2D),
    secondaryText: Color(0xFF8A8175),
    divider: Color(0xFFE1D7C8),
    highlight: Color(0x3300A88F),
  );

  static const dark = ReaderTheme(
    name: 'dark',
    background: Color(0xFF101417),
    text: Color(0xFFE4E7EB),
    secondaryText: Color(0xFF8C98A5),
    divider: Color(0xFF23303A),
    highlight: Color(0x3300A88F),
  );

  static const sepia = ReaderTheme(
    name: 'sepia',
    background: Color(0xFFF4E7CF),
    text: Color(0xFF5B4636),
    secondaryText: Color(0xFF8B6F58),
    divider: Color(0xFFDCC9A8),
    highlight: Color(0x3300A88F),
  );

  static ReaderTheme byName(String name) {
    switch (name) {
      case 'dark':
        return dark;
      case 'sepia':
        return sepia;
      default:
        return light;
    }
  }

  static String nextTheme(String current) {
    switch (current) {
      case 'light':
        return 'dark';
      case 'dark':
        return 'sepia';
      case 'sepia':
        return 'light';
      default:
        return 'light';
    }
  }
}
