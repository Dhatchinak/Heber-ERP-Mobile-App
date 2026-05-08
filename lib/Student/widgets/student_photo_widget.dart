// student_photo_widget.dart
import 'package:bhc_erp/Student/services/photo_service.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';


class StudentPhotoWidget extends StatefulWidget {
  final String rollNo;
  final double size;
  final Color? borderColor;
  final bool show3DEffect;
  final bool showGlow;
  final bool showRing;

  const StudentPhotoWidget({
    super.key,
    required this.rollNo,
    this.size = 64,
    this.borderColor,
    this.show3DEffect = true,
    this.showGlow = true,
    this.showRing = true,
  });

  @override
  State<StudentPhotoWidget> createState() => _StudentPhotoWidgetState();
}

class _StudentPhotoWidgetState extends State<StudentPhotoWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _pulse;
  late Animation<double> _shimmer;

  String? _photoUrl;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _shimmer = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut);
    _loadPhoto();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

// student_photo_widget.dart - Update _loadPhoto
Future<void> _loadPhoto() async {
  if (widget.rollNo.trim().isEmpty) return;
  
  // Already has photo URL in memory?
  final existing = PhotoService.getCachedPhotoUrlSync(widget.rollNo);
  if (existing != null) {
    if (mounted) setState(() => _photoUrl = existing);
    return;
  }
  
  // Try cache
  String? url = await PhotoService.getCachedPhotoUrl(widget.rollNo);
  if (url == null) {
    url = await PhotoService.getStudentPhotoUrl(widget.rollNo);
    if (url != null) await PhotoService.cacheStudentPhoto(widget.rollNo);
  }
  if (mounted) setState(() => _photoUrl = url);
}

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final borderColor = widget.borderColor ?? const Color(0xFF7B8CFF);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _rotateCtrl, _shimmerCtrl]),
      builder: (_, __) {
        return SizedBox(
          width: size + 16,
          height: size + 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              if (widget.showGlow)
                Container(
                  width: size + 16 + _pulse.value * 6,
                  height: size + 16 + _pulse.value * 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        borderColor.withOpacity(0.3 + _pulse.value * 0.15),
                        borderColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),

              // Rotating dashed ring
              if (widget.showRing)
                Transform.rotate(
                  angle: _rotateCtrl.value * 2 * 3.14159,
                  child: CustomPaint(
                    size: Size(size + 12, size + 12),
                    painter: _DashedRingPainter(
                      color: borderColor.withOpacity(0.6),
                      strokeWidth: 1.5,
                      dashCount: 12,
                    ),
                  ),
                ),

              // Photo container with 3D effect
              Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(_pulse.value * 0.04)
                  ..rotateY(_pulse.value * 0.02),
                alignment: Alignment.center,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withOpacity(0.4 + _pulse.value * 0.2),
                        blurRadius: 16 + _pulse.value * 8,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _photoUrl != null
                        ? Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: _photoUrl!,
                                width: size,
                                height: size,
                                fit: BoxFit.cover,
                                httpHeaders: PhotoService.headers,
                                placeholder: (_, __) => _buildPlaceholder(borderColor),
                                errorWidget: (_, __, ___) => _buildPlaceholder(borderColor),
                                imageBuilder: (_, imageProvider) {
                                  if (!_loaded) {
                                    WidgetsBinding.instance.addPostFrameCallback(
                                        (_) => mounted ? setState(() => _loaded = true) : null);
                                  }
                                  return Image(image: imageProvider, fit: BoxFit.cover);
                                },
                              ),
                              // Shimmer overlay on load
                              if (!_loaded)
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _shimmer,
                                    builder: (_, __) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment(-1 + _shimmer.value * 3, 0),
                                          end: Alignment(_shimmer.value * 3, 0),
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withOpacity(0.15),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Glass highlight
                              Positioned(
                                top: 0, left: 0, right: 0,
                                height: size * 0.4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.12),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _buildPlaceholder(borderColor),
                  ),
                ),
              ),

              // Online indicator
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  width: size * 0.18,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5A0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5A0).withOpacity(
                            0.5 + _pulse.value * 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(Color color) {
    return Container(
      color: color.withOpacity(0.1),
      child: Icon(
        Icons.person_rounded,
        color: color,
        size: widget.size * 0.45,
      ),
    );
  }
}

// Dashed ring painter
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final dashAngle = (2 * 3.14159) / (dashCount * 2);

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}