import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A cut-out in the overlay.
@immutable
class SpotlightHole {
  const SpotlightHole({
    required this.bounds,
    this.rrect,
    this.customPath,
    this.interactive = true,
  }) : assert(rrect != null || customPath != null);

  /// Area the hole occupies; used for hit testing and layout.
  final Rect bounds;
  final RRect? rrect;
  final Path? customPath;

  /// Taps inside reach the widget below.
  final bool interactive;

  Path get path => customPath ?? (Path()..addRRect(rrect!));

  bool contains(Offset point) =>
      customPath?.contains(point) ?? rrect!.contains(point);

  /// Zero-size hole at the center, used to grow new holes from nothing.
  SpotlightHole collapsed() {
    final c = bounds.center;
    return SpotlightHole(
      bounds: Rect.fromCenter(center: c, width: 0, height: 0),
      rrect: RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 0, height: 0),
        Radius.zero,
      ),
      interactive: interactive,
    );
  }

  static SpotlightHole lerp(SpotlightHole from, SpotlightHole to, double t) {
    if (t >= 1) return to;
    if (from.rrect != null && to.rrect != null) {
      final rrect = RRect.lerp(from.rrect, to.rrect, t)!;
      return SpotlightHole(
        bounds: rrect.outerRect,
        rrect: rrect,
        interactive: to.interactive,
      );
    }
    // Custom paths cannot morph; jump halfway through.
    return t < 0.5 ? from : to;
  }
}

/// Dims (and optionally blurs) everything except [holes].
class SpotlightOverlay extends StatelessWidget {
  const SpotlightOverlay({
    super.key,
    required this.holes,
    required this.color,
    required this.blurSigma,
    this.pulse,
    this.pulseColor = const Color(0xFFFFFFFF),
  });

  final List<SpotlightHole> holes;
  final Color color;
  final double blurSigma;

  /// 0→1 pulse phase; null disables the pulse ring.
  final double? pulse;
  final Color pulseColor;

  @override
  Widget build(BuildContext context) {
    Widget dim;
    if (blurSigma > 0.01) {
      dim = ClipPath(
        clipper: _InverseHolesClipper(holes),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: ColoredBox(color: color),
        ),
      );
    } else {
      dim = CustomPaint(
        size: Size.infinite,
        painter: _DimPainter(holes, color),
      );
    }
    final pulse = this.pulse;
    if (pulse != null && holes.isNotEmpty) {
      dim = Stack(
        fit: StackFit.expand,
        children: [
          dim,
          CustomPaint(painter: _PulsePainter(holes, pulse, pulseColor)),
        ],
      );
    }
    return IgnorePointer(child: dim);
  }
}

Path _inversePath(Size size, List<SpotlightHole> holes) {
  final full = Path()..addRect(Offset.zero & size);
  if (holes.isEmpty) return full;
  var cut = holes.first.path;
  for (final hole in holes.skip(1)) {
    cut = Path.combine(PathOperation.union, cut, hole.path);
  }
  return Path.combine(PathOperation.difference, full, cut);
}

class _InverseHolesClipper extends CustomClipper<Path> {
  _InverseHolesClipper(this.holes);

  final List<SpotlightHole> holes;

  @override
  Path getClip(Size size) => _inversePath(size, holes);

  @override
  bool shouldReclip(_InverseHolesClipper oldClipper) =>
      !_sameHoles(oldClipper.holes, holes);
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.holes, this.color);

  final List<SpotlightHole> holes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_inversePath(size, holes), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.color != color || !_sameHoles(old.holes, holes);
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.holes, this.t, this.color);

  final List<SpotlightHole> holes;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: (1 - t) * 0.8);
    final grow = 14 * t;
    for (final hole in holes) {
      if (hole.rrect != null) {
        canvas.drawRRect(hole.rrect!.inflate(grow), paint);
      } else {
        final b = hole.bounds;
        final scale = b.isEmpty ? 1.0 : (b.width + grow * 2) / b.width;
        canvas.save();
        canvas.translate(b.center.dx, b.center.dy);
        canvas.scale(scale);
        canvas.translate(-b.center.dx, -b.center.dy);
        canvas.drawPath(hole.path, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.t != t || old.color != color || !_sameHoles(old.holes, holes);
}

bool _sameHoles(List<SpotlightHole> a, List<SpotlightHole> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].rrect != b[i].rrect ||
        a[i].customPath != b[i].customPath ||
        a[i].bounds != b[i].bounds) {
      return false;
    }
  }
  return true;
}

/// Lets taps inside interactive holes fall through to the app, absorbs taps
/// on the dimmed area when [absorbOutside] is true, and keeps its children
/// (content, skip button) hittable.
class HoleHitTest extends SingleChildRenderObjectWidget {
  const HoleHitTest({
    super.key,
    required this.holes,
    required this.absorbOutside,
    required this.absorbHoles,
    super.child,
  });

  final List<SpotlightHole> holes;
  final bool absorbOutside;

  /// Absorb taps inside holes regardless of `SpotlightHole.interactive`
  /// (used while the overlay is animating).
  final bool absorbHoles;

  @override
  RenderHoleHitTest createRenderObject(BuildContext context) =>
      RenderHoleHitTest(holes, absorbOutside, absorbHoles);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHoleHitTest renderObject,
  ) {
    renderObject
      ..holes = holes
      ..absorbOutside = absorbOutside
      ..absorbHoles = absorbHoles;
  }
}

class RenderHoleHitTest extends RenderProxyBox {
  RenderHoleHitTest(this.holes, this.absorbOutside, this.absorbHoles);

  List<SpotlightHole> holes;
  bool absorbOutside;
  bool absorbHoles;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    for (final hole in holes) {
      if (hole.contains(position)) {
        if (hole.interactive && !absorbHoles) return false;
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    if (absorbOutside) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
