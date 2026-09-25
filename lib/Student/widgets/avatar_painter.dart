import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:bhc_erp/Student/services/avatar_service.dart';

// ─── Color-matrix filter presets ─────────────────────────────────────────────
/// Returns enhanced [ColorFilter] for artistic effects
ColorFilter avatarColorFilter(int filterIndex) {
  switch (filterIndex) {
    case 1: // Cartoon Pop
      return const ColorFilter.matrix([
        1.6,
        -0.2,
        -0.1,
        0,
        -8,
        -0.1,
        1.6,
        -0.1,
        0,
        -8,
        -0.1,
        -0.2,
        1.6,
        0,
        -8,
        0,
        0,
        0,
        1.2,
        0,
      ]);
    case 2: // Pencil Sketch
      return const ColorFilter.matrix([
        1.8,
        1.8,
        1.8,
        0,
        -220,
        1.8,
        1.8,
        1.8,
        0,
        -220,
        1.8,
        1.8,
        1.8,
        0,
        -220,
        0,
        0,
        0,
        1,
        0,
      ]);
    case 3: // Anime Cel
      return const ColorFilter.matrix([
        1.3,
        0.1,
        0,
        0,
        12,
        0,
        1.25,
        0.05,
        0,
        8,
        0.05,
        0,
        1.2,
        0,
        5,
        0,
        0,
        0,
        1.1,
        0,
      ]);
    case 4: // Watercolor
      return const ColorFilter.matrix([
        1.1,
        0.05,
        0.05,
        0,
        18,
        0.05,
        1.08,
        0.05,
        0,
        15,
        0.05,
        0.05,
        1.12,
        0,
        20,
        0,
        0,
        0,
        0.95,
        0,
      ]);
    case 5: // Comic Book
      return const ColorFilter.matrix([
        1.5,
        -0.1,
        -0.2,
        0,
        -10,
        -0.1,
        1.4,
        -0.1,
        0,
        -5,
        -0.2,
        -0.1,
        1.3,
        0,
        -15,
        0,
        0,
        0,
        1.3,
        0,
      ]);
    case 6: // Oil Painting
      return const ColorFilter.matrix([
        1.2,
        0.08,
        0.02,
        0,
        8,
        0.05,
        1.18,
        0.05,
        0,
        6,
        0.02,
        0.08,
        1.15,
        0,
        4,
        0,
        0,
        0,
        1.05,
        0,
      ]);
    case 7: // Charcoal
      return const ColorFilter.matrix([
        1.2,
        1.2,
        1.2,
        0,
        -180,
        1.2,
        1.2,
        1.2,
        0,
        -180,
        1.2,
        1.2,
        1.2,
        0,
        -180,
        0,
        0,
        0,
        1,
        0,
      ]);
    case 8: // Pastel Dream
      return const ColorFilter.matrix([
        1.05,
        0.12,
        0.08,
        0,
        22,
        0.1,
        1.02,
        0.13,
        0,
        18,
        0.08,
        0.1,
        1.0,
        0,
        25,
        0,
        0,
        0,
        0.98,
        0,
      ]);
    case 9: // Neon Glow
      return const ColorFilter.matrix([
        1.7,
        -0.15,
        -0.1,
        0,
        5,
        -0.05,
        1.5,
        -0.05,
        0,
        -2,
        -0.1,
        -0.05,
        1.8,
        0,
        10,
        0,
        0,
        0,
        1.2,
        0,
      ]);
    default: // Original
      return const ColorFilter.matrix([
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
  }
}

// ─── Frame painter with NONE option ────────────────────────────────────────────
class AvatarFramePainter extends CustomPainter {
  final int frameStyle;
  final Color badgeColor;
  AvatarFramePainter({required this.frameStyle, required this.badgeColor});

  @override
  void paint(Canvas canvas, Size size) {
    // If frameStyle is -1 (None), don't draw anything
    if (frameStyle == -1) return;

    final r = size.width / 2;
    final center = Offset(r, r);
    final paint = Paint()..style = PaintingStyle.stroke;

    switch (frameStyle) {
      case 0: // Classic single ring
        canvas.drawCircle(
          center,
          r - 2,
          paint
            ..color = badgeColor
            ..strokeWidth = 3.5,
        );
        break;

      case 1: // Glow (simulated via multiple translucent rings)
        for (int i = 0; i < 4; i++) {
          canvas.drawCircle(
            center,
            r - 1.0 - i * 2.5,
            paint
              ..color = badgeColor.withOpacity(0.08 + i * 0.06)
              ..strokeWidth = 5.0 - i,
          );
        }
        canvas.drawCircle(
            center,
            r - 2.0,
            paint
              ..color = badgeColor
              ..strokeWidth = 2.5);
        break;

      case 2: // Dashed
        const dashCount = 24;
        const gap = 2 * math.pi / dashCount;
        final dashPaint = Paint()
          ..color = badgeColor
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        for (int i = 0; i < dashCount; i += 2) {
          final start = i * gap;
          final end = start + gap * 0.65;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: r - 3),
            start,
            end - start,
            false,
            dashPaint,
          );
        }
        break;

      case 3: // Star points around ring
        canvas.drawCircle(
            center,
            r - 3.0,
            paint
              ..color = badgeColor
              ..strokeWidth = 2.0);
        final starPaint = Paint()
          ..color = badgeColor
          ..style = PaintingStyle.fill;
        for (int i = 0; i < 8; i++) {
          final angle = i * (2 * math.pi / 8) - math.pi / 2;
          final ox = center.dx + (r - 3) * math.cos(angle);
          final oy = center.dy + (r - 3) * math.sin(angle);
          _drawStar(canvas, Offset(ox, oy), 5.0, starPaint);
        }
        break;

      case 4: // Double ring
        canvas.drawCircle(
            center,
            r - 2.0,
            paint
              ..color = badgeColor
              ..strokeWidth = 2.0);
        canvas.drawCircle(
            center,
            r - 7.0,
            paint
              ..color = badgeColor.withOpacity(0.5)
              ..strokeWidth = 1.5);
        break;

      case 5: // Gradient ring (drawn as arc segments)
        final colors = [
          badgeColor,
          HSLColor.fromColor(badgeColor)
              .withHue((HSLColor.fromColor(badgeColor).hue + 60) % 360)
              .toColor(),
          HSLColor.fromColor(badgeColor)
              .withHue((HSLColor.fromColor(badgeColor).hue + 120) % 360)
              .toColor(),
          badgeColor,
        ];
        const segments = 60;
        const step = 2 * math.pi / segments;
        for (int i = 0; i < segments; i++) {
          final t = i / segments;
          final color =
              Color.lerp(colors[0], colors[2], math.sin(t * math.pi)) ??
                  badgeColor;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: r - 3),
            i * step,
            step + 0.02,
            false,
            Paint()
              ..color = color
              ..strokeWidth = 4.0
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.butt,
          );
        }
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (i * math.pi / 5) - math.pi / 2;
      final rad = i.isEven ? r : r * 0.45;
      final x = center.dx + rad * math.cos(angle);
      final y = center.dy + rad * math.sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AvatarFramePainter old) =>
      old.frameStyle != frameStyle || old.badgeColor != badgeColor;
}

