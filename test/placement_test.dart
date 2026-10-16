import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_onboarding/smart_onboarding.dart';
import 'package:smart_onboarding/src/layout/arrow_geometry.dart';
import 'package:smart_onboarding/src/layout/content_placement.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 400, 800);
  const size = Size(200, 100);

  ContentLayout place(
    Rect? anchor, {
    ContentPlacement placement = const ContentPlacement.auto(),
    TextDirection dir = TextDirection.ltr,
    List<Rect>? obstacles,
  }) => layoutContent(
    size: size,
    bounds: bounds,
    anchor: anchor,
    obstacles: obstacles ?? [?anchor],
    placement: placement,
    gap: 10,
    textDirection: dir,
  );

  test('target at the top puts content below', () {
    final layout = place(const Rect.fromLTWH(150, 20, 100, 40));
    expect(layout.side, PhysicalSide.bottom);
    expect(layout.rect.top, 70);
    expect(layout.rect.center.dx, 200);
  });

  test('target at the bottom puts content above', () {
    final layout = place(const Rect.fromLTWH(150, 740, 100, 40));
    expect(layout.side, PhysicalSide.top);
    expect(layout.rect.bottom, 730);
  });

  test('content is clamped horizontally into bounds', () {
    final layout = place(const Rect.fromLTWH(0, 20, 40, 40));
    expect(layout.rect.left, 0);
  });

  test('preferred side wins when it fits', () {
    final layout = place(
      const Rect.fromLTWH(150, 400, 100, 40),
      placement: const ContentPlacement.auto(preferred: [ContentSide.top]),
    );
    expect(layout.side, PhysicalSide.top);
  });

  test('start/end follow text direction', () {
    const anchor = Rect.fromLTWH(180, 0, 220, 800);
    final ltr = place(
      anchor,
      placement: const ContentPlacement.side(ContentSide.start),
    );
    final rtl = place(
      anchor,
      placement: const ContentPlacement.side(ContentSide.start),
      dir: TextDirection.rtl,
    );
    expect(ltr.side, PhysicalSide.left);
    expect(rtl.side, PhysicalSide.right);
  });

  test('avoids covering other highlights', () {
    const a = Rect.fromLTWH(150, 300, 100, 40);
    const blocker = Rect.fromLTWH(0, 350, 400, 120);
    final layout = place(a, obstacles: [a, blocker]);
    expect(layout.side, PhysicalSide.top);
    expect(layout.rect.overlaps(blocker), isFalse);
  });

  test('no anchor centers content', () {
    final layout = place(null);
    expect(layout.rect.center, bounds.center);
  });

  test('aligned placement ignores target', () {
    final layout = place(
      const Rect.fromLTWH(150, 20, 100, 40),
      placement: const ContentPlacement.aligned(Alignment.bottomCenter),
    );
    expect(layout.rect.bottom, 800);
  });

  test('arrow goes from content edge to target edge', () {
    final arrow = computeArrow(
      from: const Rect.fromLTWH(100, 200, 200, 100),
      target: const Rect.fromLTWH(150, 20, 100, 40),
      curvature: 0.3,
      tipGap: 6,
    )!;
    expect(arrow.start.dy, 200);
    expect(arrow.end.dy, 66);
  });

  test('no arrow when content touches target', () {
    final arrow = computeArrow(
      from: const Rect.fromLTWH(100, 60, 200, 100),
      target: const Rect.fromLTWH(150, 20, 100, 40),
      curvature: 0.3,
      tipGap: 6,
    );
    expect(arrow, isNull);
  });
}
