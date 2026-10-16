import 'dart:async';

import 'package:flutter/widgets.dart';

import 'onboarding_content.dart';
import 'onboarding_highlight.dart';

/// Which taps move the onboarding forward. `controller.next()` and buttons in
/// the content always work regardless of this setting.
enum TapToAdvance {
  /// Only `controller.next()` / content buttons / the timer.
  none,

  /// Tap inside a cut-out. If the highlight is interactive the real widget
  /// receives the tap too.
  target,

  /// Tap anywhere except the cut-outs (including the content).
  outside,

  /// Any tap.
  anywhere,
}

/// Where the countdown bar of a timed step is drawn.
enum ProgressPlacement {
  none,

  /// Inside the content; `OnboardingTooltip` and `OnboardingTimerBar` show it.
  content,

  /// Thin bar along the top of the safe area.
  top,

  /// Thin bar along the bottom of the safe area.
  bottom,
}

/// What happens when a target cannot be found within `targetTimeout`.
enum MissingTargetBehavior {
  /// Skip the whole step.
  skip,

  /// Show the step with whatever targets were found; with none found the
  /// content is centered.
  showAvailable,
}

/// When a step or group moves on.
@immutable
class StepAdvance {
  const StepAdvance({
    this.duration,
    this.tap = TapToAdvance.target,
    this.progress = ProgressPlacement.content,
  });

  /// Auto-advance after [duration]; taps still work unless [tap] is none.
  const StepAdvance.timer(
    Duration this.duration, {
    this.tap = TapToAdvance.anywhere,
    this.progress = ProgressPlacement.content,
  });

  /// No timer, advance on [tap].
  const StepAdvance.tap([this.tap = TapToAdvance.anywhere])
    : duration = null,
      progress = ProgressPlacement.none;

  /// Only `controller.next()` or a button inside the content.
  const StepAdvance.manual()
    : duration = null,
      tap = TapToAdvance.none,
      progress = ProgressPlacement.none;

  /// Null disables the timer.
  final Duration? duration;
  final TapToAdvance tap;
  final ProgressPlacement progress;
}

/// Highlights shown together. A step consists of one or more groups shown
/// one after another.
@immutable
class HighlightGroup {
  const HighlightGroup({
    this.highlights = const [],
    this.content,
    this.advance,
  });

  final List<OnboardingHighlight> highlights;

  /// Overrides the step content for this group.
  final OnboardingContent? content;

  /// Overrides the step advance rule for this group.
  final StepAdvance? advance;
}

typedef StepCondition = FutureOr<bool> Function();

/// A single onboarding step.
@immutable
class OnboardingStep {
  /// Step that highlights [highlights] at the same time.
  OnboardingStep({
    required this.id,
    List<OnboardingHighlight> highlights = const [],
    this.content,
    this.advance = const StepAdvance(),
    this.condition,
    this.onBeforeShow,
    this.missingTarget = MissingTargetBehavior.skip,
    this.targetTimeout = const Duration(seconds: 10),
    this.blockOutside,
    this.showSkip,
    this.overlayColor,
    this.blurSigma,
  }) : groups = [HighlightGroup(highlights: highlights)];

  /// Step that walks through [groups] one by one (each group may highlight
  /// several widgets at once). `controller.next()` moves to the next group.
  const OnboardingStep.sequence({
    required this.id,
    required this.groups,
    this.content,
    this.advance = const StepAdvance(),
    this.condition,
    this.onBeforeShow,
    this.missingTarget = MissingTargetBehavior.skip,
    this.targetTimeout = const Duration(seconds: 10),
    this.blockOutside,
    this.showSkip,
    this.overlayColor,
    this.blurSigma,
  });

  final String id;
  final List<HighlightGroup> groups;

  /// Content for groups that do not define their own. Null shows only the
  /// cut-outs (arrows still need an explicit `OnboardingHighlight.arrow`).
  final OnboardingContent? content;
  final StepAdvance advance;

  /// Evaluated right before the step; false skips it.
  final StepCondition? condition;

  /// Awaited before the step starts looking for its targets. Use it to
  /// navigate, open a tab, load data and so on.
  final Future<void> Function()? onBeforeShow;

  final MissingTargetBehavior missingTarget;

  /// How long to wait for targets (navigation, async loading) before
  /// applying [missingTarget].
  final Duration targetTimeout;

  /// Swallow taps outside the cut-outs so only highlighted widgets are usable.
  final bool? blockOutside;
  final bool? showSkip;
  final Color? overlayColor;
  final double? blurSigma;

  OnboardingContent? contentFor(int group) => groups[group].content ?? content;

  StepAdvance advanceFor(int group) => groups[group].advance ?? advance;
}
