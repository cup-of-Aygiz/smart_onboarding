import 'package:flutter/widgets.dart';

import '../controller/onboarding_controller.dart';
import 'onboarding_step.dart';

/// State of the step being shown, available to content builders and via
/// [OnboardingStepInfo.of] anywhere inside the content.
@immutable
class OnboardingStepInfo {
  const OnboardingStepInfo({
    required this.controller,
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.groupIndex,
    required this.groupCount,
    required this.timer,
    required this.progressPlacement,
  });

  final OnboardingController controller;
  final OnboardingStep step;
  final int stepIndex;
  final int stepCount;
  final int groupIndex;
  final int groupCount;

  /// 0→1 while the auto-advance timer runs, null when the step has no timer.
  final Animation<double>? timer;
  final ProgressPlacement progressPlacement;

  bool get isLastStep => stepIndex == stepCount - 1;
  bool get isLast => isLastStep && groupIndex == groupCount - 1;

  void next() => controller.next();
  void skip() => controller.skip();

  static OnboardingStepInfo? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingStepScope>()?.info;

  static OnboardingStepInfo of(BuildContext context) {
    final info = maybeOf(context);
    assert(info != null, 'No OnboardingStepInfo above this context.');
    return info!;
  }
}

class OnboardingStepScope extends InheritedWidget {
  const OnboardingStepScope({
    super.key,
    required this.info,
    required super.child,
  });

  final OnboardingStepInfo info;

  @override
  bool updateShouldNotify(OnboardingStepScope oldWidget) =>
      info.step != oldWidget.info.step ||
      info.stepIndex != oldWidget.info.stepIndex ||
      info.groupIndex != oldWidget.info.groupIndex ||
      info.timer != oldWidget.info.timer;
}
