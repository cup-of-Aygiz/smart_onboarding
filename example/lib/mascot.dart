import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:smart_onboarding/smart_onboarding.dart';

/// Monkey mascot for onboarding.
///
/// - [Mascot.pointer]: used as the "arrow" of a highlight. The monkey sits
///   between the content and the target and turns its arm towards the target.
/// - [Mascot.dancing]: content for steps without highlights.
abstract final class Mascot {
  static const _body = 'assets/mascot/monkey_body.svg';
  static const _arm = 'assets/mascot/monkey_arm.svg';
  static const _dance = 'assets/mascot/monkey_dance.json';

  /// Distance between content and target that leaves room for the monkey.
  static const gap = 175.0;

  static const OnboardingArrow pointer = OnboardingArrow.custom(_buildPointer);

  /// Tooltip with a dancing monkey on top.
  static OnboardingContent dancing({String? title, required String text}) =>
      OnboardingContent(
        placement: const ContentPlacement.aligned(Alignment.center),
        builder: (context, info) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(_dance, width: 190, height: 166),
            OnboardingTooltip(title: title, text: text),
          ],
        ),
      );

  /// Tooltip next to the target, pointed at by the monkey.
  static OnboardingContent pointing({
    String? title,
    required String text,
    bool showNext = true,
    ContentPlacement placement = const ContentPlacement.auto(),
  }) => OnboardingContent.tooltip(
    title: title,
    text: text,
    showNext: showNext,
    placement: placement,
    gap: gap,
    arrow: pointer,
  );

  static Widget _buildPointer(
    BuildContext context,
    ArrowGeometry geometry,
    Animation<double> progress,
  ) => _MascotPointer(geometry: geometry, progress: progress);
}

class _MascotPointer extends StatelessWidget {
  const _MascotPointer({required this.geometry, required this.progress});

  final ArrowGeometry geometry;
  final Animation<double> progress;

  // Artwork coordinates (see monkey_body.svg / monkey_arm.svg).
  static const _bodySize = Size(400, 420);
  static const _shoulder = Offset(258, 218);
  static const _armSize = Size(200, 70);
  static const _armPivot = Offset(12, 35);

  static const double width = 136;

  @override
  Widget build(BuildContext context) {
    final s = width / _bodySize.width;
    final size = _bodySize * s;

    // Sit on the line from the content to the target, next to the content.
    final travel = geometry.end - geometry.start;
    final dir = travel.distance == 0
        ? const Offset(0, 1)
        : travel / travel.distance;
    var center = geometry.start + dir * (size.longestSide * 0.55);
    // On a near-vertical line the arm would point straight down/up through
    // the body; step aside (towards the screen center) to point diagonally.
    if (dir.dx.abs() < 0.5) {
      final screenCenter = MediaQuery.sizeOf(context).width / 2;
      final side = geometry.end.dx > screenCenter ? -1.0 : 1.0;
      center += Offset(side * size.width * 0.45, 0);
    }
    final topLeft = center - Offset(size.width / 2, size.height / 2);

    // Mirror the monkey when the target is on its left, so the pointing arm
    // is always on the target's side.
    final flip = geometry.end.dx < center.dx;
    var target = geometry.end - topLeft;
    if (flip) target = Offset(size.width - target.dx, target.dy);
    final shoulder = _shoulder * s;
    final pointAngle = math.atan2(
      target.dy - shoulder.dy,
      target.dx - shoulder.dx,
    );
    // Hanging down along the body before it raises the arm.
    const restAngle = math.pi * 0.42;

    final armSize = _armSize * s * 1.35;
    final pivot = _armPivot * s * 1.35;

    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value.clamp(0.0, 1.0);
        final raise = Curves.easeOutBack.transform(
          ((t - 0.35) / 0.65).clamp(0.0, 1.0),
        );
        final appear = Curves.easeOut.transform((t / 0.35).clamp(0.0, 1.0));
        final angle = restAngle + (pointAngle - restAngle) * raise;

        final arm = Positioned(
          left: shoulder.dx - pivot.dx,
          top: shoulder.dy - pivot.dy,
          width: armSize.width,
          height: armSize.height,
          child: Transform.rotate(
            angle: angle,
            // Rotate around the shoulder, not the arm center.
            origin: Offset(
              pivot.dx - armSize.width / 2,
              pivot.dy - armSize.height / 2,
            ),
            child: SvgPicture.asset(Mascot._arm),
          ),
        );

        return Stack(
          children: [
            Positioned(
              left: topLeft.dx,
              top: topLeft.dy + (1 - appear) * 20,
              width: size.width,
              height: size.height,
              child: Opacity(
                opacity: appear,
                child: Transform.flip(
                  flipX: flip,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // An arm pointing down goes over the belly; otherwise
                      // it grows from behind the body.
                      if (!_armInFront(angle)) arm,
                      Positioned.fill(child: SvgPicture.asset(Mascot._body)),
                      if (_armInFront(angle)) arm,
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

  static bool _armInFront(double angle) =>
      angle > math.pi * 0.2 && angle < math.pi * 0.8;
}
