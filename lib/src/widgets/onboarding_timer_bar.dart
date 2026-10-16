import 'package:flutter/widgets.dart';

import '../model/step_info.dart';

/// Countdown bar for timed steps.
///
/// Without [animation] it reads the timer of the surrounding step, so it can
/// be dropped into any custom content; it renders nothing for steps without
/// a timer.
class OnboardingTimerBar extends StatelessWidget {
  const OnboardingTimerBar({
    super.key,
    this.animation,
    this.color = const Color(0xFF2962FF),
    this.backgroundColor,
    this.height = 4,
    this.radius = 2,
  });

  final Animation<double>? animation;
  final Color color;
  final Color? backgroundColor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final animation =
        this.animation ?? OnboardingStepInfo.maybeOf(context)?.timer;
    if (animation == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: backgroundColor ?? color.withValues(alpha: 0.2),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              // Shrinks as time runs out.
              widthFactor: (1 - animation.value).clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
