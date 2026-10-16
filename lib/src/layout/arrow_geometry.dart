import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Quadratic bezier from the content to a target.
@immutable
class ArrowGeometry {
  const ArrowGeometry({
    required this.start,
    required this.control,
    required this.end,
    required this.target,
  });

  final Offset start;
  final Offset control;

  /// Tip of the arrow, already moved away from the cut-out by the tip gap.
  final Offset end;

  /// Cut-out bounds the arrow points at.
  final Rect target;

  Offset pointAt(double t) {
    final u = 1 - t;
    return start * (u * u) + control * (2 * u * t) + end * (t * t);
  }

  /// Unit direction of travel at [t].
  Offset directionAt(double t) {
    final d = (control - start) * (2 * (1 - t)) + (end - control) * (2 * t);
    final len = d.distance;
    return len == 0 ? const Offset(0, 1) : d / len;
  }

  Path toPath() => Path()
    ..moveTo(start.dx, start.dy)
    ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

  double get length => (end - start).distance;
}

/// Computes an arrow from [from] (content bounds) to [target].
///
/// Returns null when the two rects touch or overlap, i.e. there is no room
/// to draw anything meaningful.
ArrowGeometry? computeArrow({
  required Rect from,
  required Rect target,
  required double curvature,
  required double tipGap,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final goal = target.inflate(tipGap);
  final start = _closestOnBorder(from, goal.center, inset: 12);
  final end = _closestOnBorder(goal, start);
  final delta = end - start;
  final length = delta.distance;
  if (length < 16 || from.inflate(2).overlaps(goal)) return null;

  final normal = Offset(-delta.dy, delta.dx) / length;
  final sign = textDirection == TextDirection.rtl ? -1.0 : 1.0;
  final mid = (start + end) / 2;
  final control = mid + normal * (length * curvature * sign);
  return ArrowGeometry(
    start: start,
    control: control,
    end: end,
    target: target,
  );
}

/// Arrow for steps without content: starts [length] away from the target on
/// the side with the most room within [bounds].
ArrowGeometry? computeStandaloneArrow({
  required Rect target,
  required Rect bounds,
  required double length,
  required double curvature,
  required double tipGap,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final spaces = <Offset, double>{
    const Offset(0, 1): bounds.bottom - target.bottom,
    const Offset(0, -1): target.top - bounds.top,
    const Offset(1, 0): bounds.right - target.right,
    const Offset(-1, 0): target.left - bounds.left,
  };
  final dir = spaces.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final edge = Offset(
    target.center.dx + dir.dx * target.width / 2,
    target.center.dy + dir.dy * target.height / 2,
  );
  final available = math.max(spaces[dir]! - tipGap, 0.0);
  final reach = math.min(length, available) + tipGap;
  if (reach - tipGap < 16) return null;
  // Slight sideways offset makes the curve visible.
  final side = Offset(-dir.dy, dir.dx) * (reach * 0.35);
  final origin = edge + dir * reach + side;
  final start = Offset(
    origin.dx.clamp(bounds.left, bounds.right),
    origin.dy.clamp(bounds.top, bounds.bottom),
  );
  return computeArrow(
    from: Rect.fromCenter(center: start, width: 0, height: 0),
    target: target,
    curvature: curvature,
    tipGap: tipGap,
    textDirection: textDirection,
  );
}

Offset _closestOnBorder(Rect rect, Offset point, {double inset = 0}) {
  final inner = rect.deflate(math.min(inset, rect.shortestSide / 2));
  var x = point.dx.clamp(inner.left, inner.right);
  var y = point.dy.clamp(inner.top, inner.bottom);
  final dx = _distToRange(point.dx, rect.left, rect.right);
  final dy = _distToRange(point.dy, rect.top, rect.bottom);
  if (dx == 0 && dy == 0) return Offset(x, y);
  if (dy >= dx) {
    y = point.dy < rect.top ? rect.top : rect.bottom;
  } else {
    x = point.dx < rect.left ? rect.left : rect.right;
  }
  return Offset(x, y);
}

double _distToRange(double v, double min, double max) =>
    v < min ? min - v : (v > max ? v - max : 0);
