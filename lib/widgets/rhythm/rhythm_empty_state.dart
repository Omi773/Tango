import 'package:flutter/material.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';

/// Rhythm's cookie-cluster empty state: one large cookie flanked by two
/// small ones, a bold headline and an optional supporting line.
class RhythmCookieEmptyState extends StatefulWidget {
  const RhythmCookieEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.mainIcon = Icons.music_note_rounded,
    this.accentIcon,
    this.cornerIcon,
    this.containerColor,
    this.contentColor,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData mainIcon;
  final IconData? accentIcon;
  final IconData? cornerIcon;
  final Color? containerColor;
  final Color? contentColor;
  final Widget? action;

  @override
  State<RhythmCookieEmptyState> createState() => _RhythmCookieEmptyStateState();
}

class _RhythmCookieEmptyStateState extends State<RhythmCookieEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final container = widget.containerColor ?? scheme.primaryContainer;
    final content = widget.contentColor ?? scheme.onPrimaryContainer;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final bob = _c.value * 6.283185307;
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -6,
                        top: 10 + 3 * _sin(bob),
                        child: RhythmCookie(
                          size: 42,
                          color: container.withValues(alpha: 0.45),
                          preset: RhythmShapePreset.cookie6,
                          rotation: bob / 3,
                          child: Icon(
                            widget.accentIcon ?? widget.mainIcon,
                            size: 18,
                            color: content.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -8,
                        bottom: 6 + 3 * _sin(bob + 2),
                        child: RhythmCookie(
                          size: 34,
                          color: container.withValues(alpha: 0.45),
                          preset: RhythmShapePreset.cookie6,
                          rotation: -bob / 3,
                          child: Icon(
                            widget.cornerIcon ?? widget.mainIcon,
                            size: 14,
                            color: content.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      RhythmCookie(
                        size: 96,
                        color: container,
                        elevation: 6,
                        rotation: bob / 6,
                        child: Icon(widget.mainIcon, size: 44, color: content),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (widget.action != null) ...[
              const SizedBox(height: 20),
              widget.action!,
            ],
          ],
        ),
      ),
    );
  }

  static double _sin(double x) => _fastSin(x);

  static double _fastSin(double x) {
    // Bhaskara approximation is plenty for a gentle bob.
    var v = x % 6.283185307;
    if (v > 3.141592653) v -= 6.283185307;
    final a = v.abs();
    final s = 16 * a * (3.141592653 - a) / (49.348022 - 4 * a * (3.141592653 - a));
    return v < 0 ? -s : s;
  }
}
