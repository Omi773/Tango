import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tango/widgets/rhythm/rhythm_ui.dart';

// ---------------------------------------------------------------------------
// Progress style (Rhythm's ProgressStyle: wavy line, arc, cookie thumb)
// ---------------------------------------------------------------------------

enum RhythmProgressStyle { wavy, arc, cookie }

const _progressStyleKey = 'rhythm_progress_style';

final rhythmProgressStyleProvider =
    NotifierProvider<RhythmProgressStyleNotifier, RhythmProgressStyle>(
      RhythmProgressStyleNotifier.new,
    );

class RhythmProgressStyleNotifier extends Notifier<RhythmProgressStyle> {
  @override
  RhythmProgressStyle build() {
    _load();
    return RhythmProgressStyle.wavy;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_progressStyleKey);
      for (final style in RhythmProgressStyle.values) {
        if (style.name == name && ref.mounted) {
          state = style;
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> set(RhythmProgressStyle style) async {
    state = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_progressStyleKey, style.name);
    } catch (_) {}
  }
}

/// Segmented picker used on the Appearance page.
class RhythmProgressStyleSelector extends ConsumerWidget {
  const RhythmProgressStyleSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(rhythmProgressStyleProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<RhythmProgressStyle>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: RhythmProgressStyle.wavy,
              label: Text('Wavy'),
              icon: Icon(Icons.waves_rounded),
            ),
            ButtonSegment(
              value: RhythmProgressStyle.arc,
              label: Text('Arc'),
              icon: Icon(Icons.radar_rounded),
            ),
            ButtonSegment(
              value: RhythmProgressStyle.cookie,
              label: Text('Cookie'),
              icon: Icon(Icons.cookie_rounded),
            ),
          ],
          selected: {style},
          onSelectionChanged: (value) {
            HapticFeedback.selectionClick();
            ref.read(rhythmProgressStyleProvider.notifier).set(value.first);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress slider
// ---------------------------------------------------------------------------

/// Seek slider in Rhythm's three looks. `value` and `max` use the same unit
/// (milliseconds for playback). The parent keeps the scrub preview, so the
/// slider only reports gestures.
class RhythmProgressSlider extends StatefulWidget {
  const RhythmProgressSlider({
    super.key,
    required this.value,
    required this.max,
    required this.style,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.playing = false,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  final double value;
  final double max;
  final RhythmProgressStyle style;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final bool playing;
  final bool enabled;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  @override
  State<RhythmProgressSlider> createState() => _RhythmProgressSliderState();
}

class _RhythmProgressSliderState extends State<RhythmProgressSlider>
    with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _amp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 240),
  );

  bool _dragging = false;
  double _last = 0;
  Size _box = const Size(1, 1);

  static const double _wavyPad = 12;
  static const double _cookiePill = 32;
  static const double _arcThumb = 18;
  static const double _arcStart = 135;
  static const double _arcSweep = 270;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RhythmProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final motion = !MediaQuery.disableAnimationsOf(context);
    final waves = widget.style != RhythmProgressStyle.cookie;
    final run = waves && widget.playing && widget.enabled && motion;
    if (run) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
    }
    final target = (widget.playing && widget.enabled && !_dragging) ? 1.0 : 0.0;
    _amp.animateTo(target, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _wave.dispose();
    _amp.dispose();
    _press.dispose();
    super.dispose();
  }

  double get _normalized => widget.max <= 0
      ? 0
      : (widget.value / widget.max).clamp(0.0, 1.0).toDouble();

  double _toValue(Offset local) {
    if (widget.style == RhythmProgressStyle.arc) {
      final center = Offset(_box.width / 2, _box.height / 2);
      var angle =
          math.atan2(local.dy - center.dy, local.dx - center.dx) * 180 / math.pi;
      if (angle < 0) angle += 360;
      var relative = angle - _arcStart;
      if (relative < 0) relative += 360;
      if (relative > _arcSweep) {
        final halfDead = (360 - _arcSweep) / 2;
        relative = relative < _arcSweep + halfDead ? _arcSweep : 0;
      }
      return (relative / _arcSweep).clamp(0.0, 1.0) * widget.max;
    }
    final pad = widget.style == RhythmProgressStyle.cookie
        ? _cookiePill / 2
        : _wavyPad;
    final usable = math.max(1.0, _box.width - pad * 2);
    return ((local.dx - pad) / usable).clamp(0.0, 1.0) * widget.max;
  }

  void _begin(Offset local) {
    if (!widget.enabled || widget.max <= 0) return;
    _dragging = true;
    _press.forward();
    _sync();
    _last = _toValue(local);
    widget.onChangeStart(_last);
    widget.onChanged(_last);
    HapticFeedback.selectionClick();
  }

  void _update(Offset local) {
    if (!_dragging) return;
    _last = _toValue(local);
    widget.onChanged(_last);
  }

  void _finish() {
    if (!_dragging) return;
    _dragging = false;
    _press.reverse();
    _sync();
    widget.onChangeEnd(_last);
  }

  void _tap(Offset local) {
    _begin(local);
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? scheme.primary;
    final inactive = widget.inactiveColor ?? scheme.secondaryContainer;
    final thumb = widget.thumbColor ?? scheme.primary;
    final arc = widget.style == RhythmProgressStyle.arc;
    final height = switch (widget.style) {
      RhythmProgressStyle.arc => 190.0,
      RhythmProgressStyle.cookie => 44.0,
      RhythmProgressStyle.wavy => 40.0,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        _box = Size(constraints.maxWidth, height);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _tap(d.localPosition),
            onHorizontalDragStart: arc
                ? null
                : (d) => _begin(d.localPosition),
            onHorizontalDragUpdate: arc
                ? null
                : (d) => _update(d.localPosition),
            onHorizontalDragEnd: arc ? null : (_) => _finish(),
            onHorizontalDragCancel: arc ? null : _finish,
            onPanStart: arc ? (d) => _begin(d.localPosition) : null,
            onPanUpdate: arc ? (d) => _update(d.localPosition) : null,
            onPanEnd: arc ? (_) => _finish() : null,
            onPanCancel: arc ? _finish : null,
            child: AnimatedBuilder(
              animation: Listenable.merge([_wave, _amp, _press]),
              builder: (context, _) => CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: switch (widget.style) {
                  RhythmProgressStyle.wavy => _WavyPainter(
                    progress: _normalized,
                    phase: _wave.value,
                    amplitude: _amp.value,
                    press: _press.value,
                    active: active,
                    inactive: inactive,
                    thumb: thumb,
                    enabled: widget.enabled,
                  ),
                  RhythmProgressStyle.arc => _ArcPainter(
                    progress: _normalized,
                    phase: _wave.value,
                    amplitude: _amp.value,
                    press: _press.value,
                    active: active,
                    inactive: inactive,
                    thumb: thumb,
                    enabled: widget.enabled,
                  ),
                  RhythmProgressStyle.cookie => _CookiePainter(
                    progress: _normalized,
                    press: _press.value,
                    active: active,
                    inactive: inactive,
                    thumb: scheme.surface,
                    enabled: widget.enabled,
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

class _WavyPainter extends CustomPainter {
  _WavyPainter({
    required this.progress,
    required this.phase,
    required this.amplitude,
    required this.press,
    required this.active,
    required this.inactive,
    required this.thumb,
    required this.enabled,
  });

  final double progress;
  final double phase;
  final double amplitude;
  final double press;
  final Color active;
  final Color inactive;
  final Color thumb;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = _RhythmProgressSliderState._wavyPad;
    const strokeWidth = 5.0;
    const wavelength = 40.0;
    final cy = size.height / 2;
    final startX = pad;
    final endX = size.width - pad;
    final thumbX = startX + (endX - startX) * progress;
    final thumbW = lerpDouble(16, 6, press)!;
    final thumbH = lerpDouble(16, 28, press)!;
    final gap = 8 + thumbW / 2;
    final color = enabled ? active : active.withValues(alpha: 0.4);

    if (thumbX + gap < endX) {
      canvas.drawLine(
        Offset(thumbX + gap, cy),
        Offset(endX, cy),
        _stroke(inactive, strokeWidth),
      );
    }
    final activeEnd = thumbX - gap;
    if (activeEnd > startX) {
      final amp = 4.0 * amplitude;
      final path = Path()..moveTo(startX, cy);
      for (var x = startX; x <= activeEnd; x += 1.5) {
        // Ease the wave in from the left end so the cap stays round.
        final ease = ((x - startX) / 14).clamp(0.0, 1.0);
        final y =
            cy +
            amp *
                ease *
                math.sin((x - startX) / wavelength * 2 * math.pi - phase * 2 * math.pi);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, _stroke(color, strokeWidth));
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(thumbX, cy),
          width: thumbW,
          height: thumbH,
        ),
        Radius.circular(thumbW / 2),
      ),
      Paint()..color = enabled ? thumb : thumb.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_WavyPainter old) => true;
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.phase,
    required this.amplitude,
    required this.press,
    required this.active,
    required this.inactive,
    required this.thumb,
    required this.enabled,
  });

  final double progress;
  final double phase;
  final double amplitude;
  final double press;
  final Color active;
  final Color inactive;
  final Color thumb;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    const trackWidth = 4.0;
    const waveAmp = 2.0;
    const waveLength = 20.0;
    const thumbSize = _RhythmProgressSliderState._arcThumb;
    final minDim = math.min(size.width, size.height);
    final radius = (minDim - thumbSize * 2 - waveAmp * 2) / 2;
    if (radius <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    const start = _RhythmProgressSliderState._arcStart;
    const sweep = _RhythmProgressSliderState._arcSweep;
    final activeSweep = sweep * progress;
    final thumbScale = 1 + 0.25 * press;
    final gapPx = thumbSize / 2 * thumbScale + 6 + trackWidth / 2;
    final gapDeg = gapPx / radius * 180 / math.pi;
    final inactiveStart = start + activeSweep + gapDeg;
    final inactiveSweep = sweep - activeSweep - gapDeg;
    final rect = Rect.fromCircle(center: center, radius: radius);
    if (inactiveSweep > 0) {
      canvas.drawArc(
        rect,
        inactiveStart * math.pi / 180,
        inactiveSweep * math.pi / 180,
        false,
        _stroke(inactive, trackWidth),
      );
    }
    if (activeSweep > 0) {
      final steps = math.max(10, (activeSweep * 2).toInt());
      final path = Path();
      for (var i = 0; i <= steps; i++) {
        final deg = i * activeSweep / steps;
        final angle = (start + deg) * math.pi / 180;
        final along = radius * deg * math.pi / 180;
        final k = 2 * math.pi / waveLength;
        final h = enabled
            ? waveAmp * amplitude * math.sin(k * along - phase * 2 * math.pi)
            : 0.0;
        final r = radius + h;
        final p = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        _stroke(enabled ? active : active.withValues(alpha: 0.4), trackWidth),
      );
    }
    final thumbAngle = (start + activeSweep) * math.pi / 180;
    canvas.drawCircle(
      Offset(
        center.dx + radius * math.cos(thumbAngle),
        center.dy + radius * math.sin(thumbAngle),
      ),
      thumbSize / 2 * thumbScale,
      Paint()..color = enabled ? thumb : thumb.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => true;
}

class _CookiePainter extends CustomPainter {
  _CookiePainter({
    required this.progress,
    required this.press,
    required this.active,
    required this.inactive,
    required this.thumb,
    required this.enabled,
  });

  final double progress;
  final double press;
  final Color active;
  final Color inactive;
  final Color thumb;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    const pill = _RhythmProgressSliderState._cookiePill;
    const pillRadius = pill / 2;
    final cy = size.height / 2;
    final top = cy - pillRadius;
    final usable = math.max(1.0, size.width - pill);
    final thumbX = pillRadius + usable * progress;
    final activeColor = enabled ? active : active.withValues(alpha: 0.4);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, pill),
        const Radius.circular(pillRadius),
      ),
      Paint()..color = inactive,
    );
    canvas.drawCircle(Offset(thumbX, cy), pillRadius, Paint()..color = activeColor);
    if (thumbX > 0) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, top, thumbX, pill),
          topLeft: const Radius.circular(pillRadius),
          bottomLeft: const Radius.circular(pillRadius),
        ),
        Paint()..color = activeColor,
      );
    }
    // Eight-sided cookie that turns as the track fills and swells on touch.
    const sides = 8;
    const curve = 0.1;
    final r = 30 * 0.42 * 0.95;
    final path = Path();
    for (var i = 0; i <= 180; i++) {
      final t = i / 180 * 2 * math.pi;
      final k = 1 + curve * math.cos(sides * t);
      final p = Offset(r * math.cos(t) * k, r * math.sin(t) * k);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.save();
    canvas.translate(thumbX, cy);
    canvas.rotate(progress * 2 * math.pi);
    final scale = 1 + 0.25 * press;
    canvas.scale(scale, scale);
    canvas.drawPath(path, Paint()..color = thumb);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CookiePainter old) => true;
}

