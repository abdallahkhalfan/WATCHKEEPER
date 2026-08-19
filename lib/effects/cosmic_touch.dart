import 'dart:math';

import 'package:flutter/material.dart';

class CosmicTouch extends StatefulWidget {
  const CosmicTouch({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<CosmicTouch> createState() => _CosmicTouchState();
}

class _Spark {
  _Spark(this.position, this.velocity, this.life);

  Offset position;
  Offset velocity;
  double life;
}

class _CosmicTouchState extends State<CosmicTouch>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  final List<_Spark> sparks = [];
  final Random random = Random();

  Offset? lastPosition;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(_tick)
      ..repeat();
  }

  void _tick() {
    for (final spark in sparks) {
      spark.position += spark.velocity;
      spark.velocity = Offset(
        spark.velocity.dx * .96,
        spark.velocity.dy * .96 + .05,
      );
      spark.life -= .035;
    }

    sparks.removeWhere((spark) => spark.life <= 0);
  }

  void _burst(
    Offset position, {
    int count = 12,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * pi * 2;
      final speed = 1 + random.nextDouble() * 4;

      sparks.add(
        _Spark(
          position,
          Offset(
            cos(angle) * speed,
            sin(angle) * speed,
          ),
          1,
        ),
      );
    }
  }

  void _trail(Offset position) {
    if (lastPosition == null ||
        (position - lastPosition!).distance > 8) {
      final velocity = lastPosition == null
          ? Offset.zero
          : (lastPosition! - position) * .22;

      sparks.add(
        _Spark(
          position,
          velocity,
          1,
        ),
      );

      lastPosition = position;
    }
  }

  @override
  void dispose() {
    controller.removeListener(_tick);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _burst(event.localPosition);
        lastPosition = event.localPosition;
      },
      onPointerMove: (event) {
        _trail(event.localPosition);
      },
      onPointerUp: (_) {
        lastPosition = null;
      },
      onPointerCancel: (_) {
        lastPosition = null;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            child: CustomPaint(
              painter: _CosmicPainter(
                sparks: sparks,
                repaint: controller,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmicPainter extends CustomPainter {
  _CosmicPainter({
    required this.sparks,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final spark in sparks) {
      final glow = Paint()
        ..color = const Color(0xFFFF6A2A)
            .withValues(alpha: spark.life * .18)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          9,
        );

      canvas.drawCircle(
        spark.position,
        8 * spark.life,
        glow,
      );

      final core = Paint()
        ..color = Color.lerp(
          const Color(0xFFFF3D00),
          const Color(0xFFFFF59D),
          1 - spark.life,
        )!
            .withValues(alpha: spark.life);

      canvas.drawCircle(
        spark.position,
        2.2 + 3 * spark.life,
        core,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicPainter oldDelegate) {
    return true;
  }
}