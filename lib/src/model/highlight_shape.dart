import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Shape of the cut-out around a highlighted widget.
@immutable
sealed class HighlightShape {
  const HighlightShape();

  /// Rounded rectangle; `radius: 0` gives a sharp rectangle.
  const factory HighlightShape.rect({double radius}) = RectHighlightShape;

  /// Circle around the target: diameter equals its longest side, so square
  /// targets (icons, FABs) get a snug circle. Corners of wide targets may
  /// poke out; use [HighlightShape.stadium] for those.
  const factory HighlightShape.circle() = CircleHighlightShape;

  /// Pill shape: radius equals half of the shortest side.
  const factory HighlightShape.stadium() = StadiumHighlightShape;

  /// Any path. Custom shapes cross-fade instead of morphing.
  const factory HighlightShape.custom(Path Function(Rect rect) builder) =
      CustomHighlightShape;

  /// The cut-out as a rounded rect, or null when it is not representable as
  /// one. Rounded rects can be interpolated smoothly between steps.
  RRect? toRRect(Rect rect);

  Path toPath(Rect rect) {
    final rrect = toRRect(rect);
    return rrect != null ? (Path()..addRRect(rrect)) : Path();
  }
}

final class RectHighlightShape extends HighlightShape {
  const RectHighlightShape({this.radius = 12});

  final double radius;

  @override
  RRect toRRect(Rect rect) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));
}

final class CircleHighlightShape extends HighlightShape {
  const CircleHighlightShape();

  @override
  RRect toRRect(Rect rect) {
    final r = math.max(rect.width, rect.height) / 2;
    return RRect.fromRectAndRadius(
      Rect.fromCircle(center: rect.center, radius: r),
      Radius.circular(r),
    );
  }
}

final class StadiumHighlightShape extends HighlightShape {
  const StadiumHighlightShape();

  @override
  RRect toRRect(Rect rect) =>
      RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2));
}

final class CustomHighlightShape extends HighlightShape {
  const CustomHighlightShape(this.builder);

  final Path Function(Rect rect) builder;

  @override
  RRect? toRRect(Rect rect) => null;

  @override
  Path toPath(Rect rect) => builder(rect);
}
