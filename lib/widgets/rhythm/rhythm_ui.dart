import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/app_icon.dart';

/// Rhythm UI kit: widgets ported from the Kotlin app's shared components
/// (RhythmGroupedMenu, StandardBottomSheetHeader, MorphingPlayPauseButton,
/// PlayingEqIcon, ShimmerBox, AnimatedDigitTickerText).

/// Rhythm's grouped row shape: big outer corners, small inner corners.
BorderRadius rhythmGroupedRadius(
  int index,
  int count, {
  double outer = 16,
  double inner = 4,
}) {
  final big = Radius.circular(outer);
  final small = Radius.circular(inner);
  if (count <= 1) return BorderRadius.all(big);
  if (index == 0) {
    return BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: small,
      bottomRight: small,
    );
  }
  if (index == count - 1) {
    return BorderRadius.only(
      topLeft: small,
      topRight: small,
      bottomLeft: big,
      bottomRight: big,
    );
  }
  return BorderRadius.all(small);
}

/// Icon circle colours of a [RhythmMenuItem], as in Rhythm's song menu:
/// actions use primary, navigation and info secondary, like tertiary and
/// anything destructive error.
enum RhythmMenuTone { primary, secondary, tertiary, error }

/// One row of a [RhythmGroupedMenu].
class RhythmMenuItem {
  const RhythmMenuItem({
    required this.title,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.subtitle,
    this.tone = RhythmMenuTone.primary,
    this.iconContainerColor,
    this.iconTint,
    this.isDestructive = false,
    this.selected = false,
  });

  final String title;

  /// Null disables the row.
  final VoidCallback? onTap;

  /// Glyph drawn in the circle. [iconWidget] wins when both are set; with
  /// neither, the row shows no circle.
  final IconData? icon;
  final Widget? iconWidget;
  final String? subtitle;
  final RhythmMenuTone tone;
  final Color? iconContainerColor;
  final Color? iconTint;
  final bool isDestructive;

  /// Single-select menus: the chosen row shows a check.
  final bool selected;
}

/// Rhythm's popup menu body: rows with a 28px tinted icon circle, 16px outer
/// and 4px inner corners, 3px between rows.
class RhythmGroupedMenu extends StatelessWidget {
  const RhythmGroupedMenu({super.key, required this.items});

  final List<RhythmMenuItem> items;