// ---------------------------------------------------------------------------
// Time pill
// ---------------------------------------------------------------------------

class RhythmTimePill extends StatelessWidget {
  const RhythmTimePill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: RhythmDigitTicker(
          text: text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12),
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Control buttons
// ---------------------------------------------------------------------------

/// Round button that squishes into a rounded square while pressed
/// (Rhythm's RhythmControlButton).
class RhythmControlButton extends StatefulWidget {
  const RhythmControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 56,
    this.iconSize,
    this.containerColor,
    this.contentColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double? iconSize;
  final Color? containerColor;
  final Color? contentColor;

  @override
  State<RhythmControlButton> createState() => _RhythmControlButtonState();
}

class _RhythmControlButtonState extends State<RhythmControlButton> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final base = widget.containerColor ?? scheme.secondaryContainer;
    final content = widget.contentColor ?? scheme.onSecondaryContainer;
    final visual = _pressed && enabled;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 220);
    final half = widget.size / 2;
    Widget button = AnimatedScale(
      scale: visual ? 0.92 : 1,
      duration: duration,
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: visual ? Color.lerp(base, Colors.black, 0.18) : base,
          borderRadius: BorderRadius.circular(
            visual ? math.max(8.0, half - 16) : half,
          ),
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: widget.iconSize ?? widget.size * 0.5,
            color: enabled ? content : content.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
    button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) {
        // Hold the squish for a beat so quick taps still show the morph.
        Future<void>.delayed(const Duration(milliseconds: 120), () => _set(false));
      },
      onTapCancel: () => _set(false),
      onTap: enabled
          ? () {
              HapticFeedback.mediumImpact();
              widget.onPressed!();
            }
          : null,
      child: button,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip,
      excludeSemantics: true,
      child: widget.tooltip == null
          ? button
          : Tooltip(message: widget.tooltip!, child: button),
    );
  }
}

