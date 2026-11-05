import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Vertical EQ band slider with a rounded fill, a thumb pill and a dB label.
class RhythmEqBandSlider extends StatelessWidget {
  const RhythmEqBandSlider({
    super.key,
    required this.gain,
    required this.label,
    required this.onChanged,
    this.min = -12,
    this.max = 12,
    this.enabled = true,
  });

  final double gain;
  final String label;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: enabled ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight;
              final frac = ((gain - min) / (max - min)).clamp(0.0, 1.0);
              final zero = (0 - min) / (max - min);
              void setFromDy(double dy) {
                if (!enabled) return;
                final f = (1 - dy / h).clamp(0.0, 1.0);
                var v = min + f * (max - min);
                v = (v * 2).round() / 2; // half-dB steps
                if ((v - gain).abs() >= 0.5) HapticFeedback.selectionClick();
                onChanged(v.clamp(min, max));
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) => setFromDy(d.localPosition.dy),
                onTapDown: (d) => setFromDy(d.localPosition.dy),
                child: Center(
                  child: SizedBox(
                    width: 44,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        // Fill from zero line to the current value.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: h * (1 - (frac > zero ? frac : zero)),
                          height: h * (frac - zero).abs(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: enabled
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          right: 4,
                          top: (h * (1 - frac) - 5).clamp(0.0, h - 10),
                          height: 10,
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.onPrimary,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: scheme.primary, width: 2),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          top: h * (1 - zero) - 0.5,
                          height: 1,
                          child: ColoredBox(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Row of band sliders inside a rounded card, with an enable switch and
/// preset chips on top.
class RhythmEqualizerPanel extends StatelessWidget {
  const RhythmEqualizerPanel({
    super.key,
    required this.gains,
    required this.labels,
    required this.onBandChanged,
    required this.enabled,
    required this.onEnabledChanged,
    this.presets = const {},
    this.onPreset,
    this.activePreset,
    this.onReset,
    this.height = 280,
  });

  final List<double> gains;
  final List<String> labels;
  final void Function(int band, double gain) onBandChanged;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final Map<String, List<double>> presets;
  final ValueChanged<String>? onPreset;
  final String? activePreset;
  final VoidCallback? onReset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          decoration: BoxDecoration(
            color: enabled ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(
                Icons.equalizer_rounded,
                color: enabled ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Equalizer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: enabled ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
              ),
              if (onReset != null)
                IconButton(onPressed: onReset, icon: const Icon(Icons.restart_alt_rounded)),
              Switch(value: enabled, onChanged: onEnabledChanged),
            ],
          ),
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final name = presets.keys.elementAt(i);
                return ChoiceChip(
                  label: Text(name),
                  selected: activePreset == name,
                  onSelected: enabled ? (_) => onPreset?.call(name) : null,
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              for (var i = 0; i < gains.length; i++)
                Expanded(
                  child: RhythmEqBandSlider(
                    gain: gains[i],
                    label: i < labels.length ? labels[i] : '',
                    enabled: enabled,
                    onChanged: (v) => onBandChanged(i, v),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
