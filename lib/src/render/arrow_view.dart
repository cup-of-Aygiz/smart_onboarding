import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/arrow_geometry.dart';
import '../model/onboarding_arrow.dart';

/// Full-size layer that renders [arrow] along [geometry] as [progress] goes
/// from 0 to 1.
class ArrowView extends StatelessWidget {
  const ArrowView({
    super.key,
    required this.arrow,
    required this.geometry,
    required this.progress,
  });

  final OnboardingArrow arrow;
  final ArrowGeometry geometry;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final arrow = this.arrow;
    final Widget child = switch (arrow) {
      NoArrow() => const SizedBox.shrink(),
      CurvedArrow() => CustomPaint(
        size: Size.infinite,
        painter: _CurvedArrowPainter(arrow, geometry, progress),
      ),
      WidgetArrow() => AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(progress.value);
          final dir = geometry.directionAt(1);
          final tip = Offset.lerp(geometry.start, geometry.end, 0.6 + 0.4 * t)!;
          // The tip sits on the arrow end; the widget extends backwards.
          final center = tip - dir * (arrow.size.height / 2);
          return Stack(
            children: [
              Positioned(
                left: center.dx - arrow.size.width / 2,
                top: center.dy - arrow.size.height / 2,
                width: arrow.size.width,
                height: arrow.size.height,
                child: Opacity(
                  opacity: t,
                  child: arrow.rotate
                      ? Transform.rotate(
                          // Child's "up" (0,-1) is rotated to the direction.
                          angle: math.atan2(dir.dy, dir.dx) + math.pi / 2,
                          child: child,
                        )
                      : child,
                ),
              ),
            ],
          );
        },
        child: arrow.child,
      ),
      CustomArrow(:final builder) => builder(context, geometry, progress),
    };
    return IgnorePointer(child: child);
  }
}

class _CurvedArrowPainter extends CustomPainter {
  _CurvedArrowPainter(this.arrow, this.geometry, this.progress)
    : super(repaint: progress);

  final CurvedArrow arrow;
  final ArrowGeometry geometry;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(progress.value.clamp(0.0, 1.0));
    if (t <= 0) return;
    final paint = Paint()
      ..color = arrow.color ?? const Color(0xFFFFFFFF)
      ..strokeWidth = arrow.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final metric = geometry.toPath().computeMetrics().firstOrNull;
    if (metric == null) return;
    final drawn = metric.length * t;
    if (arrow.dashed) {
      const dash = 8.0, gapLen = 6.0;
      for (var d = 0.0; d < drawn; d += dash + gapLen) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, drawn)),
          paint,
        );
      }
    } else {
      canvas.drawPath(metric.extractPath(0, drawn), paint);
    }

    final tangent = metric.getTangentForOffset(drawn);
    if (tangent == null) return;
    final dir = tangent.vector;
    final tip = tangent.position;
    final head = arrow.headSize * math.min(1, t * 3);
    final back = tip - dir * head;
    final normal = Offset(-dir.dy, dir.dx) * (head * 0.6);
    canvas.drawPath(
      Path()
        ..moveTo(back.dx + normal.dx, back.dy + normal.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(back.dx - normal.dx, back.dy - normal.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CurvedArrowPainter old) =>
      old.geometry.start != geometry.start ||
      old.geometry.end != geometry.end ||
      old.geometry.control != geometry.control ||
      old.arrow != arrow;
}
