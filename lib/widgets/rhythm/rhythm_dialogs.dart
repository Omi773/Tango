import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/rhythm/rhythm_button_group.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';

/// Rhythm-styled dialog: cookie icon badge, centred title, rounded 28
/// corners and pill action buttons, opened with a springy scale.
Future<T?> showRhythmDialog<T>(
  BuildContext context, {
  IconData? icon,
  required String title,
  String? message,
  Widget? content,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
      child: Center(
        child: _RhythmDialogBody(
          icon: icon,
          title: title,
          message: message,
          content: content,
          actions: actions,
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 0.86, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _RhythmDialogBody extends StatelessWidget {
  const _RhythmDialogBody({
    required this.icon,
    required this.title,
    required this.message,
    required this.content,
    required this.actions,
  });

  final IconData? icon;
  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          minWidth: 280,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null)
                Center(
                  child: RhythmCookieIcon(
                    icon: icon!,
                    size: 56,
                    preset: RhythmShapePreset.cookie9,
                  ),
                ),
              if (icon != null) const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (content != null) ...[const SizedBox(height: 16), content!],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Yes / no dialog. Returns true when confirmed.
Future<bool> showRhythmConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showRhythmDialog<bool>(
    context,
    icon: icon,
    title: title,
    message: message,
    actions: [
      Builder(
        builder: (ctx) => RhythmButton(
          label: cancelLabel,
          type: RhythmButtonType.tonal,
          size: RhythmButtonSize.large,
          expand: true,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ),
      Builder(
        builder: (ctx) => destructive
            ? _DestructiveButton(
                label: confirmLabel,
                color: scheme.error,
                onColor: scheme.onError,
                onTap: () => Navigator.of(ctx).pop(true),
              )
            : RhythmButton(
                label: confirmLabel,
                size: RhythmButtonSize.large,
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
      ),
    ],
  );
  return result ?? false;
}

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({
    required this.label,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Plain information dialog with one button.
Future<void> showRhythmInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline_rounded,
  String closeLabel = 'OK',
}) => showRhythmDialog<void>(
  context,
  icon: icon,
  title: title,
  message: message,
  actions: [
    Builder(
      builder: (ctx) => RhythmButton(
        label: closeLabel,
        size: RhythmButtonSize.large,
        expand: true,
        onPressed: () => Navigator.of(ctx).pop(),
      ),
    ),
  ],
);

/// Single text field dialog. Returns the entered text or null.
Future<String?> showRhythmTextInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? initial,
  String? hint,
  String confirmLabel = 'Save',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.edit_rounded,
}) {
  final controller = TextEditingController(text: initial);
  return showRhythmDialog<String>(
    context,
    icon: icon,
    title: title,
    message: message,
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(hintText: hint),
      textInputAction: TextInputAction.done,
    ),
    actions: [
      Builder(
        builder: (ctx) => RhythmButton(
          label: cancelLabel,
          type: RhythmButtonType.tonal,
          size: RhythmButtonSize.large,
          expand: true,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
      Builder(
        builder: (ctx) => RhythmButton(
          label: confirmLabel,
          size: RhythmButtonSize.large,
          expand: true,
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
        ),
      ),
    ],
  );
}

class _ValueDialog extends StatefulWidget {
  const _ValueDialog({
    required this.initial,
    required this.min,
    required this.max,
    required this.presets,
    required this.format,
    required this.divisions,
  });

  final double initial;
  final double min;
  final double max;
  final List<double> presets;
  final String Function(double) format;
  final int divisions;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late double _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.format(_value),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
        Slider(
          value: _value.clamp(widget.min, widget.max),
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _value = double.parse(v.toStringAsFixed(2)));
          },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final p in widget.presets)
              ChoiceChip(
                label: Text(widget.format(p)),
                selected: (_value - p).abs() < 0.001,
                onSelected: (_) => setState(() => _value = p),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: RhythmButton(
                label: 'Cancel',
                type: RhythmButtonType.tonal,
                size: RhythmButtonSize.large,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RhythmButton(
                label: 'Apply',
                size: RhythmButtonSize.large,
                expand: true,
                onPressed: () => Navigator.of(context).pop(_value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Playback speed dialog (0.25x - 3x). Returns the new speed.
Future<double?> showRhythmSpeedDialog(
  BuildContext context, {
  double current = 1,
}) => showRhythmDialog<double>(
  context,
  icon: Icons.speed_rounded,
  title: 'Playback speed',
  content: _ValueDialog(
    initial: current,
    min: 0.25,
    max: 3,
    divisions: 55,
    presets: const [0.5, 0.75, 1, 1.25, 1.5, 2],
    format: (v) => '${v.toStringAsFixed(v * 100 % 10 == 0 ? 1 : 2)}x',
  ),
);

/// Playback pitch dialog (0.5x - 2x). Returns the new pitch.
Future<double?> showRhythmPitchDialog(
  BuildContext context, {
  double current = 1,
}) => showRhythmDialog<double>(
  context,
  icon: Icons.graphic_eq_rounded,
  title: 'Playback pitch',
  content: _ValueDialog(
    initial: current,
    min: 0.5,
    max: 2,
    divisions: 30,
    presets: const [0.75, 0.9, 1, 1.1, 1.25, 1.5],
    format: (v) => '${v.toStringAsFixed(2)}x',
  ),
);

/// Shown when a file cannot be decoded. Returns 'skip', 'remove' or null.
Future<String?> showRhythmTrackCorruptionDialog(
  BuildContext context, {
  required String trackTitle,
}) => showRhythmDialog<String>(
  context,
  icon: Icons.broken_image_rounded,
  title: "Can't play this track",
  message: '"$trackTitle" looks damaged or uses an unsupported format.',
  actions: [
    Builder(
      builder: (ctx) => RhythmButton(
        label: 'Skip',
        type: RhythmButtonType.tonal,
        size: RhythmButtonSize.large,
        expand: true,
        onPressed: () => Navigator.of(ctx).pop('skip'),
      ),
    ),
    Builder(
      builder: (ctx) => RhythmButton(
        label: 'Remove',
        size: RhythmButtonSize.large,
        expand: true,
        onPressed: () => Navigator.of(ctx).pop('remove'),
      ),
    ),
  ],
);
