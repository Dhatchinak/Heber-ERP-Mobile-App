import 'package:bhc_erp/Student/screens/main_page.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

// ─────────────────────────────────────────────────────────────────
// AESTHETIC LIGHT THEME — Bishop Heber College Student Login Screen
// Palette: Soft lavender + violet + teal accents on white/pearl base
// ─────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController rollNoController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool _obscureDob = true;

  late AnimationController _bgController;
  late AnimationController _cardController;
  late AnimationController _shimmerController;

  late Animation<double> _cardOffset;
  late Animation<double> _cardOpacity;
  late Animation<double> _shimmerPos;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _cardOffset = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );
    _cardOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOut));
    _shimmerPos = Tween<double>(begin: -2, end: 3).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _cardController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> loginStudent() async {
    if (!_formKey.currentState!.validate()) return;
    String rollNo = rollNoController.text.trim();
    String dob = dobController.text.trim();
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse("https://apierp.bhc.edu.in/api/students/$rollNo"),
        headers: {"Referer": "http://117.232.64.75"},
      );
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data["data"] != null && data["data"]["personal_info"] != null) {
          String serverDob = data["data"]["personal_info"]["dob"] ?? "";
          String studentName = data["data"]["name"] ?? "Student";
          if (serverDob.isEmpty) {
            _showErrorDialog("DOB not available for this roll number");
            return;
          }
          String extractedDate = serverDob.contains("T")
              ? serverDob.split("T")[0]
              : serverDob;
          List<String> parts = dob.split("/");
          if (parts.length == 3) {
            String formattedDob =
                "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
            if (extractedDate == formattedDob) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('rollNo', rollNo);
              await prefs.setString('studentName', studentName);
              await prefs.setString('dob', formattedDob);
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) =>
                        MainPage(rollNo: rollNo, studentName: studentName),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 600),
                  ),
                );
              }
            } else {
              _showErrorDialog("Date of Birth doesn't match our records");
            }
          } else {
            _showErrorDialog("Invalid DOB format. Please use dd/mm/yyyy");
          }
        } else {
          _showErrorDialog("Student data not found for this roll number");
        }
      } else {
        _showErrorDialog("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorDialog("Connection error. Please check your internet.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Provider.of<ThemeProvider>(context, listen: false).error,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Login Failed",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Provider.of<ThemeProvider>(context, listen: false).textHigh,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Provider.of<ThemeProvider>(context, listen: false).textMid,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Provider.of<ThemeProvider>(context, listen: false).violet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Try Again",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: currentTheme.bg,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: currentTheme.bgGradient,
              ),
            ),
            child: Stack(
              children: [
                // Decorative blobs
                _Orb(
                  top: -70,
                  left: -70,
                  size: 220,
                  color: currentTheme.violet.withValues(alpha: currentTheme.isDarkMode ? 0.05 : 0.10),
                  anim: _bgController,
                ),
                _Orb(
                  bottom: -100,
                  right: -80,
                  size: 260,
                  color: currentTheme.pink.withValues(alpha: currentTheme.isDarkMode ? 0.04 : 0.09),
                  anim: _bgController,
                  flip: true,
                ),
                _Orb(
                  top: 220,
                  right: -50,
                  size: 130,
                  color: currentTheme.cyan.withValues(alpha: currentTheme.isDarkMode ? 0.05 : 0.08),
                  anim: _bgController,
                ),
                _Orb(
                  bottom: 220,
                  left: -40,
                  size: 110,
                  color: currentTheme.green.withValues(alpha: currentTheme.isDarkMode ? 0.04 : 0.07),
                  anim: _bgController,
                  flip: true,
                ),
                // Top accent line
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: currentTheme.accentGradient,
                      ),
                    ),
                  ),
                ),
                // Main scroll
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: AnimatedBuilder(
                        animation: _cardController,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, _cardOffset.value),
                          child: Opacity(
                            opacity: _cardOpacity.value,
                            child: child,
                          ),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 32),
                              _buildCard(),
                              const SizedBox(height: 28),
                              _buildFooter(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final currentTheme = Provider.of<ThemeProvider>(context);
    return Column(
      children: [
        // Logo with layered glow rings
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) => Container(
                width: 110 + _bgController.value * 4,
                height: 110 + _bgController.value * 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentTheme.violet.withValues(alpha: 0.04 + _bgController.value * 0.02),
                ),
              ),
            ),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: currentTheme.violet.withValues(alpha: 0.22),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/bhclogo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school_rounded,
                    size: 44,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Bishop Heber College',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: currentTheme.textHigh,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: currentTheme.primaryGradient,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: currentTheme.violet.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            'STUDENT PORTAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    final currentTheme = Provider.of<ThemeProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: currentTheme.isDarkMode ? currentTheme.surface : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: currentTheme.isDarkMode ? currentTheme.border : Colors.white.withValues(alpha: 0.95), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: currentTheme.violet.withValues(alpha: 0.07),
            blurRadius: 50,
            spreadRadius: 0,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: currentTheme.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: currentTheme.textHigh,
                        ),
                      ),
                      Text(
                        'Sign in to continue',
                        style: TextStyle(
                          fontSize: 12,
                          color: currentTheme.textLow,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Divider(color: currentTheme.border),
              const SizedBox(height: 24),

              // Roll No
              _FancyField(
                controller: rollNoController,
                label: 'Roll Number',
                hint: 'e.g. 22MCS001',
                icon: Icons.badge_outlined,
                accentColor: currentTheme.violet,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter roll number';
                  if (v.length < 3) return 'Roll number too short';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // DOB
              _FancyField(
                controller: dobController,
                label: 'Date of Birth',
                hint: 'Tap to pick date',
                icon: Icons.cake_outlined,
                accentColor: currentTheme.pink,
                isReadOnly: true,
                obscureText: _obscureDob,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureDob
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: currentTheme.textLow,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureDob = !_obscureDob),
                ),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: ColorScheme.light(
                          primary: currentTheme.violet,
                          onPrimary: Colors.white,
                          surface: currentTheme.surface,
                          onSurface: currentTheme.textHigh,
                        ),
                        dialogTheme: DialogThemeData(
                          backgroundColor: currentTheme.surface,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    dobController.text =
                        "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                  }
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please select DOB';
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Sign in button
              _SignInButton(
                isLoading: isLoading,
                shimmer: _shimmerPos,
                onPressed: loginStudent,
              ),
              const SizedBox(height: 18),

              // Info text
              Center(
                child: Text(
                  "Contact admin if you face login issues",
                  style: TextStyle(fontSize: 12, color: currentTheme.textLow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final currentTheme = Provider.of<ThemeProvider>(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ColorDot(currentTheme.violet),
            const SizedBox(width: 8),
            _ColorDot(currentTheme.pink),
            const SizedBox(width: 8),
            _ColorDot(currentTheme.cyan),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "© 2025 Bishop Heber College",
          style: TextStyle(
            fontSize: 11,
            color: currentTheme.textLow,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Fancy Input Field ────────────────────────────────────────────────────────

class _FancyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final bool isReadOnly;
  final bool obscureText;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const _FancyField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.isReadOnly = false,
    this.obscureText = false,
    this.suffixIcon,
    this.onTap,
    this.validator,
  });

  @override
  State<_FancyField> createState() => _FancyFieldState();
}

class _FancyFieldState extends State<_FancyField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode();
  bool _focused = false;
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _glow = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _focus.addListener(() {
      setState(() => _focused = _focus.hasFocus);
      _focused ? _ctrl.forward() : _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = Provider.of<ThemeProvider>(context);
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focused ? widget.accentColor : currentTheme.border,
            width: _focused ? 1.5 : 1.0,
          ),
          color: _focused
              ? widget.accentColor.withValues(alpha: 0.02)
              : currentTheme.elevated,
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.12),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          readOnly: widget.isReadOnly,
          obscureText: widget.obscureText,
          onTap: widget.onTap,
          validator: widget.validator,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: currentTheme.textHigh,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            labelStyle: TextStyle(
              color: _focused ? widget.accentColor : currentTheme.textLow,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            hintStyle: TextStyle(color: currentTheme.textLow.withValues(alpha: 0.5), fontSize: 14),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _focused
                    ? widget.accentColor.withValues(alpha: 0.12)
                    : currentTheme.elevated2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: _focused ? widget.accentColor : currentTheme.textLow,
                size: 18,
              ),
            ),
            suffixIcon: widget.suffixIcon,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated Sign In Button ──────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  final bool isLoading;
  final Animation<double> shimmer;
  final VoidCallback onPressed;

  const _SignInButton({
    required this.isLoading,
    required this.shimmer,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final currentTheme = Provider.of<ThemeProvider>(context);
    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) => Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: currentTheme.accentGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: currentTheme.violet.withValues(alpha: 0.38),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer sweep
                if (!isLoading)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Align(
                      alignment: Alignment(shimmer.value, 0),
                      child: Container(
                        width: 60,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_open_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "SIGN IN",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot(this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Orb extends StatelessWidget {
  final double? top, bottom, left, right, size;
  final Color color;
  final Animation<double> anim;
  final bool flip;
  const _Orb({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.color,
    required this.anim,
    this.flip = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final phase = flip ? 1 - anim.value : anim.value;
        return Positioned(
          top: top != null ? top! + phase * 18 : null,
          bottom: bottom != null ? bottom! + phase * 18 : null,
          left: left,
          right: right,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        );
      },
    );
  }
}
