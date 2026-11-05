import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/rhythm/rhythm_button_group.dart';
import 'package:tango/widgets/rhythm/rhythm_empty_state.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';

/// Rhythm's adaptive modal sheet: a bottom sheet on phones and a centred
/// rounded panel on wide screens.
Future<T?> showRhythmModalSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double maxHeightFactor = 0.9,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  final scheme = Theme.of(context).colorScheme;
  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(ctx).height * maxHeightFactor,
          ),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerLow,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

/// Standard sheet header: icon cookie, title, subtitle and optional close.
class RhythmSheetTitle extends StatelessWidget {
  const RhythmSheetTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            RhythmCookieIcon(icon: icon!, size: 44),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// One choice in [showRhythmOptionSheet].
class RhythmOption<T> {
  const RhythmOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
}

/// Single-choice sheet with grouped rows and a check on the selected one.
Future<T?> showRhythmOptionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData? icon,
  required List<RhythmOption<T>> options,
  T? selected,
}) {
  return showRhythmModalSheet<T>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RhythmSheetTitle(title: title, subtitle: subtitle, icon: icon),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: options.length,
                separatorBuilder: (context, index) => const SizedBox(height: 3),
                itemBuilder: (_, i) {
                  final o = options[i];
                  final isSel = o.value == selected;
                  final big = const Radius.circular(20);
                  const small = Radius.circular(6);
                  final n = options.length;
                  final radius = n == 1
                      ? BorderRadius.all(big)
                      : BorderRadius.only(
                          topLeft: i == 0 ? big : small,
                          topRight: i == 0 ? big : small,
                          bottomLeft: i == n - 1 ? big : small,
                          bottomRight: i == n - 1 ? big : small,
                        );
                  return Material(
                    color: isSel
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: radius,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(ctx).pop(o.value);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            if (o.icon != null) ...[
                              Icon(
                                o.icon,
                                color: isSel
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.title,
                                    style: Theme.of(ctx).textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isSel
                                              ? scheme.onSecondaryContainer
                                              : scheme.onSurface,
                                        ),
                                  ),
                                  if (o.subtitle != null)
                                    Text(
                                      o.subtitle!,
                                      style: Theme.of(ctx).textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            AnimatedScale(
                              scale: isSel ? 1 : 0,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: scheme.primary,
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

/// Result of the sleep timer sheet. [duration] null with [endOfTrack] false
/// means the timer was cancelled.
class RhythmSleepTimerResult {
  const RhythmSleepTimerResult({this.duration, this.endOfTrack = false});

  final Duration? duration;
  final bool endOfTrack;
  bool get cancelled => duration == null && !endOfTrack;
}

Future<RhythmSleepTimerResult?> showRhythmSleepTimerSheet(
  BuildContext context, {
  Duration? remaining,
  bool endOfTrackActive = false,
}) {
  return showRhythmModalSheet<RhythmSleepTimerResult>(
    context,
    builder: (ctx) => _SleepTimerSheet(
      remaining: remaining,
      endOfTrackActive: endOfTrackActive,
    ),
  );
}

class _SleepTimerSheet extends StatefulWidget {
  const _SleepTimerSheet({this.remaining, this.endOfTrackActive = false});

  final Duration? remaining;
  final bool endOfTrackActive;

  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  static const _presets = [5, 10, 15, 30, 45, 60, 90, 120];
  double _custom = 20;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.remaining != null || widget.endOfTrackActive;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RhythmSheetTitle(
              title: 'Sleep timer',
              subtitle: 'Stop playback automatically',
              icon: Icons.bedtime_rounded,
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_rounded, color: scheme.onTertiaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.endOfTrackActive
                            ? 'Stopping after this track'
                            : 'Stopping in ${_fmt(widget.remaining!)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(
                        const RhythmSleepTimerResult(),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
              children: [
                for (final m in _presets)
                  _TimerTile(
                    label: m >= 60 ? '${m ~/ 60}h${m % 60 == 0 ? '' : ' ${m % 60}'}' : '$m',
                    unit: m >= 60 ? '' : 'min',
                    selected: widget.remaining?.inMinutes == m,
                    onTap: () => Navigator.of(context).pop(
                      RhythmSleepTimerResult(duration: Duration(minutes: m)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Custom', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        '${_custom.round()} min',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _custom,
                    min: 1,
                    max: 180,
                    divisions: 179,
                    onChanged: (v) => setState(() => _custom = v),
                  ),
                  RhythmButton(
                    label: 'Start ${_custom.round()} min timer',
                    icon: Icons.play_arrow_rounded,
                    size: RhythmButtonSize.large,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(
                      RhythmSleepTimerResult(
                        duration: Duration(minutes: _custom.round()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 10),
            RhythmButton(
              label: 'Stop after current track',
              icon: Icons.skip_next_rounded,
              type: RhythmButtonType.tonal,
              size: RhythmButtonSize.large,
              expand: true,
              onPressed: () => Navigator.of(context).pop(
                const RhythmSleepTimerResult(endOfTrack: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerTile extends StatelessWidget {
  const _TimerTile({
    required this.label,
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String unit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(selected ? 28 : 18),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimary : scheme.onSecondaryContainer,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Speed and pitch together in one sheet. [onChanged] fires live.
Future<void> showRhythmSpeedPitchSheet(
  BuildContext context, {
  required double speed,
  required double pitch,
  required void Function(double speed, double pitch) onChanged,
}) {
  return showRhythmModalSheet<void>(
    context,
    builder: (ctx) {
      var s = speed;
      var p = pitch;
      return StatefulBuilder(
        builder: (ctx, setState) {
          final scheme = Theme.of(ctx).colorScheme;
          Widget row(String label, IconData icon, double v, double min, double max,
              ValueChanged<double> change) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(icon, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text(label, style: Theme.of(ctx).textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        '${v.toStringAsFixed(2)}x',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: v.clamp(min, max),
                    min: min,
                    max: max,
                    onChanged: change,
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RhythmSheetTitle(
                    title: 'Speed & pitch',
                    icon: Icons.tune_rounded,
                  ),
                  row('Speed', Icons.speed_rounded, s, 0.25, 3, (v) {
                    setState(() => s = double.parse(v.toStringAsFixed(2)));
                    onChanged(s, p);
                  }),
                  row('Pitch', Icons.graphic_eq_rounded, p, 0.5, 2, (v) {
                    setState(() => p = double.parse(v.toStringAsFixed(2)));
                    onChanged(s, p);
                  }),
                  RhythmButton(
                    label: 'Reset',
                    icon: Icons.restart_alt_rounded,
                    type: RhythmButtonType.tonal,
                    size: RhythmButtonSize.large,
                    expand: true,
                    onPressed: () {
                      setState(() {
                        s = 1;
                        p = 1;
                      });
                      onChanged(1, 1);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// One labelled fact in the song info sheet.
class RhythmInfoRow {
  const RhythmInfoRow(this.label, this.value, {this.icon});

  final String label;
  final String value;
  final IconData? icon;
}

/// Song information sheet. Pass [artwork] (any widget) and the facts you
/// have; rows with empty values are skipped. Tapping a row copies it.
Future<void> showRhythmSongInfoSheet(
  BuildContext context, {
  required String title,
  required String artist,
  Widget? artwork,
  required List<RhythmInfoRow> rows,
}) {
  return showRhythmModalSheet<void>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final shown = rows.where((r) => r.value.trim().isNotEmpty).toList();
      return SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: artwork ??
                        ColoredBox(
                          color: scheme.primaryContainer,
                          child: Icon(
                            Icons.music_note_rounded,
                            color: scheme.onPrimaryContainer,
                            size: 36,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < shown.length; i++) ...[
              _InfoTile(row: shown[i], index: i, count: shown.length),
              const SizedBox(height: 3),
            ],
          ],
        ),
      );
    },
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.row, required this.index, required this.count});

  final RhythmInfoRow row;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const big = Radius.circular(20);
    const small = Radius.circular(6);
    final radius = count == 1
        ? BorderRadius.circular(20)
        : BorderRadius.only(
            topLeft: index == 0 ? big : small,
            topRight: index == 0 ? big : small,
            bottomLeft: index == count - 1 ? big : small,
            bottomRight: index == count - 1 ? big : small,
          );
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: row.value));
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text('${row.label} copied')),
          );
        },
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (row.icon != null) ...[
                Icon(row.icon, size: 20, color: scheme.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: Text(
                  row.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  row.value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Playlist row for [showRhythmAddToPlaylistSheet].
class RhythmPlaylistOption {
  const RhythmPlaylistOption({
    required this.id,
    required this.name,
    this.trackCount = 0,
    this.cover,
    this.contains = false,
  });

  final String id;
  final String name;
  final int trackCount;
  final Widget? cover;
  final bool contains;
}

/// Returns the chosen playlist id, or '__new__' when "New playlist" is tapped.
Future<String?> showRhythmAddToPlaylistSheet(
  BuildContext context, {
  required List<RhythmPlaylistOption> playlists,
  String? songTitle,
}) {
  return showRhythmModalSheet<String>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RhythmSheetTitle(
              title: 'Add to playlist',
              subtitle: songTitle,
              icon: Icons.playlist_add_rounded,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: RhythmButton(
                label: 'New playlist',
                icon: Icons.add_rounded,
                size: RhythmButtonSize.large,
                expand: true,
                onPressed: () => Navigator.of(ctx).pop('__new__'),
              ),
            ),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: RhythmCookieEmptyState(
                  title: 'No playlists yet',
                  subtitle: 'Create one to start collecting songs',
                  mainIcon: Icons.queue_music_rounded,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: playlists.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 3),
                  itemBuilder: (_, i) {
                    final p = playlists[i];
                    final n = playlists.length;
                    const big = Radius.circular(20);
                    const small = Radius.circular(6);
                    final radius = n == 1
                        ? BorderRadius.circular(20)
                        : BorderRadius.only(
                            topLeft: i == 0 ? big : small,
                            topRight: i == 0 ? big : small,
                            bottomLeft: i == n - 1 ? big : small,
                            bottomRight: i == n - 1 ? big : small,
                          );
                    return Material(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: radius,
                      child: InkWell(
                        borderRadius: radius,
                        onTap: () => Navigator.of(ctx).pop(p.id),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: p.cover ??
                                      ColoredBox(
                                        color: scheme.tertiaryContainer,
                                        child: Icon(
                                          Icons.queue_music_rounded,
                                          color: scheme.onTertiaryContainer,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(ctx).textTheme.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${p.trackCount} songs',
                                      style: Theme.of(ctx).textTheme.bodySmall
                                          ?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.contains)
                                Icon(Icons.check_circle_rounded, color: scheme.primary),
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

/// Item for [showRhythmSongPickerSheet].
class RhythmPickerItem {
  const RhythmPickerItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final String id;
  final String title;
  final String? subtitle;
  final Widget? leading;
}

/// Multi-select picker with search. Returns the chosen ids.
Future<List<String>?> showRhythmSongPickerSheet(
  BuildContext context, {
  required List<RhythmPickerItem> items,
  String title = 'Select songs',
  Set<String> initiallySelected = const {},
  String confirmLabel = 'Add',
}) {
  return showRhythmModalSheet<List<String>>(
    context,
    maxHeightFactor: 0.92,
    builder: (ctx) => _SongPicker(
      items: items,
      title: title,
      initial: initiallySelected,
      confirmLabel: confirmLabel,
    ),
  );
}

class _SongPicker extends StatefulWidget {
  const _SongPicker({
    required this.items,
    required this.title,
    required this.initial,
    required this.confirmLabel,
  });

  final List<RhythmPickerItem> items;
  final String title;
  final Set<String> initial;
  final String confirmLabel;

  @override
  State<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<_SongPicker> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items
              .where(
                (i) =>
                    i.title.toLowerCase().contains(q) ||
                    (i.subtitle?.toLowerCase().contains(q) ?? false),
              )
              .toList();
    return SafeArea(
      top: false,
      child: Column(
        children: [
          RhythmSheetTitle(
            title: widget.title,
            subtitle: '${_selected.length} selected',
            icon: Icons.library_add_check_rounded,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: SearchBar(
              hintText: 'Search',
              leading: const Icon(Icons.search_rounded),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const RhythmCookieEmptyState(
                    title: 'Nothing found',
                    mainIcon: Icons.search_off_rounded,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final on = _selected.contains(item.id);
                      return ListTile(
                        leading: item.leading,
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: item.subtitle == null
                            ? null
                            : Text(item.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: on ? scheme.primary : Colors.transparent,
                            border: Border.all(
                              color: on ? scheme.primary : scheme.outline,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(on ? 14 : 8),
                          ),
                          child: on
                              ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
                              : null,
                        ),
                        onTap: () => setState(() {
                          HapticFeedback.selectionClick();
                          on ? _selected.remove(item.id) : _selected.add(item.id);
                        }),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: RhythmButton(
              label: '${widget.confirmLabel} (${_selected.length})',
              size: RhythmButtonSize.extraLarge,
              expand: true,
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
            ),
          ),
        ],
      ),
    );
  }
}