/// Shuffle, previous, the morphing play button, next, repeat.
class RhythmTransportRow extends StatelessWidget {
  const RhythmTransportRow({
    super.key,
    required this.playing,
    required this.loading,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
    this.leading,
    this.trailing,
    this.compact = false,
  });

  final bool playing;
  final bool loading;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String previousTooltip;
  final String nextTooltip;
  final Widget? leading;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttonSize = compact ? 48.0 : 56.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ?leading,
        RhythmControlButton(
          icon: Icons.skip_previous_rounded,
          tooltip: previousTooltip,
          size: buttonSize,
          iconSize: buttonSize * 0.55,
          onPressed: onPrevious,
        ),
        RhythmMorphPlayPauseButton(
          isPlaying: playing,
          isLoading: loading,
          size: compact ? 64 : 76,
          onPressed: onPlayPause,
        ),
        RhythmControlButton(
          icon: Icons.skip_next_rounded,
          tooltip: nextTooltip,
          size: buttonSize,
          iconSize: buttonSize * 0.55,
          onPressed: onNext,
        ),
        ?trailing,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Volume slider (inset icon, thin handle)
// ---------------------------------------------------------------------------

class RhythmVolumeSlider extends StatelessWidget {
  const RhythmVolumeSlider({
    super.key,
    required this.value,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.enabled = true,
  });