  static (Color, Color) _colors(ColorScheme scheme, RhythmMenuItem item) {
    final tone = item.isDestructive ? RhythmMenuTone.error : item.tone;
    final (container, tint) = switch (tone) {
      RhythmMenuTone.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      RhythmMenuTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      RhythmMenuTone.tertiary => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      RhythmMenuTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return (
      item.iconContainerColor ?? container.withValues(alpha: 0.6),
      item.iconTint ?? tint,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 3),
              child: _row(context, scheme, text, items[i], i),
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ColorScheme scheme,
    TextTheme text,
    RhythmMenuItem item,
    int index,
  ) {
    final (circle, tint) = _colors(scheme, item);
    final enabled = item.onTap != null;
    final glyph = item.iconWidget != null
        ? IconTheme.merge(
            data: IconThemeData(size: 16, color: tint),
            child: item.iconWidget!,
          )
        : item.icon != null
        ? AppIcon(item.icon, size: 16, color: tint)
        : null;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: item.selected,
        child: Material(
          color: scheme.surfaceContainer,
          borderRadius: rhythmGroupedRadius(index, items.length),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.mediumImpact();
                    item.onTap!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (glyph != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circle,
                      ),
                      child: glyph,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: item.selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: item.isDestructive
                                ? scheme.error
                                : scheme.onSurface,
                          ),
                        ),
                        if (item.subtitle != null && item.subtitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.subtitle!,
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (item.selected) ...[
                    const SizedBox(width: 8),
                    AppIcon(Icons.check, size: 18, color: scheme.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rhythm's bottom sheet header: large title with a subtitle pill.
class RhythmSheetHeader extends StatelessWidget {
  const RhythmSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.displayMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          subtitle!,
                          style: text.labelLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Play/pause button whose circle morphs into a 9-sided cookie and spins
/// while playing (Rhythm's MorphingPlayPauseButton).
class RhythmMorphPlayPauseButton extends StatefulWidget {
  const RhythmMorphPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 56,
    this.isLoading = false,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;
  final bool isLoading;

  @override
  State<RhythmMorphPlayPauseButton> createState() =>
      _RhythmMorphPlayPauseButtonState();
}

class _RhythmMorphPlayPauseButtonState extends State<RhythmMorphPlayPauseButton>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController.unbounded(
    vsync: this,
    value: widget.isPlaying ? 1 : 0,
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  );
  bool _pressed = false;
  bool _motion = true;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 120,
    ratio: 0.55,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = !MediaQuery.disableAnimationsOf(context);
    _syncSpin();
  }

  @override
  void didUpdateWidget(RhythmMorphPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      final target = widget.isPlaying ? 1.0 : 0.0;
      if (_motion) {
        _morph.animateWith(
          SpringSimulation(_spring, _morph.value, target, _morph.velocity),
        );
      } else {
        _morph.value = target;
      }
      _syncSpin();
    }
  }

  void _syncSpin() {
    if (_motion && widget.isPlaying) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;
    return Semantics(
      button: true,
      label: widget.isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: SizedBox.square(
            dimension: size,
            child: widget.isLoading
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                    ),
                    child: Center(
                      child: SizedBox.square(
                        dimension: size * 0.42,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.onPrimary,
                          backgroundColor: scheme.onPrimary.withValues(
                            alpha: 0.24,
                          ),
                        ),
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: _CookiePainter(
                            morph: _morph,
                            spin: _spin,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.fastOutSlowIn,
                        child: Icon(
                          widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey<bool>(widget.isPlaying),
                          size: size * 0.5,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CookiePainter extends CustomPainter {
  _CookiePainter({
    required this.morph,
    required this.spin,
    required this.color,
  }) : super(repaint: Listenable.merge([morph, spin]));

  final AnimationController morph;
  final AnimationController spin;
  final Color color;

  static const int _lobes = 9;
  static const double _depth = 0.075;
  static const int _samples = 180;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = morph.value.clamp(-0.2, 1.3);
    final amp = _depth * progress;
    final radius = size.shortestSide / 2 / (1 + _depth);
    final center = size.center(Offset.zero);
    final angle = spin.value * 2 * math.pi;
    final path = Path();
    for (var i = 0; i <= _samples; i++) {
      final t = i / _samples * 2 * math.pi;
      final r = radius * (1 + amp * math.cos(_lobes * t));
      final x = center.dx + r * math.cos(t + angle);
      final y = center.dy + r * math.sin(t + angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CookiePainter old) => old.color != color;
}

/// Three animated bars that mark the playing track (Rhythm's PlayingEqIcon).
/// When [isPlaying] turns false the bars settle into dots.
class RhythmEqIcon extends StatefulWidget {
  const RhythmEqIcon({
    super.key,
    this.color,
    this.isPlaying = true,
    this.size = 16,
    this.bars = 3,
    this.minHeightFraction = 0.28,
    this.maxHeightFraction = 1.0,
    this.gapFraction = 0.30,
  });

  /// Bar color. Defaults to [ColorScheme.onPrimaryContainer].
  final Color? color;
  final bool isPlaying;
  final double size;
  final int bars;
  final double minHeightFraction;
  final double maxHeightFraction;
  final double gapFraction;

  @override
  State<RhythmEqIcon> createState() => _RhythmEqIconState();
}

class _RhythmEqIconState extends State<RhythmEqIcon>
    with SingleTickerProviderStateMixin {
  // 24 s holds a whole number of both loops (2.4 s phase, 8 s wander).
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (motion) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor =
        widget.color ?? Theme.of(context).colorScheme.onPrimaryContainer;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.isPlaying ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 240),
        curve: Curves.fastOutSlowIn,
        builder: (context, activity, _) => RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _EqPainter(
              clock: _clock,
              activity: activity,
              color: barColor,
              bars: widget.bars,
              minFraction: widget.minHeightFraction,
              maxFraction: widget.maxHeightFraction,
              gapFraction: widget.gapFraction,
            ),
          ),
        ),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  _EqPainter({
    required this.clock,
    required this.activity,
    required this.color,
    required this.bars,
    required this.minFraction,
    required this.maxFraction,
    required this.gapFraction,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final double activity;
  final Color color;
  final int bars;
  final double minFraction;
  final double maxFraction;
  final double gapFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = clock.value * 10 * 2 * math.pi;
    final wander = clock.value * 3 * 2 * math.pi;
    final w = size.width;
    final h = size.height;
    final barW = w / (bars + (bars - 1) * (1 + gapFraction));
    final gap = barW * gapFraction;
    final paint = Paint()..color = color;
    for (var i = 0; i < bars; i++) {
      final speed = (i + 1).toDouble();
      final shift = i * 0.9;
      final slowShift = 0.6 * math.sin(wander + i * 0.4);
      final slowAmp = 0.85 + 0.15 * math.sin(wander * 0.5 + 1.1 + i * 0.3);
      final v = (math.sin(phase * speed + shift + slowShift) * slowAmp + 1) * 0.5;
      final eased = v * v * (3 - 2 * v);
      final frac = minFraction + (maxFraction - minFraction) * eased;
      final barH = h * frac;
      final blended = barW + (barH - barW) * activity;
      final top = (h - blended) / 2;
      final left = i * (barW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barW, blended),
          Radius.circular(barW / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqPainter old) =>
      old.activity != activity || old.color != color || old.bars != bars;
}

/// Loading placeholder with Rhythm's diagonal shimmer sweep.
class RhythmShimmerBox extends StatefulWidget {
  const RhythmShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.colors,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final List<Color>? colors;

  @override
  State<RhythmShimmerBox> createState() => _RhythmShimmerBoxState();
}

class _RhythmShimmerBoxState extends State<RhythmShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (motion) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final colors =
        widget.colors ??
        [
          base.withValues(alpha: 0.6),
          base.withValues(alpha: 0.2),
          base.withValues(alpha: 0.6),
        ];
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ShimmerPainter(progress: _c, colors: colors),
          ),
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.progress, required this.colors})
    : super(repaint: progress);

  final Animation<double> progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    // 300 ms rest, then a 1200 ms sweep from 0 to 1000 px.
    final t = ((progress.value - 0.2) / 0.8).clamp(0.0, 1.0);
    final x = math.max(Curves.fastOutSlowIn.transform(t) * 1000, 0.001);
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(x, x), colors);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.colors != colors;
}

/// Numbers whose digits roll up or down when they change
/// (Rhythm's AnimatedDigitTickerText).
class RhythmDigitTicker extends StatelessWidget {
  const RhythmDigitTicker({
    super.key,
    required this.text,
    this.style,
    this.color,
    this.fontWeight = FontWeight.bold,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final base =
        style ?? Theme.of(context).textTheme.titleLarge ?? const TextStyle();
    final resolved = base.copyWith(
      fontWeight: fontWeight,
      color: color ?? base.color,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < text.length; i++)
          _TickerChar(char: text[i], style: resolved),
      ],
    );
  }
}

class _TickerChar extends StatefulWidget {
  const _TickerChar({required this.char, required this.style});

  final String char;
  final TextStyle? style;

  @override
  State<_TickerChar> createState() => _TickerCharState();
}

class _TickerCharState extends State<_TickerChar> {
  double _dy = 0.5;

  @override
  void didUpdateWidget(_TickerChar old) {
    super.didUpdateWidget(old);
    final a = int.tryParse(old.char);
    final b = int.tryParse(widget.char);
    if (a != null && b != null) _dy = b > a ? 0.5 : -0.5;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey<String>(widget.char);
        final offset = Tween<Offset>(
          begin: Offset(0, incoming ? _dy : -_dy),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        widget.char,
        key: ValueKey<String>(widget.char),
        style: widget.style,
        softWrap: false,
      ),
    );
  }
}


/// Rhythm's tinted icon circle used in settings rows, menus and list rows.
/// [index] picks a tone so neighbouring rows alternate colors the way
/// Rhythm's grouped settings do.
class RhythmIconCircle extends StatelessWidget {
  const RhythmIconCircle({
    super.key,
    required this.icon,
    this.tone = RhythmMenuTone.primary,
    this.size = 40,
    this.iconSize = 22,
    this.enabled = true,
  });

  final IconData icon;
  final RhythmMenuTone tone;
  final double size;
  final double iconSize;
  final bool enabled;

  static RhythmMenuTone toneFor(int index) =>
      RhythmMenuTone.values[index.abs() % 3];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (tone) {
      RhythmMenuTone.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      RhythmMenuTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      RhythmMenuTone.tertiary => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      RhythmMenuTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: AppIcon(icon, size: iconSize, color: fg),
      ),
    );
  }
}

/// Rhythm's round drag handle for reorderable rows.
class RhythmDragHandle extends StatelessWidget {
  const RhythmDragHandle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppIcon(
        Icons.drag_handle,
        size: 22,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// Fades the top and/or bottom edge of a scrolling child to transparent
/// (Rhythm's scroll-fade edges on sheets, queue and lyrics).
class RhythmEdgeFade extends StatelessWidget {
  const RhythmEdgeFade({
    super.key,
    required this.child,
    this.top = 24,
    this.bottom = 24,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    if (top <= 0 && bottom <= 0) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final h = rect.height <= 0 ? 1.0 : rect.height;
        final t = (top / h).clamp(0.0, 0.5);
        final b = (bottom / h).clamp(0.0, 0.5);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, t, 1 - b, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

/// Light tick used by Rhythm controls.
void rhythmTick() => HapticFeedback.selectionClick();
