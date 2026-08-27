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
  late final AnimationController _talk;
  late final AnimationController _blink;
  late final AnimationController _sparkle;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _talk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
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
    if (widget.isSpeaking && !_talk.isAnimating) {
      _talk.repeat();
    } else if (!widget.isSpeaking && _talk.isAnimating) {
      _talk.stop();
      _talk.value = 0;
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _talk.dispose();
    _blink.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _talk, _blink, _sparkle]),
      builder: (context, _) {
        final idlePhase = _idle.value * math.pi * 2;
        final talkPhase = _talk.value * math.pi * 2;
        final mouth = widget.isSpeaking
            ? .22 + .78 * ((math.sin(talkPhase * 2.25) + 1) / 2)
            : 0.0;
        final gesture = widget.isSpeaking
            ? math.sin(talkPhase * .75)
            : math.sin(idlePhase * .35) * .16;
        final nod = widget.isSpeaking
            ? math.sin(talkPhase) * .024
            : math.sin(idlePhase * .45) * .008;
        final lift = math.sin(idlePhase) * 3.0;
        final breathe = 1.0 + math.sin(idlePhase) * .009;
        final blink = Curves.easeInOut.transform(_blink.value);

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.10),
                    radius: .78,
                    colors: [
                      const Color(0xFFFFE7B0).withOpacity(.34),
                      const Color(0xFFE5C788).withOpacity(.13),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AuraPainter(
                    speaking: widget.isSpeaking,
                    thinking: widget.isThinking,
                    pulse: _talk.value,
                    sparkle: _sparkle.value,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, lift),
              child: Transform.scale(
                scale: breathe,
                child: SizedBox(
                  width: 390,
                  height: 535,
                  child: CustomPaint(
                    painter: _LoloPainter(
                      mouthOpen: mouth,
                      blink: blink,
                      headTilt: nod + (widget.isThinking ? -.022 : 0),
                      gesture: gesture,
                      speaking: widget.isSpeaking,
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

class _LoloPainter extends CustomPainter {
  _LoloPainter({
    required this.mouthOpen,
    required this.blink,
    required this.headTilt,
    required this.gesture,
    required this.speaking,
  });

  final double mouthOpen;
  final double blink;
  final double headTilt;
  final double gesture;
  final bool speaking;

  Paint grad(Rect rect, List<Color> colors,
      [Alignment begin = Alignment.topLeft,
      Alignment end = Alignment.bottomRight]) {
    return Paint()
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
      ).createShader(rect);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 535;
    canvas.save();
    canvas.scale(sx, sy);

    final floor = const Rect.fromLTWH(95, 493, 205, 24);
    canvas.drawOval(
      floor,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x55302117), Color(0x18302117), Colors.transparent],
        ).createShader(floor),
    );

    _legs(canvas);
    _body(canvas);
    _arms(canvas);
    _neck(canvas);
    _head(canvas);
    _hat(canvas);
    _necklace(canvas);

    canvas.restore();
  }

  void _legs(Canvas c) {
    final pants = grad(
      const Rect.fromLTWH(132, 348, 128, 145),
      const [Color(0xFF2C4373), Color(0xFF132441)],
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(142, 348, 49, 137), const Radius.circular(18)),
      pants,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(201, 348, 49, 137), const Radius.circular(18)),
      pants,
    );
    _shoe(c, const Offset(155, 476));
    _shoe(c, const Offset(217, 476));
  }

  void _shoe(Canvas c, Offset p) {
    final path = Path()
      ..moveTo(p.dx - 18, p.dy)
      ..quadraticBezierTo(p.dx + 4, p.dy - 8, p.dx + 36, p.dy + 3)
      ..lineTo(p.dx + 34, p.dy + 16)
      ..lineTo(p.dx - 22, p.dy + 16)
      ..quadraticBezierTo(p.dx - 24, p.dy + 7, p.dx - 18, p.dy)
      ..close();
    c.drawShadow(path, Colors.black.withOpacity(.22), 5, false);
    c.drawPath(path, grad(path.getBounds(), const [Color(0xFFB7773E), Color(0xFF603313)]));
    c.drawPath(path, Paint()..color = const Color(0xFF4D2813)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _body(Canvas c) {
    final body = Path()
      ..moveTo(116, 215)
      ..quadraticBezierTo(146, 165, 188, 162)
      ..quadraticBezierTo(246, 163, 276, 215)
      ..lineTo(287, 357)
      ..quadraticBezierTo(195, 386, 104, 357)
      ..close();
    c.drawShadow(body, Colors.black.withOpacity(.17), 10, false);
    c.drawPath(
      body,
      grad(body.getBounds(), const [Color(0xFFFFFCF4), Color(0xFFF1E1C5), Color(0xFFDFC59C)]),
    );
    c.drawPath(body, Paint()..color = const Color(0xFFC6A46C)..style = PaintingStyle.stroke..strokeWidth = 2);

    final panel = RRect.fromRectAndRadius(const Rect.fromLTWH(181, 183, 32, 143), const Radius.circular(4));
    c.drawRRect(panel, Paint()..color = const Color(0xFFF8EFDF));
    c.drawRRect(panel, Paint()..color = const Color(0xFFCAAA72)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    for (final y in [207.0, 240.0, 273.0, 306.0]) {
      c.drawCircle(Offset(197, y), 4, grad(Rect.fromCircle(center: Offset(197, y), radius: 4), const [Color(0xFFFFD369), Color(0xFF9E651E)]));
    }

    final emb = Paint()..color = const Color(0xFFC8A76F).withOpacity(.72)..style = PaintingStyle.stroke..strokeWidth = 2.1..strokeCap = StrokeCap.round;
    final l = Path()..moveTo(149, 213)..cubicTo(132, 238, 157, 254, 139, 275)..cubicTo(160, 292, 140, 311, 151, 333);
    final r = Path()..moveTo(244, 213)..cubicTo(261, 238, 236, 254, 254, 275)..cubicTo(233, 292, 253, 311, 242, 333);
    c.drawPath(l, emb);
    c.drawPath(r, emb);
  }

  void _arms(Canvas c) {
    final gx = gesture * 8;
    final gy = gesture.abs() * 8;
    final left = Path()
      ..moveTo(127, 218)
      ..quadraticBezierTo(84 + gx, 253 - gy, 66 + gx, 294 - gy)
      ..lineTo(88 + gx, 306 - gy)
      ..quadraticBezierTo(120, 285, 151, 248)
      ..close();
    c.drawShadow(left, Colors.black.withOpacity(.13), 5, false);
    c.drawPath(left, grad(left.getBounds(), const [Color(0xFFFFFCF4), Color(0xFFE7D3B0)]));
    c.drawPath(left, Paint()..color = const Color(0xFFC6A46C)..style = PaintingStyle.stroke..strokeWidth = 1.6);
    _openHand(c, Offset(71 + gx, 297 - gy), gesture);

    final right = Path()
      ..moveTo(267, 220)
      ..quadraticBezierTo(309, 249, 302, 307)
      ..lineTo(278, 300)
      ..quadraticBezierTo(258, 265, 245, 236)
      ..close();
    c.drawShadow(right, Colors.black.withOpacity(.12), 5, false);
    c.drawPath(right, grad(right.getBounds(), const [Color(0xFFFFFBF0), Color(0xFFE5CFAB)]));
    c.drawPath(right, Paint()..color = const Color(0xFFC6A46C)..style = PaintingStyle.stroke..strokeWidth = 1.6);
    final hand = Rect.fromCenter(center: Offset(285, 302 + math.sin(gesture) * 3), width: 37, height: 28);
    c.drawOval(hand, grad(hand, const [Color(0xFFF6B47A), Color(0xFFD77742)]));
    c.drawOval(hand, Paint()..color = const Color(0xFFB65F35)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _openHand(Canvas c, Offset p, double g) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(-.27 + g * .08);
    final h = Path()
      ..moveTo(0, 0)
      ..cubicTo(-18, -8, -37, -19, -42, -8)
      ..cubicTo(-44, -2, -31, 7, -21, 10)
      ..cubicTo(-33, 9, -39, 16, -33, 23)
      ..cubicTo(-26, 31, -9, 21, 2, 15)
      ..cubicTo(10, 10, 10, 4, 0, 0)
      ..close();
    c.drawShadow(h, Colors.black.withOpacity(.18), 4, false);
    c.drawPath(h, grad(h.getBounds(), const [Color(0xFFF7BA83), Color(0xFFD57440)]));
    c.drawPath(h, Paint()..color = const Color(0xFFB65F35)..style = PaintingStyle.stroke..strokeWidth = 1.6);
    c.restore();
  }

  void _neck(Canvas c) {
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(179, 145, 36, 43), const Radius.circular(17));
    c.drawRRect(r, grad(r.outerRect, const [Color(0xFFF7B987), Color(0xFFD87340)], Alignment.topCenter, Alignment.bottomCenter));
  }

  void _head(Canvas c) {
    c.save();
    c.translate(197, 125);
    c.rotate(headTilt);
    c.translate(-197, -125);

    final head = const Rect.fromLTWH(132, 59, 130, 145);
    c.drawShadow(Path()..addOval(head), Colors.black.withOpacity(.18), 8, false);
    c.drawOval(head, grad(head, const [Color(0xFFFFC799), Color(0xFFF09A61), Color(0xFFD36D3F)]));
    c.drawOval(head, Paint()..color = const Color(0xFFB55C35)..style = PaintingStyle.stroke..strokeWidth = 2);

    _ear(c, const Offset(132, 129));
    _ear(c, const Offset(262, 129));
    _hair(c);
    _brows(c);
    _eyes(c);
    _nose(c);
    _mustache(c);
    _mouth(c);
    c.restore();
  }

  void _ear(Canvas c, Offset p) {
    final r = Rect.fromCenter(center: p, width: 23, height: 37);
    c.drawOval(r, grad(r, const [Color(0xFFF5AE78), Color(0xFFD36C3D)]));
    c.drawOval(r, Paint()..color = const Color(0xFFB55C35)..style = PaintingStyle.stroke..strokeWidth = 1.4);
  }

  void _hair(Canvas c) {
    final p = Path()..moveTo(143, 91)..quadraticBezierTo(153, 49, 195, 48)..quadraticBezierTo(239, 50, 252, 91)..quadraticBezierTo(228, 70, 198, 69)..quadraticBezierTo(165, 65, 143, 91)..close();
    c.drawPath(p, grad(p.getBounds(), const [Colors.white, Color(0xFFBFC2C6)]));
    c.drawPath(p, Paint()..color = const Color(0xFF85888D)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    c.drawOval(const Rect.fromLTWH(138, 78, 19, 64), Paint()..color = const Color(0xFFD6D8DA));
    c.drawOval(const Rect.fromLTWH(238, 78, 19, 64), Paint()..color = const Color(0xFFD6D8DA));
  }

  void _brows(Canvas c) {
    final p = Paint()..color = const Color(0xFF777A7D)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    c.drawArc(const Rect.fromLTWH(153, 92, 38, 18), math.pi * 1.08, math.pi * .72, false, p);
    c.drawArc(const Rect.fromLTWH(204, 92, 38, 18), math.pi * 1.20, math.pi * .72, false, p);
  }

  void _eyes(Canvas c) {
    final open = 1 - blink;
    _eye(c, const Offset(174, 118), open);
    _eye(c, const Offset(221, 118), open);
  }

  void _eye(Canvas c, Offset p, double open) {
    if (open < .1) {
      c.drawArc(Rect.fromCenter(center: p, width: 26, height: 8), 0, math.pi, false, Paint()..color = const Color(0xFF8D5034)..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round);
      return;
    }
    final r = Rect.fromCenter(center: p, width: 27, height: 10 + open * 8);
    c.drawOval(r, Paint()..color = Colors.white);
    c.drawOval(r, Paint()..color = const Color(0xFFAA6845)..style = PaintingStyle.stroke..strokeWidth = 1.1);
    c.drawCircle(p, 6, Paint()..color = const Color(0xFF6B361B));
    c.drawCircle(p, 3.4, Paint()..color = const Color(0xFF23160F));
    c.drawCircle(p.translate(-1.6, -1.7), 1.4, Paint()..color = Colors.white);
  }

  void _nose(Canvas c) {
    final p = Path()..moveTo(197, 118)..quadraticBezierTo(187, 140, 197, 146)..quadraticBezierTo(208, 142, 206, 133);
    c.drawPath(p, Paint()..color = const Color(0xFFB9603A).withOpacity(.72)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  void _mustache(Canvas c) {
    final l = Path()..moveTo(195, 151)..quadraticBezierTo(181, 139, 157, 149)..quadraticBezierTo(172, 165, 195, 157)..close();
    final r = Path()..moveTo(199, 151)..quadraticBezierTo(213, 139, 237, 149)..quadraticBezierTo(222, 165, 199, 157)..close();
    final p = grad(const Rect.fromLTWH(154, 138, 86, 28), const [Colors.white, Color(0xFFD0D2D4)]);
    c.drawPath(l, p);
    c.drawPath(r, p);
  }

  void _mouth(Canvas c) {
    const y = 169.0;
    if (!speaking) {
      final s = Path()..moveTo(183, y)..quadraticBezierTo(197, y + 10, 211, y);
      c.drawPath(s, Paint()..color = const Color(0xFF994A3A)..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round);
      return;
    }
    final o = mouthOpen.clamp(.15, 1.0);
    final r = Rect.fromCenter(center: const Offset(197, y + 1), width: 25 + 9 * o, height: 8 + 15 * o);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), Paint()..color = const Color(0xFF5B201A));
    if (o < .62) {
      final t = Rect.fromCenter(center: Offset(197, y - r.height * .10), width: r.width * .76, height: math.max(2.5, r.height * .24));
      c.drawRRect(RRect.fromRectAndRadius(t, const Radius.circular(3)), Paint()..color = Colors.white);
    } else {
      final t = Rect.fromCenter(center: Offset(197, y + r.height * .25), width: r.width * .45, height: math.max(2.5, r.height * .22));
      c.drawRRect(RRect.fromRectAndRadius(t, const Radius.circular(3)), Paint()..color = const Color(0xFFE07276));
    }
  }

  void _hat(Canvas c) {
    c.save();
    c.translate(197, 69);
    c.rotate(headTilt * .55);
    c.translate(-197, -69);
    final brim = Path()..moveTo(105, 77)..quadraticBezierTo(197, 8, 289, 77)..quadraticBezierTo(262, 98, 197, 99)..quadraticBezierTo(132, 98, 105, 77)..close();
    c.drawShadow(brim, Colors.black.withOpacity(.22), 6, false);
    c.drawPath(brim, grad(brim.getBounds(), const [Color(0xFFF4D184), Color(0xFFB97D38)], Alignment.topCenter, Alignment.bottomCenter));
    c.drawPath(brim, Paint()..color = const Color(0xFF895725)..style = PaintingStyle.stroke..strokeWidth = 2);
    final crown = Path()..moveTo(153, 76)..quadraticBezierTo(197, 0, 241, 76)..close();
    c.drawPath(crown, grad(crown.getBounds(), const [Color(0xFFF7DB94), Color(0xFFBC813C)]));
    c.drawPath(crown, Paint()..color = const Color(0xFF895725)..style = PaintingStyle.stroke..strokeWidth = 2);
    final weave = Paint()..color = const Color(0xFF895725).withOpacity(.28)..strokeWidth = 1;
    for (var x = 164.0; x <= 222; x += 13) {
      c.drawLine(Offset(x, 67), Offset(x + 22, 37), weave);
      c.drawLine(Offset(x, 37), Offset(x + 22, 67), weave);
    }
    c.restore();
  }

  void _necklace(Canvas c) {
    final p = Path()..moveTo(157, 185)..quadraticBezierTo(197, 211, 237, 185);
    c.drawPath(p, Paint()..color = const Color(0xFF6A3C1B)..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round);
    for (var i = 0; i <= 8; i++) {
      final t = i / 8;
      final x = 158 + 78 * t;
      final y = 185 + math.sin(t * math.pi) * 21;
      c.drawCircle(Offset(x, y), 3.5, grad(Rect.fromCircle(center: Offset(x, y), radius: 3.5), const [Color(0xFFD68B35), Color(0xFF6B3A19)]));
    }
  }

  @override
  bool shouldRepaint(covariant _LoloPainter old) {
    return old.mouthOpen != mouthOpen ||
        old.blink != blink ||
        old.headTilt != headTilt ||
        old.gesture != gesture ||
        old.speaking != speaking;
  }
}

class _AuraPainter extends CustomPainter {
  _AuraPainter({
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
    final center = Offset(size.width / 2, size.height * .47);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x28B88A44);
    canvas.drawCircle(center, size.shortestSide * .22, ring);
    ring.color = const Color(0x14B88A44);
    canvas.drawCircle(center, size.shortestSide * .30, ring);

    if (speaking) {
      final wave = .5 + .5 * math.sin(pulse * math.pi * 2);
      final p = Paint()..color = const Color(0xFFB67C2E).withOpacity(.34 + wave * .22)..strokeWidth = 4..strokeCap = StrokeCap.round;
      final y = size.height * .58;
      final lx = size.width * .14;
      final rx = size.width * .86;
      for (var i = 0; i < 4; i++) {
        final h = 10 + i * 5 + wave * 8;
        canvas.drawLine(Offset(lx - i * 10, y - h / 2), Offset(lx - i * 10, y + h / 2), p);
        canvas.drawLine(Offset(rx + i * 10, y - h / 2), Offset(rx + i * 10, y + h / 2), p);
      }
    }

    if (thinking) {
      final p = Paint()..color = const Color(0xFFD49A46).withOpacity(.80);
      final pts = [
        Offset(size.width * .20, size.height * .19),
        Offset(size.width * .76, size.height * .16),
        Offset(size.width * .82, size.height * .30),
      ];
      for (var i = 0; i < pts.length; i++) {
        final r = 4.0 + (((sparkle + i * .22) % 1) * 3.2);
        final c = pts[i];
        final s = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * .3, c.dy - r * .3)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx + r * .3, c.dy + r * .3)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r * .3, c.dy + r * .3)
          ..lineTo(c.dx - r, c.dy)
          ..lineTo(c.dx - r * .3, c.dy - r * .3)
          ..close();
        canvas.drawPath(s, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) {
    return old.speaking != speaking ||
        old.thinking != thinking ||
        old.pulse != pulse ||
        old.sparkle != sparkle;
  }
}
