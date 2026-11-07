import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/rhythm/rhythm_button_group.dart';
import 'package:tango/widgets/rhythm/rhythm_sheets.dart';
import 'package:tango/widgets/rhythm/rhythm_ui.dart';

/// One row of [showRhythmReorderSheet].
class RhythmReorderItem<T> {
  const RhythmReorderItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
    this.enabled = true,
    this.locked = false,
  });

  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Whether the row is switched on (visible).
  final bool enabled;

  /// A locked row can be moved but not switched off.
  final bool locked;

  RhythmReorderItem<T> copyWith({bool? enabled}) => RhythmReorderItem<T>(
    value: value,
    title: title,
    subtitle: subtitle,
    icon: icon,
    enabled: enabled ?? this.enabled,
    locked: locked,
  );
}

/// Rhythm's drag-and-drop order sheet (home sections, library tabs, player
/// chips, bottom buttons, equalizer presets, lyrics API priority).
/// Returns the new order, or null when dismissed. [defaults] enables Reset.
Future<List<RhythmReorderItem<T>>?> showRhythmReorderSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.swap_vert_rounded,
  required List<RhythmReorderItem<T>> items,
  List<RhythmReorderItem<T>>? defaults,
  bool showToggles = true,
  String saveLabel = 'Save',
  String resetLabel = 'Reset',
}) {
  return showRhythmModalSheet<List<RhythmReorderItem<T>>>(
    context,
    builder: (ctx) => _ReorderBody<T>(
      title: title,
      subtitle: subtitle,
      icon: icon,
      initial: items,
      defaults: defaults,
      showToggles: showToggles,
      saveLabel: saveLabel,
      resetLabel: resetLabel,
    ),
  );
}

class _ReorderBody<T> extends StatefulWidget {
  const _ReorderBody({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.initial,
    required this.defaults,
    required this.showToggles,
    required this.saveLabel,
    required this.resetLabel,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<RhythmReorderItem<T>> initial;
  final List<RhythmReorderItem<T>>? defaults;
  final bool showToggles;
  final String saveLabel;
  final String resetLabel;

  @override
  State<_ReorderBody<T>> createState() => _ReorderBodyState<T>();
}

class _ReorderBodyState<T> extends State<_ReorderBody<T>> {
  late List<RhythmReorderItem<T>> _items = List.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RhythmSheetTitle(
            title: widget.title,
            subtitle: widget.subtitle,
            icon: widget.icon,
          ),
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              itemCount: _items.length,
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 6,
                shadowColor: scheme.shadow,
                borderRadius: BorderRadius.circular(16),
                child: child,
              ),
              onReorderStart: (_) => HapticFeedback.mediumImpact(),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final moved = _items.removeAt(oldIndex);
                  _items.insert(newIndex, moved);
                });
                HapticFeedback.selectionClick();
              },
              itemBuilder: (context, i) {
                final item = _items[i];
                final radius = rhythmGroupedRadius(i, _items.length);
                final dim = widget.showToggles && !item.enabled;
                return Padding(
                  key: ValueKey<Object?>(item.value),
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Material(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: radius,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const RhythmDragHandle(size: 40),
                          ),
                          const SizedBox(width: 12),
                          if (item.icon != null) ...[
                            Icon(
                              item.icon,
                              color: dim
                                  ? scheme.onSurface.withValues(alpha: 0.38)
                                  : scheme.primary,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Opacity(
                              opacity: dim ? 0.5 : 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item.subtitle != null)
                                    Text(
                                      item.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.showToggles)
                            Switch(
                              value: item.enabled,
                              onChanged: item.locked
                                  ? null
                                  : (v) => setState(
                                      () =>
                                          _items[i] = item.copyWith(enabled: v),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                if (widget.defaults != null) ...[
                  Expanded(
                    child: RhythmButton(
                      label: widget.resetLabel,
                      icon: Icons.restart_alt_rounded,
                      type: RhythmButtonType.tonal,
                      size: RhythmButtonSize.large,
                      expand: true,
                      onPressed: () =>
                          setState(() => _items = List.of(widget.defaults!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: RhythmButton(
                    label: widget.saveLabel,
                    icon: Icons.check_rounded,
                    size: RhythmButtonSize.large,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(_items),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
