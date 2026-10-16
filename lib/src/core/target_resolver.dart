import 'package:flutter/widgets.dart';

import 'onboarding_target.dart';
import 'target_ref.dart';

/// A target found on screen.
@immutable
class ResolvedTarget {
  const ResolvedTarget(this.context, this.rect);

  final BuildContext context;

  /// Bounds in the coordinate space of the ancestor passed to [resolveTarget].
  final Rect rect;
}

/// Finds [ref] and returns its bounds relative to [ancestor].
///
/// A target counts as found only when it is laid out, its subtree has tickers
/// enabled (so inactive `IndexedStack` tabs and `Offstage` are ignored) and,
/// when [requireSettled] is true, its route is the current one and has
/// finished its transition.
ResolvedTarget? resolveTarget(
  OnboardingTargetRef ref,
  RenderObject ancestor, {
  bool requireSettled = true,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final List<BuildContext> candidates = switch (ref) {
    IdTargetRef(:final id) => OnboardingTargetRegistry.instance.contextsFor(id),
    KeyTargetRef(:final key) => [?key.currentContext],
  };
  final occurrence = switch (ref) {
    IdTargetRef(:final occurrence) => occurrence,
    KeyTargetRef() => 0,
  };

  final visible = <ResolvedTarget>[];
  for (final context in candidates) {
    if (!isTargetVisible(context, requireSettled: requireSettled)) continue;
    final rect = targetRect(context, ancestor);
    if (rect != null) visible.add(ResolvedTarget(context, rect));
  }
  if (visible.length <= occurrence) return null;

  if (visible.length > 1) {
    final rtl = textDirection == TextDirection.rtl;
    visible.sort((a, b) {
      final dy = a.rect.top.compareTo(b.rect.top);
      if (dy != 0 && (a.rect.top - b.rect.top).abs() > 1) return dy;
      return rtl
          ? b.rect.right.compareTo(a.rect.right)
          : a.rect.left.compareTo(b.rect.left);
    });
  }
  return visible[occurrence];
}

/// Whether the widget behind [context] is currently shown to the user.
bool isTargetVisible(BuildContext context, {bool requireSettled = true}) {
  if (!context.mounted) return false;
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize ||
      renderObject.size.isEmpty) {
    return false;
  }
  if (!TickerMode.valuesOf(context).enabled) return false;
  if (requireSettled) {
    final route = ModalRoute.of(context);
    if (route != null) {
      if (!route.isCurrent) return false;
      final status = route.animation?.status;
      if (status != null && status != AnimationStatus.completed) return false;
    }
  }
  return true;
}

/// Bounds of the render box behind [context] relative to [ancestor].
Rect? targetRect(BuildContext context, RenderObject ancestor) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  final transform = box.getTransformTo(ancestor);
  return MatrixUtils.transformRect(transform, Offset.zero & box.size);
}
