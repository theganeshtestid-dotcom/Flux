import 'package:flutter/material.dart';

const orange = Color(0xFFF87115);
ThemeData fluxTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = Color(dark ? 0xFF0F1014 : 0xFFF4F3EE);
  final surface = Color(dark ? 0xFF191C23 : 0xFFFFFFFF);
  final ink = Color(dark ? 0xFFF0F0F3 : 0xFF192138);
  final muted = Color(dark ? 0xFFBFC4D2 : 0xFF525A70);
  final border = Color(dark ? 0xFF2B303A : 0xFFE5E1D8);
  final colors = ColorScheme.fromSeed(seedColor: orange, brightness: brightness).copyWith(primary: orange, onPrimary: const Color(0xFF101114), surface: surface, onSurface: ink, onSurfaceVariant: muted, outlineVariant: border, secondary: orange, tertiary: const Color(0xFF0DC058), surfaceTint: Colors.transparent, secondaryContainer: Color(dark ? 0xFF513018 : 0xFFFFDAB9), onSecondaryContainer: ink);
  return ThemeData(useMaterial3: true, brightness: brightness, colorScheme: colors, scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(backgroundColor: bg, foregroundColor: ink, surfaceTintColor: Colors.transparent),
    cardTheme: CardThemeData(color: surface, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: border))),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(bodyColor: ink, displayColor: ink),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border))),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: surface, indicatorColor: colors.secondaryContainer),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: orange, foregroundColor: Color(0xFF101114)),
    chipTheme: ChipThemeData(backgroundColor: colors.secondaryContainer, side: BorderSide.none),
  );
}
