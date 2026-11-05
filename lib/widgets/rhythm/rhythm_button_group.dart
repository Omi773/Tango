import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum RhythmButtonSize { small, medium, large, extraLarge }

enum RhythmButtonType { filled, tonal, outlined, elevated, text }

double rhythmButtonHeight(RhythmButtonSize size) => switch (size) {
  RhythmButtonSize.small => 32,
  RhythmButtonSize.medium => 40,
  RhythmButtonSize.large => 48,
  RhythmButtonSize.extraLarge => 56,
};

double _iconSize(RhythmButtonSize size) => switch (size) {
  RhythmButtonSize.small => 14,
  RhythmButtonSize.medium => 16,
  RhythmButtonSize.large => 18,
  RhythmButtonSize.extraLarge => 20,
};

double _hPad(RhythmButtonSize size) => switch (size) {
  RhythmButtonSize.small => 8,
  RhythmButtonSize.medium => 12,
  RhythmButtonSize.large => 16,
  RhythmButtonSize.extraLarge => 20,
};

(Color bg, Color fg, BorderSide? side) _colors(
  ColorScheme s,
  RhythmButtonType type,
  bool active,
) {
  switch (type) {
    case RhythmButtonType.filled:
      return (s.primary, s.onPrimary, null);
    case RhythmButtonType.tonal:
      return (s.secondaryContainer, s.onSecondaryContainer, null);
    case RhythmButtonType.elevated:
      return (s.surfaceContainerLow, s.primary, null);
    case RhythmButtonType.outlined:
      return (
        active ? s.secondaryContainer : Colors.transparent,
        active ? s.onSecondaryContainer : s.onSurface,
        BorderSide(color: s.outline),
      );
    case RhythmButtonType.text:
      return (Colors.transparent, s.primary, null);
  }
}

/// Pressable pill button with Rhythm's squish animation.
class RhythmButton extends StatefulWidget {
  const RhythmButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.type = RhythmButtonType.filled,
    this.size = RhythmButtonSize.medium,
    this.expand = false,
    this.radius,
    this.child,
  });

  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final RhythmButtonType type;
  final RhythmButtonSize size;
  final bool expand;
  final double? radius;
  final Widget? child;

  @override
  State<RhythmButton> createState() => _RhythmButtonState();
}

