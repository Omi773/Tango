import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/rhythm/rhythm_button_group.dart';
import 'package:tango/widgets/rhythm/rhythm_dialogs.dart';
import 'package:tango/widgets/rhythm/rhythm_ui.dart';

Widget _cancelButton(String label) => Builder(
  builder: (ctx) => RhythmButton(
    label: label,
    type: RhythmButtonType.tonal,
    size: RhythmButtonSize.large,
    expand: true,
    onPressed: () => Navigator.of(ctx).pop(),
  ),
);

/// Result of [showRhythmCreatePlaylistDialog].
class RhythmNewPlaylist {
  const RhythmNewPlaylist({required this.name, this.description = ''});
  final String name;
  final String description;
}

/// Rhythm's "Create playlist" dialog: name + optional description.
Future<RhythmNewPlaylist?> showRhythmCreatePlaylistDialog(
  BuildContext context, {
  String title = 'Create playlist',
  String nameHint = 'Playlist name',
  String descriptionHint = 'Description (optional)',
  String createLabel = 'Create',
  String cancelLabel = 'Cancel',
  List<String> existingNames = const [],
  String duplicateError = 'A playlist with this name already exists',
}) {
  final name = TextEditingController();
  final description = TextEditingController();
  final existing = existingNames.map((e) => e.trim().toLowerCase()).toSet();
  return showRhythmDialog<RhythmNewPlaylist>(
    context,
    icon: Icons.playlist_add_rounded,
    title: title,
    content: ListenableBuilder(
      listenable: name,
      builder: (context, _) {
        final taken = existing.contains(name.text.trim().toLowerCase());
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: nameHint,
                errorText: taken ? duplicateError : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: descriptionHint),
            ),
          ],
        );
      },
    ),
    actions: [
      _cancelButton(cancelLabel),
      Builder(
        builder: (ctx) => ListenableBuilder(
          listenable: name,
          builder: (context, _) {
            final trimmed = name.text.trim();
            final ok =
                trimmed.isNotEmpty && !existing.contains(trimmed.toLowerCase());
            return RhythmButton(
              label: createLabel,
              size: RhythmButtonSize.large,
              expand: true,
              onPressed: ok
                  ? () => Navigator.of(ctx).pop(
                      RhythmNewPlaylist(
                        name: trimmed,
                        description: description.text.trim(),
                      ),
                    )
                  : null,
            );
          },
        ),
      ),
    ],
  );
}

/// "Save custom preset" dialog (equalizer). Returns the preset name.
Future<String?> showRhythmSaveCustomPresetDialog(
  BuildContext context, {
  String title = 'Save custom preset',
  String hint = 'Preset name',
  String saveLabel = 'Save',
  String cancelLabel = 'Cancel',
  List<String> existingNames = const [],
  String duplicateError = 'A preset with this name already exists',
}) {
  final name = TextEditingController();
  final existing = existingNames.map((e) => e.trim().toLowerCase()).toSet();
  return showRhythmDialog<String>(
    context,
    icon: Icons.tune_rounded,
    title: title,
    content: ListenableBuilder(
      listenable: name,
      builder: (context, _) => TextField(
        controller: name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          errorText: existing.contains(name.text.trim().toLowerCase())
              ? duplicateError
              : null,
        ),
      ),
    ),
    actions: [
      _cancelButton(cancelLabel),
      Builder(
        builder: (ctx) => ListenableBuilder(
          listenable: name,
          builder: (context, _) {
            final trimmed = name.text.trim();
            final ok =
                trimmed.isNotEmpty && !existing.contains(trimmed.toLowerCase());
            return RhythmButton(
              label: saveLabel,
              size: RhythmButtonSize.large,
              expand: true,
              onPressed: ok ? () => Navigator.of(ctx).pop(trimmed) : null,
            );
          },
        ),
      ),
    ],
  );
}

/// "Switch mode" confirmation: [title] and [message] describe the switch.
Future<bool> showRhythmSwitchModeDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Switch',
  String cancelLabel = 'Cancel',
}) {
  return showRhythmConfirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    icon: Icons.swap_horiz_rounded,
  );
}

