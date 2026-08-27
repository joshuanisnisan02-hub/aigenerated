import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  late final AnimationController _mouth;
  late final AnimationController _blink;
  late final AnimationController _sparkle;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
    _mouth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _scheduleBlink();
  }

  Future<void> _scheduleBlink() async {
    while (mounted) {
      await Future<void>.delayed(
        Duration(seconds: 3 + _random.nextInt(4)),
      );
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedLolo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_mouth.isAnimating) {
      _mouth.repeat(reverse: true);
    } else if (!widget.isSpeaking && _mouth.isAnimating) {
      _mouth.stop();
      _mouth.value = 0;
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _mouth.dispose();
    _blink.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _mouth, _blink, _sparkle]),
      builder: (context, _) {
        final phase = _idle.value * math.pi * 2;
        final breathe = 1 + (math.sin(phase) * .014);
        final sway = math.sin(phase) * .018;
        final lift = math.sin(phase) * 5.0;
        final talkPulse = widget.isSpeaking
            ? .5 + (math.sin(_mouth.value * math.pi) * .5)
            : 0.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.12),
                    radius: .72,
                    colors: [
                      const Color(0xFFFFE4AA).withOpacity(.30),
                      const Color(0xFFF0D39B).withOpacity(.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CharacterAuraPainter(
                    speaking: widget.isSpeaking,
                    thinking: widget.isThinking,
                    pulse: talkPulse,
                    sparkle: _sparkle.value,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              child: Container(
                width: 225,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const RadialGradient(
                    colors: [
                      Color(0x552B2118),
                      Color(0x152B2118),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, widget.isThinking ? lift * .55 : lift),
              child: Transform.rotate(
                angle: widget.isThinking ? -.028 : sway,
                child: Transform.scale(
                  scale: widget.isThinking ? .99 : breathe,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 300,
                        height: 480,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(180),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C4B25).withOpacity(.16),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/images/lakbay_lolo.svg',
                        fit: BoxFit.contain,
                      ),
                      Align(
                        alignment: const Alignment(0.0, -.42),
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: widget.isSpeaking
                                ? .18 + (.34 * _mouth.value)
                                : 0,
                            duration: const Duration(milliseconds: 70),
                            child: Transform.scale(
                              scaleY: .45 + (.95 * _mouth.value),
                              child: Container(
                                width: 36,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4D1E14),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4D1E14)
                                          .withOpacity(.18),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0.0, -.56),
                        child: Transform.scale(
                          scaleY: _blink.value,
                          child: Container(
                            width: 92,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE59255),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _CharacterAuraPainter extends CustomPainter {
  _CharacterAuraPainter({
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
    final center = Offset(size.width / 2, size.height * .43);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x2AB88A44);

    canvas.drawCircle(center, size.shortestSide * .23, ring);
    ring.color = const Color(0x16B88A44);
    canvas.drawCircle(center, size.shortestSide * .31, ring);

    if (speaking) {
      final voicePaint = Paint()
        ..color = const Color(0xFFB67C2E).withOpacity(.40 + pulse * .28)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;

      final baseY = size.height * .54;
      final leftX = size.width * .18;
      final rightX = size.width * .82;

      for (var i = 0; i < 4; i++) {
        final h = 14 + (i * 7) + (pulse * 10);
        canvas.drawLine(
          Offset(leftX - i * 13, baseY - h / 2),
          Offset(leftX - i * 13, baseY + h / 2),
          voicePaint,
        );
        canvas.drawLine(
          Offset(rightX + i * 13, baseY - h / 2),
          Offset(rightX + i * 13, baseY + h / 2),
          voicePaint,
        );
      }
    }

    if (thinking) {
      final sparklePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFD49A46).withOpacity(.82);

      final points = [
        Offset(size.width * .20, size.height * .18),
        Offset(size.width * .73, size.height * .15),
        Offset(size.width * .82, size.height * .28),
      ];

      for (var i = 0; i < points.length; i++) {
        final r = 4.5 + (((sparkle + i * .23) % 1) * 3.5);
        _drawSparkle(canvas, points[i], r, sparklePaint);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * .32, c.dy - r * .32)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * .32, c.dy + r * .32)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * .32, c.dy + r * .32)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * .32, c.dy - r * .32)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CharacterAuraPainter oldDelegate) {
    return oldDelegate.speaking != speaking ||
        oldDelegate.thinking != thinking ||
        oldDelegate.pulse != pulse ||
        oldDelegate.sparkle != sparkle;
  }
}
