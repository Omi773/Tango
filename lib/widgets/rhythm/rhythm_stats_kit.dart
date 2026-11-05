import 'package:flutter/material.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';

/// Big number card used on the stats page.
class RhythmStatCard extends StatelessWidget {
  const RhythmStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color,
    this.onColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.secondaryContainer;
    final fg = onColor ?? scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RhythmCookieIcon(
            icon: icon,
            size: 40,
            color: fg.withValues(alpha: 0.14),
            iconColor: fg,
            preset: RhythmShapePreset.cookie6,
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: fg.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple animated bar chart (e.g. listening time per weekday).
class RhythmBarChart extends StatelessWidget {
  const RhythmBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 160,
    this.highlight,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(0.0001, double.infinity);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: values[i] / max),
                          duration: Duration(milliseconds: 500 + i * 60),
                          curve: Curves.easeOutBack,
                          builder: (context, t, _) => FractionallySizedBox(
                            heightFactor: t.clamp(0.04, 1.0),
                            widthFactor: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: i == highlight
                                    ? scheme.primary
                                    : scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i < labels.length ? labels[i] : '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ranked row (top tracks / artists) with a number cookie.
class RhythmRankTile extends StatelessWidget {
  const RhythmRankTile({
    super.key,
    required this.rank,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
  });

  final int rank;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RhythmCookie(
            size: 36,
            color: rank <= 3 ? scheme.primary : scheme.surfaceContainerHighest,
            preset: RhythmShapePreset.cookie6,
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: rank <= 3 ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (leading != null) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 44, height: 44, child: leading),
            ),
          ],
        ],
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
