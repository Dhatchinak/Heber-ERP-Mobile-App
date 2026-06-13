import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffDarkColors {
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
}

class StaffLightColors {
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

class StaffThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  static const String _prefKey = 'staff_erp_theme_dark';

  StaffThemeProvider() {
    _loadTheme();
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_prefKey) ?? false;
    
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _isDarkMode);
  }

  Future<void> setDark(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  // ── Core tokens ────────────────────────────────────────────────────────────
  Color get bg => _isDarkMode ? StaffDarkColors.bg : StaffLightColors.bg;
  Color get surface =>
      _isDarkMode ? StaffDarkColors.surface : StaffLightColors.surface;
  Color get elevated =>
      _isDarkMode ? StaffDarkColors.elevated : StaffLightColors.elevated;
  Color get elevated2 =>
      _isDarkMode ? StaffDarkColors.elevated2 : StaffLightColors.elevated2;
  Color get border =>
      _isDarkMode ? StaffDarkColors.border : StaffLightColors.border;
  Color get borderBright => _isDarkMode
      ? StaffDarkColors.borderBright
      : StaffLightColors.borderBright;
  Color get cyan => _isDarkMode ? StaffDarkColors.cyan : StaffLightColors.cyan;
  Color get cyanDim =>
      _isDarkMode ? StaffDarkColors.cyanDim : StaffLightColors.cyanDim;
  Color get violet =>
      _isDarkMode ? StaffDarkColors.violet : StaffLightColors.violet;
  Color get violetBright => _isDarkMode
      ? StaffDarkColors.violetBright
      : StaffLightColors.violetBright;
  Color get pink => _isDarkMode ? StaffDarkColors.pink : StaffLightColors.pink;
  Color get pinkDim =>
      _isDarkMode ? StaffDarkColors.pinkDim : StaffLightColors.pinkDim;
  Color get green =>
      _isDarkMode ? StaffDarkColors.green : StaffLightColors.green;
  Color get greenDim =>
      _isDarkMode ? StaffDarkColors.greenDim : StaffLightColors.greenDim;
  Color get amber =>
      _isDarkMode ? StaffDarkColors.amber : StaffLightColors.amber;
  Color get textHigh =>
      _isDarkMode ? StaffDarkColors.textHigh : StaffLightColors.textHigh;
  Color get textMid =>
      _isDarkMode ? StaffDarkColors.textMid : StaffLightColors.textMid;
  Color get textLow =>
      _isDarkMode ? StaffDarkColors.textLow : StaffLightColors.textLow;

  // ── Gradients ──────────────────────────────────────────────────────────────
  List<Color> get primaryGradient => _isDarkMode
      ? [StaffDarkColors.cyan, StaffDarkColors.violet]
      : [StaffLightColors.cyan, StaffLightColors.violet];

  List<Color> get bgGradient => _isDarkMode
      ? [const Color(0xFF05060F), const Color(0xFF0B0D1C)]
      : [
          const Color(0xFFF5F6FF),
          const Color(0xFFFAF5FF),
          const Color(0xFFECEEFF)
        ];

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

  List<Color> get hodGradient => _isDarkMode
      ? [
          const Color(0xFF1A0F00),
          const Color(0xFF2A1800),
          const Color(0xFF3A2200)
        ]
      : [
          const Color(0xFFFFF3E0),
          const Color(0xFFFFE0B2),
          const Color(0xFFFFCC80)
        ];

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

  // ── Semantic ───────────────────────────────────────────────────────────────
  Color get error => _isDarkMode ? StaffDarkColors.pink : StaffLightColors.pink;
  Color get success =>
      _isDarkMode ? StaffDarkColors.green : StaffLightColors.green;
  Color get warning =>
      _isDarkMode ? StaffDarkColors.amber : StaffLightColors.amber;
  Color get info => _isDarkMode ? StaffDarkColors.cyan : StaffLightColors.cyan;

  // ── ThemeData ──────────────────────────────────────────────────────────────
  ThemeData get themeData => _isDarkMode ? _buildDark() : _buildLight();

  ThemeData _buildDark() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: StaffDarkColors.bg,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: StaffDarkColors.cyan,
          secondary: StaffDarkColors.violet,
          surface: StaffDarkColors.surface,
          error: StaffDarkColors.pink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: StaffDarkColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: StaffDarkColors.textHigh),
        ),
        cardTheme: CardThemeData(
          color: StaffDarkColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: StaffDarkColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: StaffDarkColors.elevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: StaffDarkColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: StaffDarkColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: StaffDarkColors.cyan, width: 1.5),
          ),
          hintStyle: const TextStyle(color: StaffDarkColors.textLow),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: StaffDarkColors.cyan,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? StaffDarkColors.cyan
                  : StaffDarkColors.textMid),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? StaffDarkColors.cyan.withOpacity(0.3)
                  : StaffDarkColors.border),
        ),
        dividerColor: StaffDarkColors.border,
        dialogBackgroundColor: StaffDarkColors.surface,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: StaffDarkColors.surface,
        ),
      );

  ThemeData _buildLight() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: StaffLightColors.bg,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: StaffLightColors.cyan,
          secondary: StaffLightColors.violet,
          surface: StaffLightColors.surface,
          error: StaffLightColors.pink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: StaffLightColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: StaffLightColors.textHigh),
        ),
        cardTheme: CardThemeData(
          color: StaffLightColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: StaffLightColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: StaffLightColors.elevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: StaffLightColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: StaffLightColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: StaffLightColors.cyan, width: 1.5),
          ),
          hintStyle: const TextStyle(color: StaffLightColors.textLow),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: StaffLightColors.cyan,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? StaffLightColors.cyan
                  : StaffLightColors.textMid),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? StaffLightColors.cyan.withOpacity(0.3)
                  : StaffLightColors.border),
        ),
        dividerColor: StaffLightColors.border,
        dialogBackgroundColor: StaffLightColors.surface,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: StaffLightColors.surface,
        ),
      );
}

extension StaffThemeContext on BuildContext {
  StaffThemeProvider get staffTheme =>
      Provider.of<StaffThemeProvider>(this, listen: false);
  StaffThemeProvider get staffThemeWatch =>
      Provider.of<StaffThemeProvider>(this);
}