/// Cache size picker: a slider in MB with preset chips. Returns MB.
Future<int?> showRhythmCacheSizeDialog(
  BuildContext context, {
  required int currentMb,
  int minMb = 64,
  int maxMb = 4096,
  List<int> presets = const [128, 256, 512, 1024, 2048],
  String title = 'Cache size',
  String message = 'Maximum space used for cached artwork and audio.',
  String applyLabel = 'Apply',
  String cancelLabel = 'Cancel',
}) {
  return showRhythmDialog<int>(
    context,
    icon: Icons.storage_rounded,
    title: title,
    message: message,
    content: _CacheSizeContent(
      initial: currentMb.clamp(minMb, maxMb),
      min: minMb,
      max: maxMb,
      presets: presets.where((p) => p >= minMb && p <= maxMb).toList(),
      applyLabel: applyLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

String _formatMb(int mb) => mb >= 1024
    ? '${(mb / 1024).toStringAsFixed(mb % 1024 == 0 ? 0 : 1)} GB'
    : '$mb MB';

class _CacheSizeContent extends StatefulWidget {
  const _CacheSizeContent({
    required this.initial,
    required this.min,
    required this.max,
    required this.presets,
    required this.applyLabel,
    required this.cancelLabel,
  });

  final int initial;
  final int min;
  final int max;
  final List<int> presets;
  final String applyLabel;
  final String cancelLabel;

  @override
  State<_CacheSizeContent> createState() => _CacheSizeContentState();
}

class _CacheSizeContentState extends State<_CacheSizeContent> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatMb(_value),
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
        ),
        Slider(
          value: _value.toDouble(),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          onChanged: (v) => setState(() => _value = v.round()),
          onChangeEnd: (_) => HapticFeedback.selectionClick(),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final p in widget.presets)
              ChoiceChip(
                label: Text(_formatMb(p)),
                selected: _value == p,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _value = p);
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: RhythmButton(
                label: widget.cancelLabel,
                type: RhythmButtonType.tonal,
                size: RhythmButtonSize.large,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RhythmButton(
                label: widget.applyLabel,
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

/// What the person chose in [showRhythmCustomizeImageDialog].
enum RhythmImageChoice { pick, reset }

/// Customize artist / playlist image dialog.
Future<RhythmImageChoice?> showRhythmCustomizeImageDialog(
  BuildContext context, {
  required String title,
  String pickLabel = 'Choose from gallery',
  String resetLabel = 'Reset to default',
  bool canReset = true,
}) {
  return showRhythmDialog<RhythmImageChoice>(
    context,
    icon: Icons.image_rounded,
    title: title,
    content: Builder(
      builder: (ctx) {
        final tiles = <(RhythmImageChoice, String, IconData, RhythmMenuTone)>[
          (
            RhythmImageChoice.pick,
            pickLabel,
            Icons.photo_library_rounded,
            RhythmMenuTone.primary,
          ),
          if (canReset)
            (
              RhythmImageChoice.reset,
              resetLabel,
              Icons.restart_alt_rounded,
              RhythmMenuTone.secondary,
            ),
        ];
        final scheme = Theme.of(ctx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < tiles.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Material(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: rhythmGroupedRadius(i, tiles.length),
                  child: InkWell(
                    borderRadius: rhythmGroupedRadius(i, tiles.length),
                    onTap: () => Navigator.of(ctx).pop(tiles[i].$1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          RhythmIconCircle(
                            icon: tiles[i].$3,
                            tone: tiles[i].$4,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              tiles[i].$2,
                              style: Theme.of(ctx).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
    actions: [_cancelButton('Cancel')],
  );
}

/// Beta program invitation popup. Returns true when the person opts in.
Future<bool> showRhythmBetaProgramDialog(
  BuildContext context, {
  String title = 'Join the beta',
  String message = 'Beta builds get new features first but may contain bugs. You can leave at any time.',
  String joinLabel = 'Join',
  String laterLabel = 'Not now',
}) async {
  final result = await showRhythmDialog<bool>(
    context,
    icon: Icons.science_rounded,
    title: title,
    message: message,
    actions: [
      Builder(
        builder: (ctx) => RhythmButton(
          label: laterLabel,
          type: RhythmButtonType.tonal,
          size: RhythmButtonSize.large,
          expand: true,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ),
      Builder(
        builder: (ctx) => RhythmButton(
          label: joinLabel,
          size: RhythmButtonSize.large,
          expand: true,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ),
    ],
  );
  return result ?? false;
}

/// Rhythm-styled single name dialog (rename / new playlist). Returns the
/// trimmed, non-empty name, or null when cancelled.
Future<String?> showRhythmNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String hint,
  required String cancelLabel,
  String? requiredError,
  String? initial,
  int? maxLength,
  IconData icon = Icons.edit_rounded,
  TextInputAction? textInputAction,
}) {
  final controller = TextEditingController(text: initial);
  final touched = ValueNotifier<bool>(false);
  return showRhythmDialog<String>(
    context,
    icon: icon,
    title: title,
    content: ListenableBuilder(
      listenable: Listenable.merge([controller, touched]),
      builder: (ctx, _) => TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: maxLength,
        textInputAction: textInputAction ?? TextInputAction.done,
        decoration: InputDecoration(
          hintText: hint,
          errorText:
              requiredError != null &&
                  touched.value &&
                  controller.text.trim().isEmpty
              ? requiredError
              : null,
        ),
        onChanged: (_) => touched.value = true,
        onSubmitted: (_) {
          final trimmed = controller.text.trim();
          if (trimmed.isEmpty) {
            touched.value = true;
          } else {
            Navigator.of(ctx).pop(trimmed);
          }
        },
      ),
    ),
    actions: [
      _cancelButton(cancelLabel),
      Builder(
        builder: (ctx) => ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final trimmed = controller.text.trim();
            return RhythmButton(
              label: confirmLabel,
              size: RhythmButtonSize.large,
              expand: true,
              onPressed: trimmed.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(trimmed),
            );
          },
        ),
      ),
    ],
  );
}
