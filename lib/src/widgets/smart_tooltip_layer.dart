import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../layout/arrow_geometry.dart';
import '../layout/content_placement.dart';
import '../model/onboarding_arrow.dart';
import '../model/onboarding_content.dart';
import '../model/onboarding_theme.dart';
import '../render/arrow_view.dart';

/// Full-screen layer that positions [content] next to [targets] without
/// covering them and draws [arrows] from the content to each target.
///
/// It knows nothing about onboarding and can be used on its own (see
/// `showSmartTooltip`). All rects are in this widget's coordinate space.
class SmartTooltipLayer extends StatefulWidget {
  const SmartTooltipLayer({
    super.key,
    required this.targets,
    this.content,
    this.arrows = const [],
    this.placement = const ContentPlacement.auto(),
    this.maxWidth = 320,
    this.gap = 16,
    this.anchorIndex,
    this.margin = const EdgeInsets.all(16),
    this.animation = const OnboardingAnimation(),
    this.visible = true,
    this.contentKey,
    this.arrowOnlyLength = 72,
    this.avoid = const [],
  });

  /// Bounds of the highlighted areas.
  final List<Rect> targets;
  final Widget? content;

  /// Arrow per target (same index). Missing entries mean no arrow.
  final List<OnboardingArrow> arrows;
  final ContentPlacement placement;
  final double maxWidth;
  final double gap;
  final int? anchorIndex;

  /// Insets from the layer edges content must respect (safe area + margin).
  final EdgeInsets margin;
  final OnboardingAnimation animation;
  final bool visible;

  /// Change it to tell the layer the content is new: it is re-measured and
  /// arrows are drawn again.
  final Object? contentKey;

  /// Arrow length when there is no content.
  final double arrowOnlyLength;

  /// Extra areas content should not cover (e.g. a skip button).
  final List<Rect> avoid;

  @override
  State<SmartTooltipLayer> createState() => _SmartTooltipLayerState();
}

class _SmartTooltipLayerState extends State<SmartTooltipLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrows = AnimationController(vsync: this);
  Size? _contentSize;
  bool _arrowsStarted = false;

  @override
  void initState() {
    super.initState();
    _syncArrowDuration();
    _maybeStartArrows();
  }

  @override
  void didUpdateWidget(SmartTooltipLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentKey != widget.contentKey) {
      _contentSize = null;
      _arrowsStarted = false;
      _arrows.value = 0;
    }
    if (!widget.visible && oldWidget.visible) {
      _arrowsStarted = false;
      _arrows.value = 0;
    }
    _syncArrowDuration();
    _maybeStartArrows();
  }

  @override
  void dispose() {
    _arrows.dispose();
    super.dispose();
  }

  int get _arrowCount => widget.arrows
      .take(widget.targets.length)
      .where((a) => a is! NoArrow)
      .length;

  void _syncArrowDuration() {
    final a = widget.animation;
    final n = math.max(1, _arrowCount);
    _arrows.duration = a.arrowDuration + a.arrowStagger * (n - 1);
  }

  void _maybeStartArrows() {
    if (_arrowsStarted || !widget.visible) return;
    if (widget.content != null && _contentSize == null) return;
    _arrowsStarted = true;
    if (!widget.animation.enabled) {
      _arrows.value = 1;
      return;
    }
    // Let the content fade in a bit before arrows start drawing.
    final delay = widget.animation.duration * 0.5;
    Future<void>.delayed(delay, () {
      if (mounted && _arrowsStarted && widget.visible) {
        _arrows.forward(from: 0);
      }
    });
  }

  void _onMeasured(Size size) {
    if (!mounted || size == _contentSize) return;
    setState(() => _contentSize = size);
    _maybeStartArrows();
  }

  Animation<double> _arrowProgress(int index) {
    final total = _arrows.duration ?? Duration.zero;
    if (total == Duration.zero) return _arrows;
    final a = widget.animation;
    final start =
        (a.arrowStagger * index).inMicroseconds / total.inMicroseconds;
    final end =
        (a.arrowStagger * index + a.arrowDuration).inMicroseconds /
        total.inMicroseconds;
    return _arrows.drive(
      CurveTween(curve: Interval(start.clamp(0, 1), end.clamp(0, 1))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = widget.margin.deflateRect(
          Offset.zero & constraints.biggest,
        );
        final children = <Widget>[];
        final targets = widget.targets;
        final anchorIndex = widget.anchorIndex;
        final anchor = targets.isEmpty
            ? null
            : anchorIndex != null && anchorIndex < targets.length
            ? targets[anchorIndex]
            : targets.reduce((a, b) => a.expandToInclude(b));

        Rect? contentRect;
        final content = widget.content;
        if (content != null) {
          final measured = _MeasureSize(
            key: ValueKey(widget.contentKey),
            onChange: _onMeasured,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.max(0, math.min(widget.maxWidth, bounds.width)),
                maxHeight: math.max(0, bounds.height),
              ),
              child: content,
            ),
          );
          final size = _contentSize;
          if (size == null) {
            children.add(
              Positioned(
                left: bounds.left,
                top: bounds.top,
                child: IgnorePointer(
                  child: Opacity(opacity: 0, child: measured),
                ),
              ),
            );
          } else {
            contentRect = layoutContent(
              size: size,
              bounds: bounds,
              anchor: anchor,
              obstacles: [...targets, ...widget.avoid],
              placement: widget.placement,
              gap: widget.gap,
              textDirection: direction,
            ).rect;
            children.add(
              Positioned(
                left: contentRect.left,
                top: contentRect.top,
                child: AnimatedOpacity(
                  opacity: widget.visible ? 1 : 0,
                  duration: widget.animation.effectiveDuration,
                  curve: widget.animation.curve,
                  child: IgnorePointer(
                    ignoring: !widget.visible,
                    child: measured,
                  ),
                ),
              ),
            );
          }
        }

        final canDrawArrows = content == null || contentRect != null;
        if (canDrawArrows && widget.visible) {
          var arrowIndex = 0;
          for (var i = 0; i < targets.length && i < widget.arrows.length; i++) {
            final arrow = widget.arrows[i];
            if (arrow is NoArrow) continue;
            final curvature = arrow is CurvedArrow ? arrow.curvature : 0.25;
            final geometry = contentRect != null
                ? computeArrow(
                    from: contentRect,
                    target: targets[i],
                    curvature: curvature,
                    tipGap: arrow.tipGap,
                    textDirection: direction,
                  )
                : computeStandaloneArrow(
                    target: targets[i],
                    bounds: bounds,
                    length: widget.arrowOnlyLength,
                    curvature: curvature,
                    tipGap: arrow.tipGap,
                    textDirection: direction,
                  );
            if (geometry == null) continue;
            children.insert(
              0,
              Positioned.fill(
                child: ArrowView(
                  arrow: arrow,
                  geometry: geometry,
                  progress: _arrowProgress(arrowIndex++),
                ),
              ),
            );
          }
        }

        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({super.key, required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    final reported = size;
    SchedulerBinding.instance.addPostFrameCallback((_) => onChange(reported));
  }
}
