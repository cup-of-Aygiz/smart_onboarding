import 'package:flutter/widgets.dart';

import '../model/onboarding_content.dart';

/// Physical side, after resolving `start`/`end` against text direction.
enum PhysicalSide { top, bottom, left, right }

@immutable
class ContentLayout {
  const ContentLayout(this.rect, this.side);

  final Rect rect;

  /// Side of the anchor the content ended up on; null when the content was
  /// pinned or centered independently of the anchor.
  final PhysicalSide? side;
}

PhysicalSide resolveSide(ContentSide side, TextDirection direction) {
  final rtl = direction == TextDirection.rtl;
  return switch (side) {
    ContentSide.top => PhysicalSide.top,
    ContentSide.bottom => PhysicalSide.bottom,
    ContentSide.start => rtl ? PhysicalSide.right : PhysicalSide.left,
    ContentSide.end => rtl ? PhysicalSide.left : PhysicalSide.right,
  };
}

/// Finds where content of [size] goes.
///
/// [bounds] is the usable area (safe area minus margins), [anchor] the area
/// the content relates to and [obstacles] the cut-outs it must not cover.
ContentLayout layoutContent({
  required Size size,
  required Rect bounds,
  required Rect? anchor,
  required List<Rect> obstacles,
  required ContentPlacement placement,
  required double gap,
  required TextDirection textDirection,
}) {
  switch (placement) {
    case AlignedPlacement(:final alignment):
      final rect = alignment.resolve(textDirection).inscribe(size, bounds);
      return ContentLayout(rect, null);
    case CustomPlacement(:final position):
      return ContentLayout(position(bounds, size, anchor) & size, null);
    case SidePlacement(:final side):
      if (anchor == null) return _centered(size, bounds, obstacles);
      final physical = resolveSide(side, textDirection);
      return ContentLayout(
        _clamp(_sideRect(physical, size, anchor, gap), bounds),
        physical,
      );
    case AutoPlacement(:final preferred):
      if (anchor == null) return _centered(size, bounds, obstacles);
      return _auto(
        size: size,
        bounds: bounds,
        anchor: anchor,
        obstacles: obstacles,
        preferred: [for (final s in preferred) resolveSide(s, textDirection)],
        gap: gap,
      );
  }
}

ContentLayout _auto({
  required Size size,
  required Rect bounds,
  required Rect anchor,
  required List<Rect> obstacles,
  required List<PhysicalSide> preferred,
  required double gap,
}) {
  double space(PhysicalSide side) => switch (side) {
    PhysicalSide.top => anchor.top - bounds.top,
    PhysicalSide.bottom => bounds.bottom - anchor.bottom,
    PhysicalSide.left => anchor.left - bounds.left,
    PhysicalSide.right => bounds.right - anchor.right,
  };

  // Vertical sides read better on phones, so they go first; within each
  // axis the side with more room wins.
  final vertical = [PhysicalSide.bottom, PhysicalSide.top]
    ..sort((a, b) => space(b).compareTo(space(a)));
  final horizontal = [PhysicalSide.right, PhysicalSide.left]
    ..sort((a, b) => space(b).compareTo(space(a)));
  final order = <PhysicalSide>{...preferred, ...vertical, ...horizontal};

  final candidates = <ContentLayout>[];
  for (final side in order) {
    final raw = _sideRect(side, size, anchor, gap);
    final fitsMainAxis = switch (side) {
      PhysicalSide.top => raw.top >= bounds.top - 0.5,
      PhysicalSide.bottom => raw.bottom <= bounds.bottom + 0.5,
      PhysicalSide.left => raw.left >= bounds.left - 0.5,
      PhysicalSide.right => raw.right <= bounds.right + 0.5,
    };
    final rect = _clamp(raw, bounds);
    final layout = ContentLayout(rect, side);
    if (fitsMainAxis && _overlap(rect, obstacles) == 0) return layout;
    candidates.add(layout);
  }

  // Nothing fits cleanly next to the anchor: also consider fixed spots on
  // screen and take whatever covers the highlights the least.
  for (final alignment in const [
    Alignment.bottomCenter,
    Alignment.topCenter,
    Alignment.center,
  ]) {
    candidates.add(ContentLayout(alignment.inscribe(size, bounds), null));
  }
  candidates.sort(
    (a, b) =>
        _overlap(a.rect, obstacles).compareTo(_overlap(b.rect, obstacles)),
  );
  return candidates.first;
}

ContentLayout _centered(Size size, Rect bounds, List<Rect> obstacles) {
  final spots = [
    for (final alignment in const [
      Alignment.center,
      Alignment.bottomCenter,
      Alignment.topCenter,
    ])
      alignment.inscribe(size, bounds),
  ];
  spots.sort(
    (a, b) => _overlap(a, obstacles).compareTo(_overlap(b, obstacles)),
  );
  return ContentLayout(spots.first, null);
}

Rect _sideRect(PhysicalSide side, Size size, Rect anchor, double gap) {
  return switch (side) {
    PhysicalSide.bottom =>
      Offset(anchor.center.dx - size.width / 2, anchor.bottom + gap) & size,
    PhysicalSide.top =>
      Offset(
            anchor.center.dx - size.width / 2,
            anchor.top - gap - size.height,
          ) &
          size,
    PhysicalSide.left =>
      Offset(
            anchor.left - gap - size.width,
            anchor.center.dy - size.height / 2,
          ) &
          size,
    PhysicalSide.right =>
      Offset(anchor.right + gap, anchor.center.dy - size.height / 2) & size,
  };
}

Rect _clamp(Rect rect, Rect bounds) {
  double clampAxis(double start, double length, double min, double max) {
    if (length >= max - min) return min;
    return start.clamp(min, max - length);
  }

  return Offset(
        clampAxis(rect.left, rect.width, bounds.left, bounds.right),
        clampAxis(rect.top, rect.height, bounds.top, bounds.bottom),
      ) &
      rect.size;
}

double _overlap(Rect rect, List<Rect> obstacles) {
  var total = 0.0;
  for (final o in obstacles) {
    final i = rect.intersect(o);
    if (i.width > 0 && i.height > 0) total += i.width * i.height;
  }
  return total;
}
