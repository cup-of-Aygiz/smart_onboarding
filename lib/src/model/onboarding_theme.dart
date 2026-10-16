import 'package:flutter/widgets.dart';

import 'highlight_shape.dart';
import 'onboarding_arrow.dart';

/// Animation settings. `OnboardingAnimation.none` turns everything off.
@immutable
class OnboardingAnimation {
  const OnboardingAnimation({
    this.enabled = true,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeInOutCubic,
    this.pulse = true,
    this.pulseDuration = const Duration(milliseconds: 1400),
    this.arrowDuration = const Duration(milliseconds: 550),
    this.arrowStagger = const Duration(milliseconds: 250),
  });

  static const OnboardingAnimation none = OnboardingAnimation(
    enabled: false,
    pulse: false,
  );

  final bool enabled;

  /// Fade in/out and morphing of cut-outs between groups and steps.
  final Duration duration;
  final Curve curve;

  /// Ring pulsing around cut-outs.
  final bool pulse;
  final Duration pulseDuration;

  /// Time to draw a single arrow.
  final Duration arrowDuration;

  /// Delay between arrows when several targets are highlighted at once.
  final Duration arrowStagger;

  Duration get effectiveDuration => enabled ? duration : Duration.zero;
}

typedef SkipButtonBuilder =
    Widget Function(BuildContext context, VoidCallback skip);

/// Defaults for every step. Most of them can be overridden per step or per
/// highlight.
@immutable
class OnboardingTheme {
  const OnboardingTheme({
    this.overlayColor = const Color(0xB3000000),
    this.blurSigma = 2.5,
    this.padding = const EdgeInsets.all(8),
    this.shape = const HighlightShape.rect(),
    this.arrow = const OnboardingArrow.curved(),
    this.animation = const OnboardingAnimation(),
    this.blockOutside = true,
    this.interactive = true,
    this.showSkip = true,
    this.skipLabel = 'Skip',
    this.skipBuilder,
    this.skipAlignment = AlignmentDirectional.topEnd,
    this.margin = const EdgeInsets.all(16),
    this.progressColor = const Color(0xFFFFFFFF),
    this.arrowOnlyLength = 72,
  });

  final Color overlayColor;

  /// Backdrop blur of the dimmed area; 0 disables it.
  final double blurSigma;
  final EdgeInsets padding;
  final HighlightShape shape;

  /// Arrow drawn from content to targets when nothing more specific is set.
  /// Set to [OnboardingArrow.none] to disable arrows by default.
  final OnboardingArrow arrow;
  final OnboardingAnimation animation;
  final bool blockOutside;
  final bool interactive;
  final bool showSkip;
  final String skipLabel;
  final SkipButtonBuilder? skipBuilder;
  final AlignmentGeometry skipAlignment;

  /// Distance kept between content and the safe area edges.
  final EdgeInsets margin;
  final Color progressColor;

  /// Length of arrows in steps without content.
  final double arrowOnlyLength;
}
