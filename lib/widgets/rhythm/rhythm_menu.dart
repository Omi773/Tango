import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tango/widgets/app_icon_button.dart';
import 'package:tango/widgets/rhythm/rhythm_ui.dart';

/// Popup and sheet hosts for [RhythmGroupedMenu], ported from Rhythm's
/// DropdownMenu (surface panel, 20dp corners, 4dp padding, 220dp minimum
/// width) and its song-menu bottom sheet.

/// One choice of a Rhythm popup menu; [value] is what the menu returns.
class RhythmMenuEntry<T> {
  const RhythmMenuEntry({
    required this.value,
    required this.title,
    this.icon,
    this.iconWidget,
    this.subtitle,
    this.tone = RhythmMenuTone.primary,
    this.selected = false,
    this.destructive = false,
    this.enabled = true,
  });

  final T value;
  final String title;
  final IconData? icon;
  final Widget? iconWidget;
  final String? subtitle;
  final RhythmMenuTone tone;
  final bool selected;
  final bool destructive;
  final bool enabled;

  RhythmMenuItem toItem(VoidCallback onPick) => RhythmMenuItem(
    title: title,
    icon: icon,
    iconWidget: iconWidget,
    subtitle: subtitle,
    tone: tone,
    selected: selected,
    isDestructive: destructive,
    onTap: enabled ? onPick : null,
  );
}

/// Bounds of the control owning [context], in screen coordinates.
Rect? rhythmMenuAnchor(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Opens [entries] as Rhythm's grouped menu beside [anchor] (or centred when
/// there is none) and completes with the chosen value, or null on dismissal.
Future<T?> showRhythmMenu<T>({
  required BuildContext context,
  required List<RhythmMenuEntry<T>> entries,
  Rect? anchor,
  bool preferAbove = false,
  double minWidth = 220,
  double maxWidth = 320,
}) {
  if (entries.isEmpty) return Future<T?>.value();
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final target = anchor ?? rhythmMenuAnchor(context);
  final screen = MediaQuery.sizeOf(context);
  final fromRight = target == null || target.center.dx > screen.width / 2;
  final alignment = Alignment(fromRight ? 1 : -1, preferAbove ? 1 : -1);
  final instant = MediaQuery.disableAnimationsOf(context);
  return navigator.push<T>(
    RawDialogRoute<T>(
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.10),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: instant
          ? Duration.zero
          : const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, _, child) {
        final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: eased.drive(Tween<double>(begin: 0.9, end: 1)),
            alignment: alignment,
            child: child,
          ),
        );
      },
      pageBuilder: (routeContext, _, _) {
        final media = MediaQuery.of(routeContext);
        return Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: MaterialLocalizations.of(routeContext).popupMenuLabel,
          explicitChildNodes: true,
          child: CustomSingleChildLayout(
            delegate: _RhythmMenuLayout(
              anchor: target,
              preferAbove: preferAbove,
              minWidth: minWidth,
              maxWidth: maxWidth,
              padding: media.padding.copyWith(
                bottom: math.max(media.padding.bottom, media.viewInsets.bottom),
              ),
            ),
            child: themes.wrap(_RhythmMenuPanel<T>(entries: entries)),
          ),
        );
      },
    ),
  );
}

class _RhythmMenuPanel<T> extends StatelessWidget {
  const _RhythmMenuPanel({required this.entries});

  final List<RhythmMenuEntry<T>> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: RhythmGroupedMenu(
            items: [
              for (final entry in entries)
                entry.toItem(() => Navigator.of(context).pop(entry.value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RhythmMenuLayout extends SingleChildLayoutDelegate {
  const _RhythmMenuLayout({
    required this.anchor,
    required this.padding,
    required this.preferAbove,
    required this.minWidth,
    required this.maxWidth,
  });

  final Rect? anchor;
  final EdgeInsets padding;
  final bool preferAbove;
  final double minWidth;
  final double maxWidth;
  static const double _margin = 12;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = math.max(
      0.0,
      constraints.maxWidth - padding.horizontal - _margin * 2,
    );
    final widest = math.min(maxWidth, available);
    return BoxConstraints(
      minWidth: math.min(minWidth, widest),
      maxWidth: widest,
      maxHeight: math.max(
        0.0,
        constraints.maxHeight - padding.vertical - _margin * 2,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final target = anchor;
    if (target == null) {
      return Offset(
        (size.width - childSize.width) / 2,
        (size.height - childSize.height) / 2,
      );
    }
    final left = padding.left + _margin;
    final top = padding.top + _margin;
    final right = math.max(
      left,
      size.width - padding.right - _margin - childSize.width,
    );
    final bottom = math.max(
      top,
      size.height - padding.bottom - _margin - childSize.height,
    );
    final fromRight = target.center.dx > size.width / 2;
    final x = fromRight ? target.right - childSize.width : target.left;
    final below = target.bottom + 4;
    final above = target.top - childSize.height - 4;
    final fitsBelow = below <= bottom;
    final fitsAbove = above >= top;
    final y = preferAbove
        ? (fitsAbove ? above : (fitsBelow ? below : top))
        : (fitsBelow ? below : (fitsAbove ? above : bottom));
    return Offset(x.clamp(left, right), y.clamp(top, bottom));
  }

  @override
  bool shouldRelayout(_RhythmMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      padding != oldDelegate.padding ||
      preferAbove != oldDelegate.preferAbove ||
      minWidth != oldDelegate.minWidth ||
      maxWidth != oldDelegate.maxWidth;
}

/// Icon button that opens [entries] as a Rhythm popup menu.
class RhythmMenuButton<T> extends StatelessWidget {
  const RhythmMenuButton({
    super.key,
    required this.icon,
    required this.entries,
    required this.onSelected,
    this.tooltip,
    this.preferAbove = false,
  });

  final Widget icon;
  final List<RhythmMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final String? tooltip;
  final bool preferAbove;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => AppIconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: () async {
          final value = await showRhythmMenu<T>(
            context: buttonContext,
            entries: entries,
            anchor: rhythmMenuAnchor(buttonContext),
            preferAbove: preferAbove,
          );
          if (value != null) onSelected(value);
        },
      ),
    );
  }
}

/// Body of a bottom sheet that lists [items] as Rhythm's grouped menu, with
/// an optional [header] above it (a song's cover and name, say).
class RhythmMenuSheetBody extends StatelessWidget {
  const RhythmMenuSheetBody({super.key, required this.items, this.header});

  final List<RhythmMenuItem> items;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            RhythmGroupedMenu(items: items),
          ],
        ),
      ),
    );
  }
}
