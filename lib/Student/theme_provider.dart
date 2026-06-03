import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DarkColors {
  static const bg = Color(0xFF05060F);
  static const surface = Color(0xFF0B0D1C);
  static const elevated = Color(0xFF111428);
  static const elevated2 = Color(0xFF16193A);
  static const border = Color(0xFF101535);
  static const borderBright = Color(0xFF1C2248);
  static const cyan = Color(0xFF7B8CFF);
  static const cyanDim = Color(0xFF5A6AE8);
  static const violet = Color(0xFFB06EFF);
  static const violetBright = Color(0xFFCF96FF);
  static const green = Color(0xFF00E5A0);
  static const greenDim = Color(0xFF00B87C);
  static const amber = Color(0xFFFFB340);
  static const pink = Color(0xFFFF5FA0);
  static const pinkDim = Color(0xFFE0407A);
  static const textHigh = Color(0xFFEDF0FF);
  static const textMid = Color(0xFF7B8DB8);
  static const textLow = Color(0xFF2E3A5E);
  Color get orange => const Color(0xFFF97316); // Orange color
}

// ─── LIGHT: Crystal Aurora Premium ───────────────────────────────────────────
// BG:       #F5F6FF  (indigo-tinted pearl white)
// Surface:  #FFFFFF  (pure white cards)
// Elevated: #ECEEFF  (soft indigo fill)
// Elevated2:#DEE1FF  (deeper indigo fill)
// Border:   rgba(75,88,232,0.12) → #E3E4FB approx
// Cyan:     #4B58E8  (electric indigo — premium primary)
// Violet:   #7C3AED  (deep violet accent)
// Green:    #00A86B  (emerald success)
// Amber:    #D97706  (warm amber)
// Pink:     #E02060  (crimson danger)
// TextHigh: #12153A  (deep indigo-black — premium dark)
// TextMid:  #4A526A  (cool slate)
// TextLow:  #9CA3AF  (muted gray)
class LightColors {
  static const bg = Color(0xFFF5F6FF);
  static const surface = Color(0xFFFFFFFF);
  static const elevated = Color(0xFFECEEFF);
  static const elevated2 = Color(0xFFDEE1FF);
  static const border = Color(0xFFE3E4FB);
  static const borderBright = Color(0xFFC7C9F5);
  static const cyan = Color(0xFF4B58E8);
  static const cyanDim = Color(0xFF3340C0);
  static const violet = Color(0xFF7C3AED);
  static const violetBright = Color(0xFF9B5FF5);
  static const green = Color(0xFF00A86B);
  static const greenDim = Color(0xFF007A4E);
  static const amber = Color(0xFFD97706);
  static const pink = Color(0xFFE02060);
  static const pinkDim = Color(0xFFB01540);
  static const textHigh = Color(0xFF12153A);
  static const textMid = Color(0xFF4A526A);
  static const textLow = Color(0xFF9CA3AF);
}

class ThemeProvider extends ChangeNotifier {
  static const _key = 'student_theme_dark';
  bool _isDarkMode = true;

