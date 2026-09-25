import 'package:bhc_erp/Staff/common/OTPLoginScreen.dart';
import 'package:bhc_erp/core/auth/auth_provider.dart';
import 'package:bhc_erp/Staff/screens/staff_dashboard.dart';
import 'package:bhc_erp/Staff/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => StaffThemeProvider()),
      ],
      child: Consumer<StaffThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'BHC Staff ERP',
            theme: themeProvider.themeData,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthWrapper(),
              '/login': (context) => const OTPLoginScreen(),
              '/staff-dashboard': (context) => const StaffDashboard(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with TickerProviderStateMixin {
  bool _isLoading = true;

  // Animation controllers
  late AnimationController _orbitCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _textCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _progressCtrl;

  late Animation<double> _orbitAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _textFadeAnim;
  late Animation<Offset> _textSlideAnim;
  late Animation<double> _ringAnim;
  late Animation<double> _particleAnim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkAuth();
  }

  void _initAnimations() {
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _orbitAnim = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_orbitCtrl);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _textFadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _ringAnim = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_ringCtrl);
    _particleAnim = Tween<double>(begin: 0, end: 1)
        .animate(_particleCtrl);
    _progressAnim = Tween<double>(begin: 0.3, end: 0.85)
        .animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));
  }

  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      await Future.delayed(const Duration(milliseconds: 2800));
    } else {
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _textCtrl.dispose();
    _ringCtrl.dispose();
    _particleCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<StaffThemeProvider>(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: _buildSplashScreen(theme),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isAuthenticated) return const OTPLoginScreen();
        return const StaffDashboard();
      },
    );
  }

  Widget _buildSplashScreen(StaffThemeProvider theme) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => CustomPaint(
            size: size,
            painter: _SplashBgPainter(
              theme: theme,
              progress: _glowAnim.value,
              particleProgress: _particleAnim.value,
            ),
          ),
        ),

        // ── Orbiting particles ───────────────────────────────────────────
        AnimatedBuilder(
          animation: _orbitAnim,
          builder: (_, __) => CustomPaint(
            size: size,
            painter: _OrbitPainter(
              theme: theme,
              angle: _orbitAnim.value,
              glowIntensity: _glowAnim.value,
            ),
          ),
        ),

        // ── Grid overlay ─────────────────────────────────────────────────
        Opacity(
          opacity: 0.04,
          child: CustomPaint(
            size: size,
            painter: _GridPainter(color: theme.cyan),
          ),
        ),

        // ── Core content ─────────────────────────────────────────────────
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 3D Logo sphere
              _buildLogoSphere(theme),

              const SizedBox(height: 40),

              // Animated text
              FadeTransition(
                opacity: _textFadeAnim,
                child: SlideTransition(
                  position: _textSlideAnim,
                  child: _buildTextBlock(theme),
                ),
              ),

              const SizedBox(height: 48),

              // Progress indicator
              FadeTransition(
                opacity: _textFadeAnim,
                child: _buildProgressBar(theme),
              ),

              const SizedBox(height: 20),

              // Status text
              FadeTransition(
                opacity: _textFadeAnim,
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Opacity(
                    opacity: 0.5 + _pulseCtrl.value * 0.5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.green,
                            boxShadow: [
                              BoxShadow(
                                color: theme.green.withOpacity(0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'INITIALIZING SECURE SESSION',
                          style: TextStyle(
                            color: theme.textLow,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Version tag ──────────────────────────────────────────────────
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _textFadeAnim,
            child: Column(
              children: [
                Text(
                  'Bishop Heber College',
                  style: TextStyle(
                    color: theme.textLow,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Staff ERP v1.0.0',
                  style: TextStyle(
                    color: theme.textLow.withOpacity(0.6),
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

Widget _buildLogoSphere(StaffThemeProvider theme) {
  return AnimatedBuilder(
    animation: Listenable.merge([_pulseAnim, _glowAnim, _ringAnim, _orbitAnim]),
    builder: (_, __) {
      return SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.cyan.withOpacity(0.15 + _glowAnim.value * 0.1),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: theme.violet.withOpacity(0.1 + _glowAnim.value * 0.08),
                      blurRadius: 60,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

            // Rotating outer dashed ring
            Transform.rotate(
              angle: _ringAnim.value,
              child: CustomPaint(
                size: const Size(160, 160),
                painter: _DashedRingPainter(
                  color: theme.cyan.withOpacity(0.3),
                  dashCount: 16,
                  strokeWidth: 1.5,
                ),
              ),
            ),

            // Counter-rotating inner ring
            Transform.rotate(
              angle: -_ringAnim.value * 0.7,
              child: CustomPaint(
                size: const Size(130, 130),
                painter: _DashedRingPainter(
                  color: theme.violet.withOpacity(0.4),
                  dashCount: 10,
                  strokeWidth: 1,
                ),
              ),
            ),

            // Orbiting dot 1
            Transform.rotate(
              angle: _orbitAnim.value,
              child: Transform.translate(
                offset: const Offset(72, 0),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.cyan,
                    boxShadow: [
                      BoxShadow(
                        color: theme.cyan.withOpacity(0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Orbiting dot 2 (offset by pi)
            Transform.rotate(
              angle: _orbitAnim.value + math.pi,
              child: Transform.translate(
                offset: const Offset(55, 0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.violet,
                    boxShadow: [
                      BoxShadow(
                        color: theme.violet.withOpacity(0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Orbiting dot 3 (offset by pi/2)
            Transform.rotate(
              angle: _orbitAnim.value + math.pi / 2,
              child: Transform.translate(
                offset: const Offset(80, 0),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.green,
                    boxShadow: [
                      BoxShadow(
                        color: theme.green.withOpacity(0.8),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3D Core sphere (behind the logo)
            Transform.scale(
              scale: _pulseAnim.value * 0.97,
              child: CustomPaint(
                size: const Size(100, 100),
                painter: _Sphere3DPainter(
                  primaryColor: theme.cyan,
                  secondaryColor: theme.violet,
                  glowProgress: _glowAnim.value,
                  isDark: theme.isDarkMode,
                ),
              ),
            ),

            // ─── COLLEGE LOGO (Replaces the school icon) ──────────────────
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png', // Make sure this path is correct
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image not found - shows college initials
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.cyan, theme.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'BHC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              'EST. 1975',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}



  Widget _buildTextBlock(StaffThemeProvider theme) {
    return Column(
      children: [
        // ERP label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: theme.cyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.cyan.withOpacity(0.2)),
          ),
          child: Text(
            'STAFF ERP SYSTEM',
            style: TextStyle(
              color: theme.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Main title
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [theme.cyan, theme.violet, theme.cyan],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: const Text(
            'BISHOP HEBER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              height: 1.0,
            ),
          ),
        ),
        Text(
          'COLLEGE',
          style: TextStyle(
            color: theme.textMid,
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 8,
          ),
        ),

        const SizedBox(height: 10),

        // Divider with glow
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Container(
            width: 120,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  theme.cyan.withOpacity(0.4 + _glowAnim.value * 0.3),
                  theme.violet.withOpacity(0.4 + _glowAnim.value * 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Tiruchirappalli — Est. 1975',
          style: TextStyle(
            color: theme.textLow,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(StaffThemeProvider theme) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _progressAnim,
          builder: (_, __) => Container(
            width: 220,
            height: 3,
            decoration: BoxDecoration(
              color: theme.border,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                // Animated fill
                FractionallySizedBox(
                  widthFactor: _progressAnim.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [theme.cyan, theme.violet],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.cyan.withOpacity(0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                // Shimmer effect
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Positioned(
                    left: 220 * _progressAnim.value - 20,
                    child: Container(
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _progressAnim,
          builder: (_, __) => Text(
            '${(_progressAnim.value * 100).toInt()}%',
            style: TextStyle(
              color: theme.textMid,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Custom Painters ────────────────────────────────────────────────────────────

class _SplashBgPainter extends CustomPainter {
  final StaffThemeProvider theme;
  final double progress;
  final double particleProgress;

  _SplashBgPainter({
    required this.theme,
    required this.progress,
    required this.particleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Deep radial gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        radius: 1.2,
        colors: [
          theme.isDarkMode
              ? const Color(0xFF0A0C2A).withOpacity(0.8)
              : const Color(0xFFEBEEFF).withOpacity(0.8),
          theme.bg,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Secondary glow blobs
    _drawGlowBlob(
      canvas,
      Offset(cx - 80, cy - 120),
      120,
      theme.cyan.withOpacity(0.06 + progress * 0.04),
    );
    _drawGlowBlob(
      canvas,
      Offset(cx + 80, cy + 100),
      100,
      theme.violet.withOpacity(0.05 + progress * 0.03),
    );
    _drawGlowBlob(
      canvas,
      Offset(cx, cy),
      80,
      theme.cyan.withOpacity(0.08 + progress * 0.05),
    );

    // Floating particles
    final random = math.Random(42);
    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = baseY - (particleProgress * 30 * (i % 3 + 0.5)) % size.height;
      final radius = 1.0 + random.nextDouble() * 2;
      final opacity = 0.08 + random.nextDouble() * 0.12;
      final colorChoice = i % 3;
      final color = colorChoice == 0
          ? theme.cyan.withOpacity(opacity)
          : colorChoice == 1
              ? theme.violet.withOpacity(opacity)
              : theme.green.withOpacity(opacity);
      particlePaint.color = color;
      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  void _drawGlowBlob(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SplashBgPainter old) => true;
}

class _OrbitPainter extends CustomPainter {
  final StaffThemeProvider theme;
  final double angle;
  final double glowIntensity;

  _OrbitPainter({
    required this.theme,
    required this.angle,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw orbit trails
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = theme.cyan.withOpacity(0.06);

    canvas.drawCircle(Offset(cx, cy), size.width * 0.42, orbitPaint);
    orbitPaint.color = theme.violet.withOpacity(0.05);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.35, orbitPaint);

    // Distant orbiting specks
    final specks = [
      (size.width * 0.42, angle * 0.5, theme.cyan, 3.0),
      (size.width * 0.42, angle * 0.5 + math.pi, theme.violet, 2.5),
      (size.width * 0.35, -angle * 0.4, theme.green, 2.0),
      (size.width * 0.35, -angle * 0.4 + math.pi * 2 / 3, theme.amber, 1.5),
    ];

    for (final (r, a, color, radius) in specks) {
      final dx = cx + r * math.cos(a);
      final dy = cy + r * math.sin(a);
      final speckPaint = Paint()
        ..color = color.withOpacity(0.35 + glowIntensity * 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius);
      canvas.drawCircle(Offset(dx, dy), radius, speckPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => true;
}

class _Sphere3DPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double glowProgress;
  final bool isDark;

  _Sphere3DPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Base sphere — dark glass look
    final basePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 1.0,
        colors: isDark
            ? [
                const Color(0xFF1C2060).withOpacity(0.95),
                const Color(0xFF0A0D2A).withOpacity(0.98),
              ]
            : [
                const Color(0xFFD8DCFF).withOpacity(0.95),
                const Color(0xFFA8B0F0).withOpacity(0.98),
              ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    final path = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(path, basePaint);

    // Outer glow ring on sphere edge
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        colors: [
          primaryColor.withOpacity(0.0),
          primaryColor.withOpacity(0.8 + glowProgress * 0.2),
          secondaryColor.withOpacity(0.6 + glowProgress * 0.2),
          primaryColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, edgePaint);

    // Specular highlight — top-left bright spot
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.55),
        radius: 0.55,
        colors: [
          Colors.white.withOpacity(0.25),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(path, highlightPaint);

    // Secondary specular — bottom right
    final specular2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.6, 0.55),
        radius: 0.45,
        colors: [
          secondaryColor.withOpacity(0.15 + glowProgress * 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(path, specular2);

    // Inner grid lines on sphere (latitude/longitude feel)
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = primaryColor.withOpacity(0.15);

    // Horizontal arc approximation
    for (double fraction in [0.33, 0.5, 0.67]) {
      final arcY = cy - r + (2 * r * fraction);
      final halfW = math.sqrt(math.max(0, r * r - (arcY - cy) * (arcY - cy)));
      if (halfW > 2) {
        final rect = Rect.fromCenter(
          center: Offset(cx, arcY),
          width: halfW * 2,
          height: halfW * 0.3,
        );
        canvas.drawArc(rect, 0, math.pi * 2, false, gridPaint);
      }
    }

    // Vertical center line
    canvas.drawLine(Offset(cx, cy - r * 0.9), Offset(cx, cy + r * 0.9), gridPaint);

    // Bottom inner shadow for depth
    final bottomShadow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, 0.6),
        radius: 0.7,
        colors: [
          Colors.black.withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(path, bottomShadow);
  }

  @override
  bool shouldRepaint(covariant _Sphere3DPainter old) => true;
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  final int dashCount;
  final double strokeWidth;

  _DashedRingPainter({
    required this.color,
    required this.dashCount,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - strokeWidth;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final anglePerDash = (2 * math.pi) / dashCount;
    final dashAngle = anglePerDash * 0.45;
    final gapAngle = anglePerDash * 0.55;

    double currentAngle = 0;
    while (currentAngle < 2 * math.pi) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        currentAngle,
        dashAngle,
        false,
        paint,
      );
      currentAngle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => false;
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const sp = 32.0;
    for (double x = 0; x <= size.width; x += sp) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += sp) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}