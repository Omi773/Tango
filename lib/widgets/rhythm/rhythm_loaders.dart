import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';

/// Indeterminate wavy line loader (Rhythm's WavyProgressLoader).
class RhythmWavyLoader extends StatefulWidget {
  const RhythmWavyLoader({
    super.key,
    this.width,
    this.height = 14,
    this.color,
    this.trackColor,
    this.strokeWidth = 4,
  });

  final double? width;
  final double height;
  final Color? color;
  final Color? trackColor;
  final double strokeWidth;

  @override
  State<RhythmWavyLoader> createState() => _RhythmWavyLoaderState();
}

class _RhythmWavyLoaderState extends State<RhythmWavyLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _WavyLoaderPainter(
            phase: _c.value,
            color: widget.color ?? scheme.primary,
            track: widget.trackColor ?? scheme.surfaceContainerHighest,
            stroke: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _WavyLoaderPainter extends CustomPainter {
  _WavyLoaderPainter({
    required this.phase,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double phase;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final amp = (size.height - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(stroke / 2, mid), Offset(size.width - stroke / 2, mid), trackPaint);

    // A moving window of the wave.
    final windowLen = size.width * 0.45;
    final start = (size.width + windowLen) * phase - windowLen;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    var first = true;
    final from = math.max(stroke / 2, start);
    final to = math.min(size.width - stroke / 2, start + windowLen);
    for (var x = from; x <= to; x += 1) {
      final edge = math.min((x - start) / 18, (start + windowLen - x) / 18).clamp(0.0, 1.0);
      final y = mid + math.sin((x / 16) - phase * 6.283185307 * 2) * amp * edge;
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    if (!first) canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavyLoaderPainter old) =>
      old.phase != phase || old.color != color || old.track != track;
}

/// Spinning, morphing cookie used as the main loading indicator.
class RhythmLoadingIndicator extends StatefulWidget {
  const RhythmLoadingIndicator({super.key, this.size = 48, this.color});

  final double size;
  final Color? color;

  @override
  State<RhythmLoadingIndicator> createState() => _RhythmLoadingIndicatorState();
}

class _RhythmLoadingIndicatorState extends State<RhythmLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const presets = [
      RhythmShapePreset.cookie9,
      RhythmShapePreset.cookie6,
      RhythmShapePreset.sunny,
      RhythmShapePreset.cookie12,
    ];
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final step = (_c.value * presets.length).floor() % presets.length;
        final pulse = 0.88 + 0.12 * math.sin(_c.value * math.pi * 2 * presets.length).abs();
        return Transform.scale(
          scale: pulse,
          child: RhythmCookie(
            size: widget.size,
            color: widget.color ?? scheme.primary,
            preset: presets[step],
            rotation: _c.value * math.pi * 2,
          ),
        );
      },
    );
  }
}

/// Full-area centred loader with optional message.
class RhythmLoadingView extends StatelessWidget {
  const RhythmLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RhythmLoadingIndicator(),
          if (message != null) ...[
            const SizedBox(height: 20),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
