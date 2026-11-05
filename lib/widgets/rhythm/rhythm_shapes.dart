import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scalloped "cookie" outline (Rhythm's COOKIE_* expressive shapes).
///
/// [bumps] is the number of lobes, [depth] how deep the valleys cut in
/// (0 = circle, 0.1 = strong scallops) and [rotation] rotates the outline.
Path rhythmCookiePath(
  Rect rect, {
  int bumps = 12,
  double depth = 0.05,
  double rotation = 0,
}) {
  final center = rect.center;
  final radius = math.min(rect.width, rect.height) / 2;
  final path = Path();
  const steps = 240;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps * 2 * math.pi;
    final r = radius * (1 - depth + depth * math.cos(bumps * t));
    final x = center.dx + r * math.cos(t + rotation);
    final y = center.dy + r * math.sin(t + rotation);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

/// Named presets mirroring Rhythm's shape set.
enum RhythmShapePreset {
  cookie4(4, 0.09),
  cookie6(6, 0.07),
  cookie7(7, 0.065),
  cookie9(9, 0.06),
  cookie12(12, 0.05),
  sunny(8, 0.1),
  circle(1, 0);

  const RhythmShapePreset(this.bumps, this.depth);

  final int bumps;
  final double depth;

  RhythmCookieBorder border({double rotation = 0}) =>
      RhythmCookieBorder(bumps: bumps, depth: depth, rotation: rotation);
}

/// A [ShapeBorder] drawing a cookie outline. Works with [Material],
/// [ShapeDecoration], [ClipPath] (via [ShapeBorderClipper]) and `Surface`s.
class RhythmCookieBorder extends ShapeBorder {
  const RhythmCookieBorder({
    this.bumps = 12,
    this.depth = 0.05,
    this.rotation = 0,
  });

  final int bumps;
  final double depth;
  final double rotation;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      rhythmCookiePath(rect, bumps: bumps, depth: depth, rotation: rotation);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is RhythmCookieBorder) {
      return RhythmCookieBorder(
        bumps: t < 0.5 ? bumps : b.bumps,
        depth: lerpDouble(depth, b.depth, t),
        rotation: lerpDouble(rotation, b.rotation, t),
      );
    }
    return super.lerpTo(b, t);
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// A filled, clipped cookie with optional centred [child].
class RhythmCookie extends StatelessWidget {
  const RhythmCookie({
    super.key,
    required this.size,
    this.color,
    this.preset = RhythmShapePreset.cookie12,
    this.rotation = 0,
    this.elevation = 0,
    this.child,
  });

  final double size;
  final Color? color;
  final RhythmShapePreset preset;
  final double rotation;
  final double elevation;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: color ?? scheme.primaryContainer,
        elevation: elevation,
        shadowColor: scheme.shadow,
        shape: preset.border(rotation: rotation),
        clipBehavior: Clip.antiAlias,
        child: Center(child: child),
      ),
    );
  }
}

/// An icon centred in a [RhythmCookie].
class RhythmCookieIcon extends StatelessWidget {
  const RhythmCookieIcon({
    super.key,
    required this.icon,
    this.size = 56,
    this.iconSize,
    this.color,
    this.iconColor,
    this.preset = RhythmShapePreset.cookie9,
    this.rotation = 0,
  });

  final IconData icon;
  final double size;
  final double? iconSize;
  final Color? color;
  final Color? iconColor;
  final RhythmShapePreset preset;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RhythmCookie(
      size: size,
      color: color ?? scheme.primaryContainer,
      preset: preset,
      rotation: rotation,
      child: Icon(
        icon,
        size: iconSize ?? size * 0.46,
        color: iconColor ?? scheme.onPrimaryContainer,
      ),
    );
  }
}

/// Backdrop of soft cookie blobs, used behind hero headers (Rhythm's
/// BackdropShapes).
class RhythmBackdropShapes extends StatelessWidget {
  const RhythmBackdropShapes({super.key, this.color, this.opacity = 0.12});

  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.primary;
    Widget blob(double size, RhythmShapePreset p, double rot) => RhythmCookie(
      size: size,
      color: base.withValues(alpha: opacity),
      preset: p,
      rotation: rot,
    );
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: blob(180, RhythmShapePreset.cookie9, 0.3),
          ),
          Positioned(
            top: 90,
            left: -50,
            child: blob(130, RhythmShapePreset.cookie6, 0.9),
          ),
          Positioned(
            bottom: -30,
            right: 40,
            child: blob(100, RhythmShapePreset.sunny, 0.1),
          ),
        ],
      ),
    );
  }
}