class _RhythmButtonState extends State<RhythmButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = rhythmButtonHeight(widget.size);
    final (bg, fg, side) = _colors(scheme, widget.type, false);
    final enabled = widget.onPressed != null;
    final radius = widget.radius ?? h / 2;
    final content =
        widget.child ??
        Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) Icon(widget.icon, size: _iconSize(widget.size)),
            if (widget.icon != null && widget.label != null)
              const SizedBox(width: 6),
            if (widget.label != null)
              Flexible(
                child: Text(
                  widget.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
    return AnimatedScale(
      scale: _down ? 0.95 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: h,
        decoration: ShapeDecoration(
          color: enabled ? bg : scheme.onSurface.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_down ? radius * 0.6 : radius),
            side: side ?? BorderSide.none,
          ),
          shadows: widget.type == RhythmButtonType.elevated
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTapDown: enabled ? (_) => setState(() => _down = true) : null,
            onTapCancel: () => setState(() => _down = false),
            onTap: enabled
                ? () {
                    setState(() => _down = false);
                    HapticFeedback.selectionClick();
                    widget.onPressed!();
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _hPad(widget.size) + 8),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: enabled ? fg : scheme.onSurface.withValues(alpha: 0.38),
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: enabled ? fg : scheme.onSurface.withValues(alpha: 0.38),
                  ),
                  child: Center(widthFactor: 1, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One option of a [RhythmToggleButtonGroup].
class RhythmToggleOption<T> {
  const RhythmToggleOption({required this.value, this.label, this.icon})
    : assert(label != null || icon != null);

  final T value;
  final String? label;
  final IconData? icon;
}

/// Connected toggle group. The selected segment becomes a full pill and
/// grows; its neighbours keep tight inner corners.
class RhythmToggleButtonGroup<T> extends StatelessWidget {
  const RhythmToggleButtonGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.size = RhythmButtonSize.large,
    this.type = RhythmButtonType.tonal,
    this.selectedWeight = 1.5,
    this.gap = 4,
  });

  final List<RhythmToggleOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final RhythmButtonSize size;
  final RhythmButtonType type;
  final double selectedWeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = rhythmButtonHeight(size);
    return LayoutBuilder(
      builder: (context, constraints) {
        final weights = [
          for (final o in options) o.value == selected ? selectedWeight : 1.0,
        ];
        final total = weights.fold<double>(0, (a, b) => a + b);
        final avail =
            constraints.maxWidth - gap * (options.length - 1).clamp(0, 99);
        return Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _segment(context, scheme, h, i, avail * weights[i] / total),
            ],
          ],
        );
      },
    );
  }

  Widget _segment(
    BuildContext context,
    ColorScheme scheme,
    double h,
    int i,
    double width,
  ) {
    final option = options[i];
    final active = option.value == selected;
    final outer = Radius.circular(h / 2);
    const inner = Radius.circular(8);
    final isFirst = i == 0;
    final isLast = i == options.length - 1;
    final radius = active
        ? BorderRadius.circular(h / 2)
        : BorderRadius.only(
            topLeft: isFirst ? outer : inner,
            bottomLeft: isFirst ? outer : inner,
            topRight: isLast ? outer : inner,
            bottomRight: isLast ? outer : inner,
          );
    final bg = active
        ? (type == RhythmButtonType.filled
              ? scheme.primary
              : scheme.secondaryContainer)
        : scheme.surfaceContainerHighest;
    final fg = active
        ? (type == RhythmButtonType.filled
              ? scheme.onPrimary
              : scheme.onSecondaryContainer)
        : scheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      width: width < 0 ? 0 : width,
      height: h,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(option.value);
          },
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null)
                  Icon(option.icon, size: _iconSize(size) + 2, color: fg),
                if (option.icon != null && option.label != null)
                  const SizedBox(width: 6),
                if (option.label != null)
                  Flexible(
                    child: Text(
                      option.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
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

/// Row of weighted action buttons (Play / Shuffle / Download ...) used on
/// album, playlist and artist pages. The pressed button grows.
class RhythmActionButtonRow extends StatefulWidget {
  const RhythmActionButtonRow({super.key, required this.actions, this.height = 52});

  final List<RhythmDetailAction> actions;
  final double height;

  @override
  State<RhythmActionButtonRow> createState() => _RhythmActionButtonRowState();
}

class _RhythmActionButtonRowState extends State<RhythmActionButtonRow> {
  int? _pressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final n = widget.actions.length;
        final weights = [
          for (var i = 0; i < n; i++) _pressed == i ? 1.25 : 1.0,
        ];
        final total = weights.fold<double>(0, (a, b) => a + b);
        final avail = c.maxWidth - gap * (n - 1);
        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                width: avail * weights[i] / total,
                height: widget.height,
                decoration: BoxDecoration(
                  color: widget.actions[i].primary
                      ? scheme.primary
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(
                    _pressed == i ? 14 : widget.height / 2.6,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(widget.height / 2.6),
                    onTapDown: (_) => setState(() => _pressed = i),
                    onTapCancel: () => setState(() => _pressed = null),
                    onTap: () {
                      setState(() => _pressed = null);
                      HapticFeedback.lightImpact();
                      widget.actions[i].onTap();
                    },
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.actions[i].icon,
                            size: 20,
                            color: widget.actions[i].primary
                                ? scheme.onPrimary
                                : scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.actions[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: widget.actions[i].primary
                                        ? scheme.onPrimary
                                        : scheme.onSecondaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class RhythmDetailAction {
  const RhythmDetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
}
