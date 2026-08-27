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

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _mouth = AnimationController(vsync: this, duration: const Duration(milliseconds: 170));
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _scheduleBlink();
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future<void>.delayed(Duration(seconds: 3 + math.Random().nextInt(4)));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _mouth, _blink]),
      builder: (context, _) {
        final breathe = 1 + (_idle.value * 0.012);
        final sway = math.sin(_idle.value * math.pi * 2) * 0.008;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE8C886).withOpacity(.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: widget.isThinking ? -0.025 : sway,
              child: Transform.scale(
                scale: widget.isThinking ? .985 : breathe,
                child: SvgPicture.asset(
                  'assets/images/lakbay_lolo.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.0, -0.42),
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: widget.isSpeaking ? .32 + (.24 * _mouth.value) : 0,
                  duration: const Duration(milliseconds: 80),
                  child: Transform.scale(
                    scaleY: .45 + (.9 * _mouth.value),
                    child: Container(
                      width: 34,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4D1E14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.0, -0.56),
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
        );
      },
    );
  }
}
