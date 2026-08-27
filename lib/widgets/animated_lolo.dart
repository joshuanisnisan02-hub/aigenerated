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
      duration: const Duration(milliseconds: 170),
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
      await Future<void>.delayed(Duration(seconds: 3 + _random.nextInt(4)));
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
        final breathe = 1 + (math.sin(phase) * .012);
        final sway = math.sin(phase) * .012;
        final lift = math.sin(phase) * 4.0;
        final talkPulse = widget.isSpeaking
            ? .5 + (math.sin(_mouth.value * math.pi) * .5)
            : 0.0;
        final blinkAmount = Curves.easeInOut.transform(_blink.value);

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
                angle: widget.isThinking ? -.022 : sway,
                child: Transform.scale(
                  scale: widget.isThinking ? .992 : breathe,
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
                        alignment: const Alignment(0.0, -.52),
                        child: IgnorePointer(
                          child: SizedBox(
                            width: 150,
                            height: 112,
                            child: CustomPaint(
                              painter: _NaturalFacePainter(
                                blinkAmount: blinkAmount,
                                mouthPhase: _mouth.value,
                                idlePhase: phase,
                                isSpeaking: widget.isSpeaking,
                                isThinking: widget.isThinking,
                              ),
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

class _NaturalFacePainter extends CustomPainter {
  _NaturalFacePainter({
    required this.blinkAmount,
    required this.mouthPhase,
    required this.idlePhase,
    required this.isSpeaking,
    required this.isThinking,
  });

  final double blinkAmount;
  final double mouthPhase;
  final double idlePhase;
  final bool isSpeaking;
  final bool isThinking;

  static const _brow = Color(0xFF6C6D70);
  static const _eye = Color(0xFF32261E);
  static const _mouth = Color(0xFF6D291F);
  static const _lip = Color(0xFF8E4330);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final eyeY = size.height * .29;
    final eyeOpen = 1.0 - blinkAmount;
    final lookX = isThinking ? -2.2 : math.sin(idlePhase * .55) * .8;
    final lookY = isThinking ? -.8 : math.cos(idlePhase * .42) * .45;

    _drawBrow(canvas, Offset(cx - 34, eyeY - 17), false);
    _drawBrow(canvas, Offset(cx + 34, eyeY - 17), true);
    _drawEye(canvas, Offset(cx - 34, eyeY), eyeOpen, lookX, lookY);
    _drawEye(canvas, Offset(cx + 34, eyeY), eyeOpen, lookX, lookY);
    _drawMouth(canvas, cx, size.height * .79);
  }

  void _drawBrow(Canvas canvas, Offset center, bool right) {
    final direction = right ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(center.dx - 13 * direction, center.dy + 3)
      ..quadraticBezierTo(
        center.dx - 3 * direction,
        center.dy - 6,
        center.dx + 13 * direction,
        center.dy + 2,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = _brow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEye(
    Canvas canvas,
    Offset center,
    double openness,
    double lookX,
    double lookY,
  ) {
    if (openness < .12) {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: 25, height: 7),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFF9D5E3C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final eyeRect = Rect.fromCenter(
      center: center,
      width: 25,
      height: 10 + (7 * openness),
    );

    canvas.drawOval(eyeRect, Paint()..color = Colors.white);
    canvas.drawOval(
      eyeRect,
      Paint()
        ..color = const Color(0xFFB56B44).withOpacity(.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    final pupil = center.translate(lookX, lookY);
    canvas.drawCircle(pupil, 5.0, Paint()..color = _eye);
    canvas.drawCircle(
      pupil.translate(-1.5, -1.3),
      1.3,
      Paint()..color = Colors.white,
    );
  }

  void _drawMouth(Canvas canvas, double cx, double y) {
    if (!isSpeaking) {
      final smile = Path()
        ..moveTo(cx - 17, y)
        ..quadraticBezierTo(cx, y + 10, cx + 17, y);
      canvas.drawPath(
        smile,
        Paint()
          ..color = _lip
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.7
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final wave = .5 + .5 * math.sin(mouthPhase * math.pi);
    final shapeIndex = ((mouthPhase * 5).floor()) % 5;

    double width;
    double height;
    switch (shapeIndex) {
      case 0:
        width = 25;
        height = 9 + 5 * wave;
        break;
      case 1:
        width = 18;
        height = 16 + 6 * wave;
        break;
      case 2:
        width = 31;
        height = 11 + 7 * wave;
        break;
      case 3:
        width = 21;
        height = 19 + 5 * wave;
        break;
      default:
        width = 27;
        height = 13 + 5 * wave;
    }

    final rect = Rect.fromCenter(
      center: Offset(cx, y),
      width: width,
      height: height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = _mouth,
    );

    if (shapeIndex == 0 || shapeIndex == 2) {
      final teeth = Rect.fromCenter(
        center: Offset(cx, y - height * .16),
        width: width * .74,
        height: math.max(2.8, height * .24),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(teeth, const Radius.circular(3)),
        Paint()..color = Colors.white,
      );
    } else {
      final tongue = Rect.fromCenter(
        center: Offset(cx, y + height * .22),
        width: width * .44,
        height: math.max(2.8, height * .24),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tongue, const Radius.circular(4)),
        Paint()..color = const Color(0xFFD86E72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NaturalFacePainter oldDelegate) {
    return oldDelegate.blinkAmount != blinkAmount ||
        oldDelegate.mouthPhase != mouthPhase ||
        oldDelegate.idlePhase != idlePhase ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.isThinking != isThinking;
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
