import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../controller/onboarding_controller.dart';
import '../core/target_resolver.dart';
import '../model/onboarding_arrow.dart';
import '../model/onboarding_content.dart';
import '../model/onboarding_highlight.dart';
import '../model/onboarding_step.dart';
import '../model/onboarding_theme.dart';
import '../model/step_info.dart';
import '../render/spotlight.dart';
import 'onboarding_timer_bar.dart';
import 'smart_tooltip_layer.dart';

/// Hosts the onboarding overlay above [child].
///
/// Put it above every route so steps can follow navigation, ideally via
/// `MaterialApp(builder: SmartOnboarding.builder(controller: controller))`.
class SmartOnboarding extends StatefulWidget {
  const SmartOnboarding({
    super.key,
    required this.controller,
    required this.child,
    this.theme = const OnboardingTheme(),
  });

  /// Convenience for `MaterialApp.builder` / `CupertinoApp.builder`.
  /// [builder] lets you keep an existing app builder.
  static TransitionBuilder builder({
    required OnboardingController controller,
    OnboardingTheme theme = const OnboardingTheme(),
    TransitionBuilder? builder,
  }) {
    return (context, child) => SmartOnboarding(
      controller: controller,
      theme: theme,
      child: builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
    );
  }

  final OnboardingController controller;
  final OnboardingTheme theme;
  final Widget child;

  /// The nearest controller, e.g. to call `next()` from a screen.
  static OnboardingController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_OnboardingScope>()?.controller;

  static OnboardingController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No SmartOnboarding above this context.');
    return controller!;
  }

  @override
  State<SmartOnboarding> createState() => _SmartOnboardingState();
}

/// Found highlight paired with its cut-out.
class _Spot {
  const _Spot(this.highlight, this.context, this.hole);

  final OnboardingHighlight highlight;
  final BuildContext? context;
  final SpotlightHole hole;
}

