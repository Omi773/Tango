import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/rhythm/rhythm_button_group.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';
import 'package:tango/widgets/rhythm/rhythm_sheets.dart';
import 'package:tango/widgets/rhythm/rhythm_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Artist chooser: pick one artist of a multi-artist track.
Future<String?> showRhythmArtistChooserSheet(
  BuildContext context, {
  required List<String> artists,
  String title = 'Choose artist',
  String? subtitle,
}) {
  return showRhythmOptionSheet<String>(
    context,
    title: title,
    subtitle: subtitle,
    icon: Icons.person_search_rounded,
    options: [
      for (final a in artists)
        RhythmOption<String>(value: a, title: a, icon: Icons.person_rounded),
    ],
  );
}

/// One open-source credit for [showRhythmLicensesSheet].
class RhythmLicenseEntry {
  const RhythmLicenseEntry({
    required this.name,
    required this.license,
    this.url,
    this.description,
  });

  final String name;
  final String license;
  final String? url;
  final String? description;
}

/// Rhythm's open-source licenses sheet. [onViewAll] opens the full list
/// (typically `showLicensePage`).
Future<void> showRhythmLicensesSheet(
  BuildContext context, {
  required List<RhythmLicenseEntry> entries,
  String title = 'Open-source licenses',
  String? subtitle,
  String viewAllLabel = 'View all licenses',
  VoidCallback? onViewAll,
}) {
  return showRhythmModalSheet<void>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RhythmSheetTitle(
              title: title,
              subtitle: subtitle,
              icon: Icons.gavel_rounded,
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                itemCount: entries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 3),
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final radius = rhythmGroupedRadius(i, entries.length);
                  return Material(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: radius,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: e.url == null
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              launchUrl(
                                Uri.parse(e.url!),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.name,
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (e.description != null)
                                    Text(
                                      e.description!,
                                      style: text.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                e.license,
                                style: text.labelMedium?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
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
            if (onViewAll != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: RhythmButton(
                  label: viewAllLabel,
                  icon: Icons.article_outlined,
                  type: RhythmButtonType.tonal,
                  size: RhythmButtonSize.large,
                  expand: true,
                  onPressed: onViewAll,
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Expressive shape presets picker (cookie shapes used for art and icons).
Future<RhythmShapePreset?> showRhythmShapePresetsSheet(
  BuildContext context, {
  RhythmShapePreset? selected,
  String title = 'Shape presets',
  String? subtitle,
}) {
  return showRhythmModalSheet<RhythmShapePreset>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RhythmSheetTitle(
              title: title,
              subtitle: subtitle,
              icon: Icons.interests_rounded,
            ),
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  for (final p in RhythmShapePreset.values)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(ctx).pop(p);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          color: p == selected
                              ? scheme.secondaryContainer
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: p == selected
                                ? scheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RhythmCookieIcon(
                              icon: Icons.music_note_rounded,
                              size: 56,
                              preset: p,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.name,
                              style: text.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// One line of [showRhythmBackupRestoreResultSheet].
class RhythmResultLine {
  const RhythmResultLine({
    required this.label,
    required this.value,
    this.ok = true,
  });

  final String label;
  final String value;
  final bool ok;
}

/// Backup / restore result: success or failure with per-item lines.
Future<void> showRhythmBackupRestoreResultSheet(
  BuildContext context, {
  required bool success,
  required String title,
  String? message,
  List<RhythmResultLine> lines = const [],
  String doneLabel = 'Done',
}) {
  return showRhythmModalSheet<void>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RhythmCookieIcon(
                icon: success
                    ? Icons.check_rounded
                    : Icons.error_outline_rounded,
                size: 72,
                color: success
                    ? scheme.primaryContainer
                    : scheme.errorContainer,
                iconColor: success
                    ? scheme.onPrimaryContainer
                    : scheme.onErrorContainer,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: lines.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 3),
                    itemBuilder: (_, i) {
                      final l = lines[i];
                      final radius = rhythmGroupedRadius(i, lines.length);
                      return Material(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: radius,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                l.ok
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 20,
                                color: l.ok ? scheme.primary : scheme.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(l.label)),
                              Text(
                                l.value,
                                style: text.labelLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              RhythmButton(
                label: doneLabel,
                size: RhythmButtonSize.large,
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// "Update available" sheet. Returns true when the person taps download.
Future<bool> showRhythmUpdateSheet(
  BuildContext context, {
  required String version,
  String? notes,
  String title = 'Update available',
  String downloadLabel = 'Download',
  String laterLabel = 'Later',
}) async {
  final result = await showRhythmModalSheet<bool>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: RhythmCookieIcon(
                  icon: Icons.system_update_rounded,
                  size: 72,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v$version',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: scheme.primary),
              ),
              if (notes != null && notes.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SingleChildScrollView(
                      child: Text(notes.trim(), style: text.bodyMedium),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: RhythmButton(
                      label: laterLabel,
                      type: RhythmButtonType.tonal,
                      size: RhythmButtonSize.large,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RhythmButton(
                      label: downloadLabel,
                      icon: Icons.download_rounded,
                      size: RhythmButtonSize.large,
                      expand: true,
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// One action of [showRhythmMultiSelectionSheet].
class RhythmSelectionAction {
  const RhythmSelectionAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = RhythmMenuTone.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final RhythmMenuTone tone;
}

/// Actions for a multi-selection (play, queue, add to playlist, delete).
Future<void> showRhythmMultiSelectionSheet(
  BuildContext context, {
  required int count,
  required List<RhythmSelectionAction> actions,
  String Function(int count)? titleBuilder,
}) {
  return showRhythmModalSheet<void>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RhythmSheetTitle(
              title: titleBuilder?.call(count) ?? '$count selected',
              icon: Icons.checklist_rounded,
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: actions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 3),
                itemBuilder: (_, i) {
                  final a = actions[i];
                  final radius = rhythmGroupedRadius(i, actions.length);
                  return Material(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: radius,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(ctx).pop();
                        a.onTap();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            RhythmIconCircle(icon: a.icon, tone: a.tone),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                a.label,
                                style: Theme.of(ctx).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
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
          ],
        ),
      );
    },
  );
}
