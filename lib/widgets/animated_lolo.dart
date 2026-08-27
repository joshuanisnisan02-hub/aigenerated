import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedLolo extends StatefulWidget {
  const AnimatedLolo({
    super.key,
    required this.isThinking,
    required this.isSpeaking,
  });

  final bool isThinking;
  final bool isSpeaking;

  @override
  State<AnimatedLolo> createState() => _AnimatedLoloState();
}

class _AnimatedLoloState extends State<AnimatedLolo>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _narration;
  late final AnimationController _sparkle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _narration = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedLolo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_narration.isAnimating) {
      _narration.repeat();
    } else if (!widget.isSpeaking && _narration.isAnimating) {
      _narration.stop();
      _narration.value = 0;
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _narration.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _narration, _sparkle]),
      builder: (context, _) {
        final idlePhase = _idle.value * math.pi * 2;
        final talkPhase = _narration.value * math.pi * 2;

        final breathe = 1 + math.sin(idlePhase) * 0.008;
        final idleLift = math.sin(idlePhase) * 3.0;
        final idleTilt = math.sin(idlePhase * .5) * .006;

        final speakingNod = widget.isSpeaking ? math.sin(talkPhase) * 2.5 : 0.0;
        final speakingTilt = widget.isSpeaking
            ? math.sin(talkPhase * .5) * .012
            : 0.0;
        final speakingScale = widget.isSpeaking
            ? 1 + math.sin(talkPhase * 1.5).abs() * .004
            : 1.0;

        final thinkingTilt = widget.isThinking ? -.018 : 0.0;
        final totalTilt = idleTilt + speakingTilt + thinkingTilt;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.12),
                    radius: .78,
                    colors: [
                      const Color(0xFFFFE7B0).withOpacity(.28),
                      const Color(0xFFE9C98C).withOpacity(.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _NarrationAuraPainter(
                    speaking: widget.isSpeaking,
                    thinking: widget.isThinking,
                    pulse: _narration.value,
                    sparkle: _sparkle.value,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              child: Container(
                width: 230,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const RadialGradient(
                    colors: [
                      Color(0x4D2B2118),
                      Color(0x122B2118),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, idleLift + speakingNod),
              child: Transform.rotate(
                angle: totalTilt,
                child: Transform.scale(
                  scale: breathe * speakingScale,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A4723).withOpacity(.18),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/lakbay_lolo_3d.jpg',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NarrationAuraPainter extends CustomPainter {
  _NarrationAuraPainter({
    required this.speaking,
    required this.thinking,
    required this.pulse,
    required this.sparkle,
  });

  final bool speaking;
  final bool thinking;
  final double pulse;
  final double sparkle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .46);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x26B88A44);

    canvas.drawCircle(center, size.shortestSide * .22, ring);
    ring.color = const Color(0x14B88A44);
    canvas.drawCircle(center, size.shortestSide * .30, ring);

    if (speaking) {
      final wave = .5 + .5 * math.sin(pulse * math.pi * 2);
      final voicePaint = Paint()
        ..color = const Color(0xFFB67C2E).withOpacity(.34 + wave * .22)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      final y = size.height * .56;
      final leftX = size.width * .12;
      final rightX = size.width * .88;

      for (var i = 0; i < 4; i++) {
        final h = 10 + i * 5 + wave * 8;
        canvas.drawLine(
          Offset(leftX - i * 10, y - h / 2),
          Offset(leftX - i * 10, y + h / 2),
          voicePaint,
        );
        canvas.drawLine(
          Offset(rightX + i * 10, y - h / 2),
          Offset(rightX + i * 10, y + h / 2),
          voicePaint,
        );
      }
    }

    if (thinking) {
      final sparklePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFD49A46).withOpacity(.76);

      final points = [
        Offset(size.width * .19, size.height * .20),
        Offset(size.width * .76, size.height * .16),
        Offset(size.width * .82, size.height * .30),
      ];

      for (var i = 0; i < points.length; i++) {
        final r = 4.0 + (((sparkle + i * .2) % 1) * 3.0);
        _drawSparkle(canvas, points[i], r, sparklePaint);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * .30, c.dy - r * .30)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * .30, c.dy + r * .30)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * .30, c.dy + r * .30)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * .30, c.dy - r * .30)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NarrationAuraPainter oldDelegate) {
    return oldDelegate.speaking != speaking ||
        oldDelegate.thinking != thinking ||
        oldDelegate.pulse != pulse ||
        oldDelegate.sparkle != sparkle;
  }
}