// ─── Placeholder painter (shown when no photo) ───────────────────────────────
class _PlaceholderPainter extends CustomPainter {
  final Color bg;
  final Color fg;
  _PlaceholderPainter({required this.bg, required this.fg});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Background gradient
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [bg.withOpacity(0.3), bg.withOpacity(0.6)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Person silhouette
    final headR = r * 0.32;
    canvas.drawCircle(
      Offset(center.dx, center.dy - r * 0.18),
      headR,
      Paint()..color = fg.withOpacity(0.35),
    );
    final body = Path()
      ..moveTo(center.dx - r * 0.4, center.dy + r * 0.7)
      ..quadraticBezierTo(center.dx - r * 0.38, center.dy + r * 0.15,
          center.dx - r * 0.28, center.dy + r * 0.05)
      ..quadraticBezierTo(center.dx, center.dy - r * 0.0, center.dx + r * 0.28,
          center.dy + r * 0.05)
      ..quadraticBezierTo(center.dx + r * 0.38, center.dy + r * 0.15,
          center.dx + r * 0.4, center.dy + r * 0.7)
      ..close();
    canvas.drawPath(body, Paint()..color = fg.withOpacity(0.25));

    // Camera icon hint
    final iconPaint = Paint()
      ..color = fg.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final iconFill = Paint()
      ..color = fg.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    final cx = center.dx, cy = center.dy + r * 0.38;
    final ir = r * 0.18;
    // camera body
    final camBody = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy), width: ir * 3.2, height: ir * 2.2),
      const Radius.circular(4),
    );
    canvas.drawRRect(camBody, iconPaint);
    // lens
    canvas.drawCircle(Offset(cx, cy), ir * 0.7, iconPaint);
    canvas.drawCircle(Offset(cx, cy), ir * 0.4, iconFill);
    // viewfinder bump
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - ir * 0.6, cy - ir * 1.15),
            width: ir * 0.9,
            height: ir * 0.5),
        const Radius.circular(2),
      ),
      iconPaint,
    );
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) => old.bg != bg || old.fg != fg;
}

// ─── Main AvatarWidget ────────────────────────────────────────────────────────
/// Drop-in replacement for the old cartoon AvatarWidget.
/// Shows the student's real photo with optional cartoon filter + decorative frame.
class AvatarWidget extends StatelessWidget {
  final AvatarConfig config;
  final double size;
  final bool circular; // kept for API compatibility; always renders as circle

  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 96,
    this.circular = true,
  });

  Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final bg = _hexColor(config.bgColor);
    final badge = _hexColor(config.badgeColor);

    Widget photoWidget;

    if (config.hasPhoto) {
      // Real photo with color-filter applied
      photoWidget = ColorFiltered(
        colorFilter: avatarColorFilter(config.filterIndex),
        child: Image.file(
          File(config.photoPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(bg, badge),
        ),
      );
    } else {
      photoWidget = _buildPlaceholder(bg, badge);
    }

    // Clip to circle
    Widget avatar = ClipOval(
      child: SizedBox(width: size, height: size, child: photoWidget),
    );

    // Sticker overlay
    final stickerEmoji =
        stickerEmojis[config.sticker.clamp(0, stickerEmojis.length - 1)];

    return Stack(
      alignment: Alignment.center,
      children: [
        // Frame ring (only drawn if frameStyle is not -1)
        if (config.frameStyle != -1)
          CustomPaint(
            painter: AvatarFramePainter(
                frameStyle: config.frameStyle, badgeColor: badge),
            size: Size(size + 6, size + 6),
            child: Padding(padding: const EdgeInsets.all(3), child: avatar),
          )
        else
          avatar, // No frame, just the avatar
        // Sticker (bottom-right badge position)
        if (config.sticker > 0)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.18), blurRadius: 4.0)
                ],
              ),
              child: Center(
                child:
                    Text(stickerEmoji, style: TextStyle(fontSize: size * 0.17)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder(Color bg, Color badge) {
    return CustomPaint(
      painter: _PlaceholderPainter(bg: badge, fg: badge),
      size: Size(size, size),
    );
  }
}
