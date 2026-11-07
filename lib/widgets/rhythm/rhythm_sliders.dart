import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';
import 'package:tango/widgets/rhythm/rhythm_ui.dart';

/// Rhythm's CookieHorizontalSlider: a pill track whose thumb is a spinning
/// cookie shape.
class RhythmCookieSlider extends StatefulWidget {
  const RhythmCookieSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.preset = RhythmShapePreset.cookie9,
    this.height = 40,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final RhythmShapePreset preset;
  final double height;

  @override
  State<RhythmCookieSlider> createState() => _RhythmCookieSliderState();
}

class _RhythmCookieSliderState extends State<RhythmCookieSlider> {
  bool _dragging = false;

  double _fraction() {
    final span = widget.max - widget.min;
    if (span <= 0) return 0;
    return ((widget.value - widget.min) / span).clamp(0.0, 1.0);
  }

  void _update(Offset local, double width) {
    final f = (local.dx / width).clamp(0.0, 1.0);
    widget.onChanged(widget.min + f * (widget.max - widget.min));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            setState(() => _dragging = true);
            HapticFeedback.selectionClick();
            _update(d.localPosition, width);
          },
          onHorizontalDragUpdate: (d) => _update(d.localPosition, width),
          onHorizontalDragEnd: (_) {
            setState(() => _dragging = false);
            widget.onChangeEnd?.call(widget.value);
          },
          onTapDown: (d) => _update(d.localPosition, width),
          onTapUp: (_) => widget.onChangeEnd?.call(widget.value),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _fraction()),
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              builder: (context, f, _) => CustomPaint(
                painter: _CookieSliderPainter(
                  fraction: f,
                  preset: widget.preset,
                  track: scheme.surfaceContainerHighest,
                  active: scheme.primary,
                  thumb: scheme.primary,
                  thumbSize: _dragging ? widget.height : widget.height * 0.8,
                  rotation: f * 6.2831853 * 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CookieSliderPainter extends CustomPainter {
  _CookieSliderPainter({
    required this.fraction,
    required this.preset,
    required this.track,
    required this.active,
    required this.thumb,
    required this.thumbSize,
    required this.rotation,
  });

  final double fraction;
  final RhythmShapePreset preset;
  final Color track;
  final Color active;
  final Color thumb;
  final double thumbSize;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const trackH = 12.0;
    final half = thumbSize / 2;
    final cx = half + (size.width - thumbSize) * fraction;
    final r = const Radius.circular(trackH / 2);

    canvas.drawRRect(
      RRect.fromLTRBR(0, cy - trackH / 2, size.width, cy + trackH / 2, r),
      Paint()..color = track,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(0, cy - trackH / 2, cx, cy + trackH / 2, r),
      Paint()..color = active,
    );
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: thumbSize,
      height: thumbSize,
    );
    final path = preset.border(rotation: rotation).getOuterPath(rect);
    canvas.drawPath(path, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_CookieSliderPainter old) =>
      old.fraction != fraction ||
      old.thumbSize != thumbSize ||
      old.track != track ||
      old.active != active ||
      old.preset != preset;
}

/// Rhythm's tooltip: rounded inverse-surface bubble.
class RhythmTooltip extends StatelessWidget {
  const RhythmTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: message,
      preferBelow: false,
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: child,
    );
  }
}

/// Rhythm's guard card: a status card with a cookie icon, title, supporting
/// text and an optional switch (used for protective / safety options).
class RhythmGuardCard extends StatelessWidget {
  const RhythmGuardCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.shield_rounded,
    this.value,
    this.onChanged,
    this.tone = RhythmMenuTone.primary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final RhythmMenuTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final on = value ?? true;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: on ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          RhythmCookieIcon(
            icon: icon,
            size: 52,
            color: on ? scheme.primary : scheme.surfaceContainerHighest,
            iconColor: on ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: on ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: on
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onChanged != null && value != null)
            Switch(value: value!, onChanged: onChanged),
        ],
      ),
    );
  }
}