class _SmartOnboardingState extends State<SmartOnboarding>
    with TickerProviderStateMixin {
  late final AnimationController _visibility = AnimationController(vsync: this);
  late final AnimationController _morph = AnimationController(
    vsync: this,
    value: 1,
  );
  late final AnimationController _timer = AnimationController(vsync: this)
    ..addStatusListener(_onTimerStatus);
  late final AnimationController _pulse = AnimationController(vsync: this);

  /// Controller position this state is showing or waiting for.
  int _position = -1;

  /// Position whose step is currently drawn (lags behind [_position] while
  /// the next targets are being looked up).
  int _shownPosition = -1;
  OnboardingStep? _shownStep;
  int _shownStepIndex = 0;
  int _shownStepCount = 0;
  int _shownGroup = 0;

  List<_Spot> _spots = const [];
  List<SpotlightHole> _from = const [];
  List<SpotlightHole> _lastDrawn = const [];
  bool _ready = false;
  bool _acceptPartial = false;
  bool _scrolled = false;
  Timer? _waitTimer;
  bool _trackScheduled = false;

  int? _pointer;
  Offset? _pointerDown;

  OnboardingController get _controller => widget.controller;
  OnboardingAnimation get _animation => widget.theme.animation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _applyAnimationDurations();
    _sync();
  }

  @override
  void didUpdateWidget(SmartOnboarding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _position = -1;
      _sync();
    }
    _applyAnimationDurations();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _waitTimer?.cancel();
    _visibility.dispose();
    _morph.dispose();
    _timer.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _applyAnimationDurations() {
    _visibility.duration = _animation.effectiveDuration;
    _morph.duration = _animation.effectiveDuration;
    _pulse.duration = _animation.pulseDuration;
  }

  void _onControllerChanged() {
    // `start()` may be called from a build method or initState; never
    // setState in the middle of a frame.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    } else {
      _sync();
    }
  }

  void _sync() {
    final position = _controller.position;
    if (position == _position) return;
    _position = position;
    _from = _lastDrawn;
    _ready = false;
    _acceptPartial = false;
    _scrolled = false;
    _waitTimer?.cancel();
    _timer
      ..stop()
      ..value = 0;

    final step = _controller.currentStep;
    if (step == null) {
      _pulse.stop();
      _hide();
      setState(() {});
      return;
    }
    _waitTimer = Timer(step.targetTimeout, _onTargetTimeout);
    _scheduleTrack();
    SchedulerBinding.instance.ensureVisualUpdate();
    setState(() {});
  }

  void _hide() {
    if (_animation.enabled) {
      _visibility.reverse();
    } else {
      _visibility.value = 0;
    }
  }

  void _scheduleTrack() {
    if (_trackScheduled) return;
    _trackScheduled = true;
    // Runs after every frame (without forcing frames), so scrolling,
    // rotation, keyboard and layout changes are all picked up.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _trackScheduled = false;
      if (!mounted || !_controller.isActive) return;
      _track();
      _scheduleTrack();
    });
  }

  void _track() {
    final step = _controller.currentStep;
    final group = _controller.currentGroup;
    final root = context.findRenderObject();
    if (step == null || group == null || root == null || !root.attached) {
      return;
    }
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final theme = widget.theme;

    final spots = <_Spot>[];
    var missing = false;
    for (final highlight in group.highlights) {
      final found = resolveTarget(
        highlight.target,
        root,
        textDirection: direction,
      );
      if (found == null) {
        missing = true;
        continue;
      }
      final rect = (highlight.padding ?? theme.padding).inflateRect(found.rect);
      final shape = highlight.shape ?? theme.shape;
      final rrect = shape.toRRect(rect);
      spots.add(
        _Spot(
          highlight,
          found.context,
          SpotlightHole(
            bounds: rrect?.outerRect ?? rect,
            rrect: rrect,
            customPath: rrect == null ? shape.toPath(rect) : null,
            interactive: highlight.interactive ?? theme.interactive,
          ),
        ),
      );
    }

    if (missing && !_acceptPartial) {
      if (_ready) {
        // A target vanished (navigation, rebuild). Pause until it is back.
        setState(() {
          _ready = false;
          _timer.stop();
          _pulse.stop();
          _hide();
        });
      }
      return;
    }

    if (!_ready) {
      _becomeReady(step, spots);
    } else if (!_sameSpots(spots, _spots)) {
      setState(() => _spots = spots);
    }
  }

  void _becomeReady(OnboardingStep step, List<_Spot> spots) {
    _waitTimer?.cancel();
    final firstShowOfPosition = _shownPosition != _position;
    setState(() {
      _ready = true;
      _spots = spots;
      _shownPosition = _position;
      _shownStep = step;
      _shownStepIndex = _controller.stepIndex;
      _shownStepCount = _controller.steps.length;
      _shownGroup = _controller.groupIndex;
    });

    if (!_animation.enabled) {
      _visibility.value = 1;
      _morph.value = 1;
    } else {
      if (_visibility.value == 0) {
        // Nothing on screen: just fade in.
        _morph.value = 1;
      } else if (firstShowOfPosition) {
        _morph.forward(from: 0);
      }
      _visibility.forward();
      if (_animation.pulse) _pulse.repeat();
    }

    final advance = step.advanceFor(_controller.groupIndex);
    if (advance.duration != null) {
      _timer.duration = advance.duration;
      _timer.forward();
    }

    if (!_scrolled) {
      _scrolled = true;
      for (final spot in spots) {
        if (spot.highlight.autoScroll && spot.context != null) {
          _ensureVisible(spot.context!);
        }
      }
    }

    if (firstShowOfPosition) _controller.reportShown(_position);
  }

  void _ensureVisible(BuildContext target) {
    final scrollable = Scrollable.maybeOf(target);
    final viewport = scrollable?.context.findRenderObject();
    final root = context.findRenderObject();
    if (scrollable == null || viewport is! RenderBox || root == null) return;
    final targetBounds = targetRect(target, viewport);
    if (targetBounds == null) return;
    final visible = Offset.zero & viewport.size;
    if (visible.contains(targetBounds.topLeft) &&
        visible.contains(targetBounds.bottomRight - const Offset(1, 1))) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: _animation.enabled
          ? const Duration(milliseconds: 350)
          : Duration.zero,
      curve: Curves.easeInOut,
    );
  }

  void _onTargetTimeout() {
    if (!mounted || _ready) return;
    final step = _controller.currentStep;
    if (step == null) return;
    switch (step.missingTarget) {
      case MissingTargetBehavior.skip:
        _controller.reportMissing(_position);
      case MissingTargetBehavior.showAvailable:
        _acceptPartial = true;
        _track();
    }
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.advanceFrom(_position, StepCompletionReason.timer);
    }
  }

  // Tap detection runs on a translucent Listener above the whole app, so it
  // sees taps even when they pass through a cut-out to the real widget.
  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _pointerDown = event.position;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final down = _pointerDown;
    _pointer = null;
    _pointerDown = null;
    if (down == null || (event.position - down).distance > kTouchSlop) return;
    _onTap(event.localPosition);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _pointerDown = null;
  }

  void _onTap(Offset position) {
    final step = _controller.currentStep;
    if (!_ready || step == null || _shownPosition != _position) return;
    final tap = step.advanceFor(_controller.groupIndex).tap;
    final inHole = _spots.any((s) => s.hole.contains(position));
    final allowed = switch (tap) {
      TapToAdvance.none => false,
      TapToAdvance.target => inHole,
      TapToAdvance.outside => !inHole,
      TapToAdvance.anywhere => true,
    };
    if (!allowed) return;
    final token = _position;
    final reason = inHole
        ? StepCompletionReason.tapTarget
        : StepCompletionReason.tapOutside;
    // Let the real widget handle the tap first; if it calls next() itself
    // the token check prevents a double advance.
    scheduleMicrotask(() => _controller.advanceFrom(token, reason));
  }

  List<SpotlightHole> _currentHoles() {
    final to = [for (final s in _spots) s.hole];
    final t = _animation.curve.transform(_morph.value.clamp(0.0, 1.0));
    if (t >= 1) return to;
    return [
      for (var i = 0; i < to.length; i++)
        SpotlightHole.lerp(
          i < _from.length ? _from[i] : to[i].collapsed(),
          to[i],
          t,
        ),
      for (var i = to.length; i < _from.length; i++)
        SpotlightHole.lerp(_from[i], _from[i].collapsed(), t),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final media =
        MediaQuery.maybeOf(context) ??
        MediaQueryData.fromView(View.of(context));

    return _OnboardingScope(
      controller: _controller,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Stack(
          textDirection: direction,
          fit: StackFit.expand,
          children: [
            widget.child,
            AnimatedBuilder(
              animation: Listenable.merge([_visibility, _morph]),
              builder: (context, _) {
                if (_shownStep == null || _visibility.value == 0) {
                  _lastDrawn = const [];
                  return const SizedBox.shrink();
                }
                return Directionality(
                  textDirection: direction,
                  child: MediaQuery(data: media, child: _buildLayer(media)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayer(MediaQueryData media) {
    final theme = widget.theme;
    final step = _shownStep!;
    final content = step.contentFor(_shownGroup);
    final advance = step.advanceFor(_shownGroup);
    final v = _visibility.value;

    final holes = _currentHoles();
    _lastDrawn = holes;

    final baseColor = step.overlayColor ?? theme.overlayColor;
    final color = baseColor.withValues(alpha: baseColor.a * v);
    final sigma = (step.blurSigma ?? theme.blurSigma) * v;
    final blockOutside = (step.blockOutside ?? theme.blockOutside) && _ready;
    final showSkip = step.showSkip ?? theme.showSkip;

    final insets =
        media.padding + EdgeInsets.only(bottom: media.viewInsets.bottom);
    final margin = EdgeInsets.fromLTRB(
      insets.left + theme.margin.left,
      insets.top + theme.margin.top,
      insets.right + theme.margin.right,
      insets.bottom + theme.margin.bottom,
    );

    final arrows = [
      for (final spot in _spots)
        spot.highlight.arrow ??
            content?.arrow ??
            (content == null ? OnboardingArrow.none : theme.arrow),
    ];

    final info = OnboardingStepInfo(
      controller: _controller,
      step: step,
      stepIndex: _shownStepIndex,
      stepCount: _shownStepCount,
      groupIndex: _shownGroup,
      groupCount: step.groups.length,
      timer: advance.duration != null ? _timer : null,
      progressPlacement: advance.progress,
    );

    Widget? contentWidget;
    if (content != null) {
      contentWidget = OnboardingStepScope(
        info: info,
        child: Material(
          type: MaterialType.transparency,
          child: Builder(builder: (context) => content.builder(context, info)),
        ),
      );
    }

    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final skipAlignment = showSkip ? _skipAlignment(media, direction) : null;
    final skipRect = skipAlignment?.inscribe(
      _skipReserve,
      media.padding.deflateRect(Offset.zero & media.size),
    );

    final showBar =
        advance.duration != null &&
        (advance.progress == ProgressPlacement.top ||
            advance.progress == ProgressPlacement.bottom);

    // Gives text in the skip button and custom builders a DefaultTextStyle;
    // a transparency Material does not absorb hits.
    return Material(
      type: MaterialType.transparency,
      child: HoleHitTest(
        holes: holes,
        absorbOutside: blockOutside,
        absorbHoles: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => SpotlightOverlay(
                holes: holes,
                color: color,
                blurSigma: sigma,
                pulse: _animation.pulse && _ready && _pulse.isAnimating
                    ? _pulse.value
                    : null,
                pulseColor: const Color(0xFFFFFFFF).withValues(alpha: v),
              ),
            ),
            SmartTooltipLayer(
              targets: [for (final s in _spots) s.hole.bounds],
              content: contentWidget,
              arrows: arrows,
              placement: content?.placement ?? const ContentPlacement.auto(),
              maxWidth: content?.maxWidth ?? 320,
              gap: content?.gap ?? (arrows.any((a) => a is! NoArrow) ? 56 : 16),
              anchorIndex: content?.anchor,
              margin: margin,
              animation: _animation,
              visible: _ready,
              contentKey: _shownPosition,
              arrowOnlyLength: theme.arrowOnlyLength,
              avoid: [?skipRect],
            ),
            if (showBar)
              Positioned(
                left: insets.left,
                right: insets.right,
                top: advance.progress == ProgressPlacement.top
                    ? insets.top
                    : null,
                bottom: advance.progress == ProgressPlacement.bottom
                    ? insets.bottom
                    : null,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: v,
                    child: OnboardingTimerBar(
                      animation: _timer,
                      color: theme.progressColor,
                      height: 3,
                      radius: 0,
                    ),
                  ),
                ),
              ),
            if (skipAlignment != null)
              Positioned.fill(
                child: SafeArea(
                  child: Align(
                    alignment: skipAlignment,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Opacity(
                        opacity: v,
                        child: IgnorePointer(
                          ignoring: !_ready,
                          child:
                              theme.skipBuilder?.call(
                                context,
                                _controller.skip,
                              ) ??
                              _SkipButton(
                                label: theme.skipLabel,
                                onTap: _controller.skip,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Space reserved for the skip button when choosing its corner.
  static const _skipReserve = Size(140, 56);

  /// The theme corner, unless a cut-out is there; then the first free one.
  Alignment _skipAlignment(MediaQueryData media, TextDirection direction) {
    final safe = media.padding.deflateRect(Offset.zero & media.size);
    final candidates = <AlignmentGeometry>[
      widget.theme.skipAlignment,
      AlignmentDirectional.bottomEnd,
      AlignmentDirectional.topStart,
      AlignmentDirectional.bottomStart,
    ];
    for (final candidate in candidates) {
      final alignment = candidate.resolve(direction);
      final rect = alignment.inscribe(_skipReserve, safe);
      if (!_spots.any((s) => s.hole.bounds.overlaps(rect))) return alignment;
    }
    return widget.theme.skipAlignment.resolve(direction);
  }
}

bool _sameSpots(List<_Spot> a, List<_Spot> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i].hole, y = b[i].hole;
    if (x.bounds != y.bounds || x.interactive != y.interactive) return false;
  }
  return true;
}

class _OnboardingScope extends InheritedWidget {
  const _OnboardingScope({required this.controller, required super.child});

  final OnboardingController controller;

  @override
  bool updateShouldNotify(_OnboardingScope oldWidget) =>
      controller != oldWidget.controller;
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
