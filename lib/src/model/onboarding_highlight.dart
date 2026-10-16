import 'package:flutter/widgets.dart';

import '../core/target_ref.dart';
import 'highlight_shape.dart';
import 'onboarding_arrow.dart';

/// One widget cut out of the dimmed overlay.
///
/// Fields left null fall back to the step and then to `OnboardingTheme`.
@immutable
class OnboardingHighlight {
  const OnboardingHighlight(
    this.target, {
    this.padding,
    this.shape,
    this.arrow,
    this.interactive,
    this.autoScroll = true,
  });

  OnboardingHighlight.id(
    String id, {
    int occurrence = 0,
    this.padding,
    this.shape,
    this.arrow,
    this.interactive,
    this.autoScroll = true,
  }) : target = OnboardingTargetRef.id(id, occurrence: occurrence);

  OnboardingHighlight.key(
    GlobalKey key, {
    this.padding,
    this.shape,
    this.arrow,
    this.interactive,
    this.autoScroll = true,
  }) : target = OnboardingTargetRef.key(key);

  final OnboardingTargetRef target;

  /// Space between the widget and the edge of the cut-out.
  final EdgeInsets? padding;
  final HighlightShape? shape;

  /// Arrow from the content to this highlight. Use [OnboardingArrow.none] to
  /// hide it for this highlight only.
  final OnboardingArrow? arrow;

  /// Whether taps inside the cut-out reach the real widget. When false the
  /// tap is swallowed, but it still counts towards advancing the step.
  final bool? interactive;

  /// Scroll the nearest [Scrollable] so the target is fully visible.
  final bool autoScroll;
}
