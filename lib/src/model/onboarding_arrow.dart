import 'package:flutter/widgets.dart';

import '../layout/arrow_geometry.dart';

/// How the pointer from content to a highlighted widget looks.
@immutable
sealed class OnboardingArrow {
  const OnboardingArrow();

  /// Hand-drawn style bezier arrow that animates as if being drawn.
  const factory OnboardingArrow.curved({
    Color? color,
    double strokeWidth,
    double curvature,
    double headSize,
    double tipGap,
    bool dashed,
  }) = CurvedArrow;

  /// Places [child] (an image, icon, Lottie...) at the arrow tip, rotated so
  /// that its "up" points at the target when [rotate] is true. The child
  /// slides in from the content towards the target.
  const factory OnboardingArrow.widget({
    required Widget child,
    Size size,
    bool rotate,
    double tipGap,
  }) = WidgetArrow;

  /// Full control: build any widget from the computed geometry and the
  /// 0→1 [progress] animation. The returned widget is laid out full screen.
  const factory OnboardingArrow.custom(
    Widget Function(
      BuildContext context,
      ArrowGeometry geometry,
      Animation<double> progress,
    )
    builder,
  ) = CustomArrow;

  /// No arrow.
  static const OnboardingArrow none = NoArrow();

  /// Distance kept between the arrow tip and the cut-out.
  double get tipGap => 6;
}

final class CurvedArrow extends OnboardingArrow {
  const CurvedArrow({
    this.color,
    this.strokeWidth = 2.5,
    this.curvature = 0.3,
    this.headSize = 11,
    this.tipGap = 6,
    this.dashed = false,
  });

  /// Defaults to white.
  final Color? color;
  final double strokeWidth;

  /// Bend relative to the arrow length. 0 draws a straight line; negative
  /// values bend to the other side.
  final double curvature;
  final double headSize;
  @override
  final double tipGap;
  final bool dashed;
}

final class WidgetArrow extends OnboardingArrow {
  const WidgetArrow({
    required this.child,
    this.size = const Size(40, 40),
    this.rotate = true,
    this.tipGap = 4,
  });

  final Widget child;
  final Size size;
  final bool rotate;
  @override
  final double tipGap;
}

final class CustomArrow extends OnboardingArrow {
  const CustomArrow(this.builder);

  final Widget Function(
    BuildContext context,
    ArrowGeometry geometry,
    Animation<double> progress,
  )
  builder;
}

final class NoArrow extends OnboardingArrow {
  const NoArrow();
}