  final double value;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value.clamp(0.0, 1.0).toDouble();
    final icon = v <= 0
        ? Icons.volume_mute_rounded
        : v < 0.5
        ? Icons.volume_down_rounded
        : Icons.volume_up_rounded;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double at(Offset local) => (local.dx / width).clamp(0.0, 1.0).toDouble();
        final fill = math.max(0.0, width * v);
        final iconOnFill = fill > 44;
        return IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                onChangeStart();
                onChanged(at(d.localPosition));
              },
              onTapUp: (d) => onChangeEnd(at(d.localPosition)),
              onHorizontalDragStart: (d) {
                onChangeStart();
                onChanged(at(d.localPosition));
              },
              onHorizontalDragUpdate: (d) => onChanged(at(d.localPosition)),
              onHorizontalDragEnd: (_) => onChangeEnd(v),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: fill,
                          height: 48,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      child: Icon(
                        icon,
                        size: 22,
                        color: iconOnFill
                            ? scheme.onPrimary
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                    if (fill > 20)
                      Positioned(
                        left: fill - 12,
                        child: Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: scheme.onPrimary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Chip row under the volume slider
// ---------------------------------------------------------------------------

class RhythmPlayerChip extends StatefulWidget {
  const RhythmPlayerChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  State<RhythmPlayerChip> createState() => _RhythmPlayerChipState();
}

class _RhythmPlayerChipState extends State<RhythmPlayerChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final fg = widget.selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
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

class RhythmPlayerChipRow extends StatelessWidget {
  const RhythmPlayerChipRow({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth - 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                chips[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