  ThemeProvider() {
    _load();
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDarkMode);
  }


  // ── Core tokens ─────────────────────────────────────────────────────────────
  Color get bg => _isDarkMode ? DarkColors.bg : LightColors.bg;
  Color get surface => _isDarkMode ? DarkColors.surface : LightColors.surface;
  Color get elevated =>
      _isDarkMode ? DarkColors.elevated : LightColors.elevated;
  Color get elevated2 =>
      _isDarkMode ? DarkColors.elevated2 : LightColors.elevated2;
  Color get border => _isDarkMode ? DarkColors.border : LightColors.border;
  Color get borderBright =>
      _isDarkMode ? DarkColors.borderBright : LightColors.borderBright;
  Color get cyan => _isDarkMode ? DarkColors.cyan : LightColors.cyan;
  Color get cyanDim => _isDarkMode ? DarkColors.cyanDim : LightColors.cyanDim;
  Color get violet => _isDarkMode ? DarkColors.violet : LightColors.violet;
  Color get violetBright =>
      _isDarkMode ? DarkColors.violetBright : LightColors.violetBright;
  Color get pink => _isDarkMode ? DarkColors.pink : LightColors.pink;
  Color get pinkDim => _isDarkMode ? DarkColors.pinkDim : LightColors.pinkDim;
  Color get green => _isDarkMode ? DarkColors.green : LightColors.green;
  Color get greenDim =>
      _isDarkMode ? DarkColors.greenDim : LightColors.greenDim;
  Color get amber => _isDarkMode ? DarkColors.amber : LightColors.amber;
  Color get textHigh =>
      _isDarkMode ? DarkColors.textHigh : LightColors.textHigh;
  Color get textMid => _isDarkMode ? DarkColors.textMid : LightColors.textMid;
  Color get textLow => _isDarkMode ? DarkColors.textLow : LightColors.textLow;
  Color get orange => const Color(0xFFF97316); // Orange color

  // ── Gradients ────────────────────────────────────────────────────────────────
  List<Color> get primaryGradient => _isDarkMode
      ? [DarkColors.cyan, DarkColors.violet]
      : [LightColors.cyan, LightColors.violet];

  List<Color> get bgGradient => _isDarkMode
      ? [const Color(0xFF05060F), const Color(0xFF0B0D1C)]
      : [
          const Color(0xFFF5F6FF),
          const Color(0xFFFAF5FF),
          const Color(0xFFECEEFF)
        ];

  /// Hero / banner card gradient
  List<Color> get bannerGradient => _isDarkMode
      ? [
          const Color(0xFF0B0E23),
          const Color(0xFF0F1230),
          const Color(0xFF130D25)
        ]
      : [
          const Color(0xFFEFF1FF),
          const Color(0xFFE8ECFF),
          const Color(0xFFEEE8FF)
        ];

  /// Accent shimmer (used on progress fills, neon highlights)
  List<Color> get accentGradient => _isDarkMode
      ? [DarkColors.cyan, DarkColors.violet, DarkColors.pink]
      : [LightColors.cyan, LightColors.violet, LightColors.green];

  /// Stat card individual gradients
  List<Color> get statCardCyan => _isDarkMode
      ? [const Color(0xFF0D1230), const Color(0xFF111840)]
      : [const Color(0xFFEEF0FF), const Color(0xFFE6E9FF)];

  List<Color> get statCardGreen => _isDarkMode
      ? [const Color(0xFF06120E), const Color(0xFF0A1A14)]
      : [const Color(0xFFEBFDF5), const Color(0xFFD8F9EC)];

  List<Color> get statCardViolet => _isDarkMode
      ? [const Color(0xFF0F0820), const Color(0xFF150D2E)]
      : [const Color(0xFFF3EEFF), const Color(0xFFEAE2FF)];

  List<Color> get statCardAmber => _isDarkMode
      ? [const Color(0xFF150F02), const Color(0xFF201504)]
      : [const Color(0xFFFFF8EC), const Color(0xFFFFF1D6)];

  // ── Semantic colors ───────────────────────────────────────────────────────────
  Color get error => _isDarkMode ? DarkColors.pink : LightColors.pink;
  Color get success => _isDarkMode ? DarkColors.green : LightColors.green;
  Color get warning => _isDarkMode ? DarkColors.amber : LightColors.amber;
  Color get info => _isDarkMode ? DarkColors.cyan : LightColors.cyan;

  // ── Opacity helpers ───────────────────────────────────────────────────────────
  /// Tinted surface overlay — use for chip/badge backgrounds
  Color accentSurface(Color accent, [double opacity = 0.08]) =>
      accent.withOpacity(opacity);

  /// Tinted border — use for chip/card borders
  Color accentBorder(Color accent, [double opacity = 0.25]) =>
      accent.withOpacity(opacity);

  // ── MaterialApp ThemeData ─────────────────────────────────────────────────────
  ThemeData get themeData => _isDarkMode ? _darkTheme : _lightTheme;

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DarkColors.bg,
    fontFamily: 'Inter',
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: DarkColors.cyan,
      secondary: DarkColors.violet,
      background: DarkColors.bg,
      surface: DarkColors.surface,
      error: DarkColors.pink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DarkColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: DarkColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: DarkColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DarkColors.elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DarkColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DarkColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DarkColors.cyan, width: 1.5),
      ),
    ),
    dividerColor: DarkColors.border,
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? DarkColors.cyan
              : DarkColors.textMid),
      trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? DarkColors.cyan.withOpacity(0.3)
              : DarkColors.border),
    ),
  );

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: LightColors.bg,
    fontFamily: 'Inter',
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: LightColors.cyan,
      secondary: LightColors.violet,
      background: LightColors.bg,
      surface: LightColors.surface,
      error: LightColors.pink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: LightColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: LightColors.textHigh,
    ),
    cardTheme: CardThemeData(
      color: LightColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: LightColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LightColors.elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LightColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LightColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LightColors.cyan, width: 1.5),
      ),
    ),
    dividerColor: LightColors.border,
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? LightColors.cyan
              : LightColors.textMid),
      trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? LightColors.cyan.withOpacity(0.25)
              : LightColors.border),
    ),
  );
}
