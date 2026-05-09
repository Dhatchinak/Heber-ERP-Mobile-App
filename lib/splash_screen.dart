import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _ringCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _exitCtrl;

  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _ring3;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoGlow;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _tagOpacity;
  late Animation<Offset> _tagSlide;
  late Animation<double> _exitScale;
  late Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))..repeat();
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _ring1 = CurvedAnimation(parent: _ringCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _ring2 = CurvedAnimation(parent: _ringCtrl, curve: const Interval(0.15, 0.75, curve: Curves.easeOut));
    _ring3 = CurvedAnimation(parent: _ringCtrl, curve: const Interval(0.3, 0.9, curve: Curves.easeOut));

    _logoScale   = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeIn));
    _logoGlow    = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);
    _textSlide   = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _tagOpacity  = CurvedAnimation(parent: _textCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn));
    _tagSlide    = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));

    _exitScale   = Tween<double>(begin: 1.0, end: 1.1)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _ringCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textCtrl.forward();
    // Hold for 1.8s then exit
    await Future.delayed(const Duration(milliseconds: 1800));
    _particleCtrl.stop();
    await _exitCtrl.forward();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.04), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _particleCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (context, child) => Opacity(
        opacity: _exitOpacity.value,
        child: Transform.scale(scale: _exitScale.value, child: child),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF05060F),
        body: Stack(
          children: [
            // ── Radial gradient bg ─────────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      const Color(0xFF0D1130),
                      const Color(0xFF05060F),
                    ],
                  ),
                ),
              ),
            ),

            // ── Animated particles ─────────────────────────────────────
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                size: Size(size.width, size.height),
                painter: _ParticlePainter(_particleCtrl.value),
              ),
            ),

            // ── Expanding rings ────────────────────────────────────────
            Center(
              child: AnimatedBuilder(
                animation: _ringCtrl,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    _Ring(progress: _ring3.value, size: 340, color: const Color(0xFF7B8CFF), opacity: 0.06),
                    _Ring(progress: _ring2.value, size: 260, color: const Color(0xFFB06EFF), opacity: 0.10),
                    _Ring(progress: _ring1.value, size: 180, color: const Color(0xFF7B8CFF), opacity: 0.18),
                  ],
                ),
              ),
            ),

            // ── Main content ───────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo container
                  AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value.clamp(0.0, 1.0) * 0.4 + 0.6,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF111428),
                            border: Border.all(
                              color: const Color(0xFF7B8CFF).withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B8CFF).withOpacity(_logoGlow.value * 0.5),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                              BoxShadow(
                                color: const Color(0xFFB06EFF).withOpacity(_logoGlow.value * 0.25),
                                blurRadius: 60,
                                spreadRadius: 12,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/bhclogo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.school_rounded,
                                size: 52,
                                color: Color(0xFF7B8CFF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // College name
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, __) => SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF7B8CFF), Color(0xFFB06EFF)],
                              ).createShader(bounds),
                              child: const Text(
                                'BISHOP HEBER',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                            const Text(
                              'COLLEGE',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFFEDF0FF),
                                letterSpacing: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tag line
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, __) => SlideTransition(
                      position: _tagSlide,
                      child: FadeTransition(
                        opacity: _tagOpacity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B8CFF), Color(0xFFB06EFF)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B8CFF).withOpacity(0.35),
                                blurRadius: 16,
                              )
                            ],
                          ),
                          child: const Text(
                            'UNIFIED ERP PORTAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),

                  // Loading dots
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, __) => FadeTransition(
                      opacity: _tagOpacity,
                      child: _LoadingDots(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom tagline ─────────────────────────────────────────
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, __) => FadeTransition(
                  opacity: _tagOpacity,
                  child: const Text(
                    'Tiruchirappalli · Est. 1948',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3A4A6B),
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanding ring widget ─────────────────────────────────────────────────────
class _Ring extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;
  final double opacity;
  const _Ring({required this.progress, required this.size,
      required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (1 - progress) * opacity,
      child: Container(
        width: size * progress,
        height: size * progress,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
    );
  }
}

// ── Particle painter ──────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double t;
  static final _rng = math.Random(42);
  static final List<_Particle> _particles = List.generate(
      30, (_) => _Particle(_rng));

  _ParticlePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final x = p.x * size.width;
      final y = ((p.y + t * p.speed) % 1.0) * size.height;
      final opacity = (math.sin((t + p.phase) * math.pi * 2) * 0.5 + 0.5) * p.opacity;
      canvas.drawCircle(
        Offset(x, y),
        p.radius,
        Paint()..color = p.color.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => t != old.t;
}

class _Particle {
  final double x, y, speed, radius, opacity, phase;
  final Color color;

  _Particle(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        speed = 0.05 + rng.nextDouble() * 0.1,
        radius = 0.5 + rng.nextDouble() * 1.5,
        opacity = 0.2 + rng.nextDouble() * 0.5,
        phase = rng.nextDouble(),
        color = rng.nextBool() ? const Color(0xFF7B8CFF) : const Color(0xFFB06EFF);
}

// ── Animated loading dots ─────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i / 3.0;
          final t = (((_ctrl.value - delay) % 1.0) + 1.0) % 1.0;
          final scale = 0.6 + math.sin(t * math.pi) * 0.4;
          final opacity = 0.3 + math.sin(t * math.pi) * 0.7;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7B8CFF),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
