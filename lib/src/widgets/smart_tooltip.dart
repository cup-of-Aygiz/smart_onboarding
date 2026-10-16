import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/target_ref.dart';
import '../core/target_resolver.dart';
import '../model/onboarding_arrow.dart';
import '../model/onboarding_content.dart';
import '../model/onboarding_theme.dart';
import 'smart_tooltip_layer.dart';

/// Handle returned by [showSmartTooltip].
class SmartTooltipHandle {
  SmartTooltipHandle._();

  _TrackedTooltipState? _state;
  OverlayEntry? _entry;
  final Completer<void> _closed = Completer<void>();

  bool get isShowing => _entry != null;

  /// Completes once the tooltip is removed.
  Future<void> get closed => _closed.future;

  /// Fades the tooltip out and removes it.
  void dismiss() {
    final state = _state;
    if (state != null && state.mounted) {
      state._close();
    } else {
      _remove();
    }
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
    if (!_closed.isCompleted) _closed.complete();
  }
}

/// Shows [builder]'s widget next to [target] without dimming the screen.
///
/// The tooltip follows the target while it moves, picks the side with room
/// on its own (unless [placement] pins it) and optionally points at it with
/// [arrow]. Returns a handle to dismiss it.
SmartTooltipHandle showSmartTooltip(
  BuildContext context, {
  required OnboardingTargetRef target,
  required WidgetBuilder builder,
  ContentPlacement placement = const ContentPlacement.auto(),
  OnboardingArrow arrow = OnboardingArrow.none,
  double maxWidth = 280,
  double gap = 12,
  EdgeInsets margin = const EdgeInsets.all(12),
  OnboardingAnimation animation = const OnboardingAnimation(),
  Duration? duration,
  bool dismissOnTap = true,
  VoidCallback? onDismissed,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final handle = SmartTooltipHandle._();
  handle._entry = OverlayEntry(
    builder: (context) => _TrackedTooltip(
      handle: handle,
      target: target,
      builder: builder,
      placement: placement,
      arrow: arrow,
      maxWidth: maxWidth,
      gap: gap,
      margin: margin,
      animation: animation,
      duration: duration,
      dismissOnTap: dismissOnTap,
      onDismissed: onDismissed,
    ),
  );
  overlay.insert(handle._entry!);
  return handle;
}

class _TrackedTooltip extends StatefulWidget {
  const _TrackedTooltip({
    required this.handle,
    required this.target,
    required this.builder,
    required this.placement,
    required this.arrow,
    required this.maxWidth,
    required this.gap,
    required this.margin,
    required this.animation,
    required this.duration,
    required this.dismissOnTap,
    required this.onDismissed,
  });

  final SmartTooltipHandle handle;
  final OnboardingTargetRef target;
  final WidgetBuilder builder;
  final ContentPlacement placement;
  final OnboardingArrow arrow;
  final double maxWidth;
  final double gap;
  final EdgeInsets margin;
  final OnboardingAnimation animation;
  final Duration? duration;
  final bool dismissOnTap;
  final VoidCallback? onDismissed;

  @override
  State<_TrackedTooltip> createState() => _TrackedTooltipState();
}

class _TrackedTooltipState extends State<_TrackedTooltip> {
  Rect? _rect;
  bool _closing = false;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    widget.handle._state = this;
    if (widget.duration != null) _autoClose = Timer(widget.duration!, _close);
    _track();
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    if (widget.handle._state == this) widget.handle._state = null;
    super.dispose();
  }

  void _track() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) return;
      final root = context.findRenderObject();
      if (root != null && root.attached) {
        final found = resolveTarget(
          widget.target,
          root,
          textDirection: Directionality.of(context),
        );
        if (found?.rect != _rect) setState(() => _rect = found?.rect);
      }
      _track();
    });
  }

  void _close() {
    if (_closing || !mounted) return;
    _autoClose?.cancel();
    setState(() => _closing = true);
    Future<void>.delayed(widget.animation.effectiveDuration, () {
      widget.handle._remove();
      widget.onDismissed?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    final media = MediaQuery.of(context);
    final margin =
        widget.margin +
        media.padding +
        EdgeInsets.only(bottom: media.viewInsets.bottom);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.dismissOnTap ? (_) => _close() : null,
      child: SizedBox.expand(
        child: SmartTooltipLayer(
          targets: [?rect],
          content: Material(
            type: MaterialType.transparency,
            child: Builder(builder: widget.builder),
          ),
          arrows: [widget.arrow],
          placement: widget.placement,
          maxWidth: widget.maxWidth,
          gap: widget.gap,
          margin: margin.resolve(Directionality.of(context)),
          animation: widget.animation,
          visible: rect != null && !_closing,
        ),
      ),
    );
  }
}
