import 'package:flutter/widgets.dart';

import '../widgets/onboarding_tooltip.dart';
import 'onboarding_arrow.dart';
import 'step_info.dart';

typedef OnboardingContentBuilder =
    Widget Function(BuildContext context, OnboardingStepInfo info);

/// Logical side of the highlighted widget. `start`/`end` follow the ambient
/// [TextDirection], so layouts mirror automatically in RTL.
enum ContentSide { top, bottom, start, end }

/// Where content goes on screen.
@immutable
sealed class ContentPlacement {
  const ContentPlacement();

  /// Picks the first side (from [preferred], then by free space) where the
  /// content fits without covering any highlight. Falls back to the spot with
  /// the least overlap.
  const factory ContentPlacement.auto({List<ContentSide> preferred}) =
      AutoPlacement;

  /// Always on [side] of the target, only shifted to stay on screen.
  const factory ContentPlacement.side(ContentSide side) = SidePlacement;

  /// Pinned to [alignment] inside the safe area, ignoring targets.
  const factory ContentPlacement.aligned(AlignmentGeometry alignment) =
      AlignedPlacement;

  /// Pinned to an arbitrary rect. [bounds] is the safe area, [anchor] is the
  /// highlighted area (null for steps without targets).
  const factory ContentPlacement.custom(
    Offset Function(Rect bounds, Size content, Rect? anchor) position,
  ) = CustomPlacement;
}

final class AutoPlacement extends ContentPlacement {
  const AutoPlacement({this.preferred = const []});

  final List<ContentSide> preferred;
}

final class SidePlacement extends ContentPlacement {
  const SidePlacement(this.side);

  final ContentSide side;
}

final class AlignedPlacement extends ContentPlacement {
  const AlignedPlacement(this.alignment);

  final AlignmentGeometry alignment;
}

final class CustomPlacement extends ContentPlacement {
  const CustomPlacement(this.position);

  final Offset Function(Rect bounds, Size content, Rect? anchor) position;
}

/// What is shown next to the highlight: any widget plus how to place it.
@immutable
class OnboardingContent {
  const OnboardingContent({
    required this.builder,
    this.placement = const ContentPlacement.auto(),
    this.maxWidth = 320,
    this.gap,
    this.arrow,
    this.anchor,
  });

  /// Ready-made card with title, text, step counter, timer bar and a
  /// next button.
  factory OnboardingContent.tooltip({
    String? title,
    required String text,
    String? nextLabel,
    String? doneLabel,
    bool showNext = true,
    bool showCounter = true,
    ContentPlacement placement = const ContentPlacement.auto(),
    double maxWidth = 320,
    double? gap,
    OnboardingArrow? arrow,
    int? anchor,
  }) => OnboardingContent(
    builder: (context, info) => OnboardingTooltip(
      title: title,
      text: text,
      nextLabel: nextLabel,
      doneLabel: doneLabel,
      showNext: showNext,
      showCounter: showCounter,
    ),
    placement: placement,
    maxWidth: maxWidth,
    gap: gap,
    arrow: arrow,
    anchor: anchor,
  );

  final OnboardingContentBuilder builder;
  final ContentPlacement placement;
  final double maxWidth;

  /// Distance between the content and the highlight. Null picks a value that
  /// leaves room for arrows when they are shown (56) or 16 otherwise.
  final double? gap;

  /// Default arrow for every highlight of the group. Overridden by
  /// `OnboardingHighlight.arrow`. Null falls back to the theme.
  final OnboardingArrow? arrow;

  /// Index of the highlight the content is positioned around. Null means the
  /// bounding box of all highlights.
  final int? anchor;
}
