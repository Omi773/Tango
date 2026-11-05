import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';
import 'package:tango/widgets/rhythm/rhythm_sheets.dart';
import 'package:tango/widgets/rhythm/rhythm_ui.dart';

/// Rhythm settings page: large collapsing title and a column of sections.
class RhythmSettingsScaffold extends StatelessWidget {
  const RhythmSettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.hero,
    this.controller,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? hero;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            actions: actions,
          ),
          if (hero != null) SliverToBoxAdapter(child: hero),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
    );
  }
}

/// Section title + grouped rounded tiles (big outer, small inner corners).
class RhythmSettingsSection extends StatelessWidget {
  const RhythmSettingsSection({
    super.key,
    this.title,
    required this.children,
    this.footer,
  });

  final String? title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            _GroupedSlot(index: i, count: children.length, child: children[i]),
          ],
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                footer!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupedSlot extends StatelessWidget {
  const _GroupedSlot({
    required this.index,
    required this.count,
    required this.child,
  });

  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = rhythmGroupedRadius(index, count, outer: 24, inner: 6);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Basic settings row with a tonal icon circle.
class RhythmSettingsTile extends StatelessWidget {
  const RhythmSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = RhythmMenuTone.primary,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final RhythmMenuTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled && onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                RhythmIconCircle(icon: icon!, tone: tone, size: 44),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (trailing == null && onTap != null)
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class RhythmSettingsSwitchTile extends StatelessWidget {
  const RhythmSettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = RhythmMenuTone.primary,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final RhythmMenuTone tone;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => RhythmSettingsTile(
    title: title,
    subtitle: subtitle,
    icon: icon,
    tone: tone,
    enabled: enabled,
    onTap: () => onChanged(!value),
    trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
  );
}

class RhythmSettingsSliderTile extends StatelessWidget {
  const RhythmSettingsSliderTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = RhythmMenuTone.secondary,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.format,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final RhythmMenuTone tone;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              if (icon != null) ...[
                RhythmIconCircle(icon: icon!, tone: tone, size: 44),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                format?.call(value) ?? value.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Row that opens a [showRhythmOptionSheet] and shows the current choice.
class RhythmSettingsChoiceTile<T> extends StatelessWidget {
  const RhythmSettingsChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = RhythmMenuTone.tertiary,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final RhythmMenuTone tone;
  final List<RhythmOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = options.where((o) => o.value == value).firstOrNull;
    return RhythmSettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      tone: tone,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          current?.title ?? '',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: () async {
        final picked = await showRhythmOptionSheet<T>(
          context,
          title: title,
          subtitle: subtitle,
          icon: icon,
          options: options,
          selected: value,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Big tinted card with a cookie icon, used at the top of About, Updates,
/// Backup and similar pages.
class RhythmSettingsHeroCard extends StatelessWidget {
  const RhythmSettingsHeroCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.music_note_rounded,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          RhythmCookieIcon(
            icon: icon,
            size: 72,
            color: scheme.primary,
            iconColor: scheme.onPrimary,
            preset: RhythmShapePreset.cookie12,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline notice card (info, warning, error).
class RhythmNoticeCard extends StatelessWidget {
  const RhythmNoticeCard({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = RhythmMenuTone.secondary,
  });

  final String message;
  final IconData icon;
  final RhythmMenuTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      RhythmMenuTone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      RhythmMenuTone.secondary => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      RhythmMenuTone.tertiary => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      RhythmMenuTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Searchable settings index (Rhythm's SettingsSearch): filters [entries]
/// by title/keywords and calls [onOpen] with the tapped entry.
class RhythmSettingsEntry {
  const RhythmSettingsEntry({
    required this.title,
    required this.section,
    required this.icon,
    required this.onOpen,
    this.keywords = const [],
  });

  final String title;
  final String section;
  final IconData icon;
  final VoidCallback onOpen;
  final List<String> keywords;
}

class RhythmSettingsSearch extends StatefulWidget {
  const RhythmSettingsSearch({super.key, required this.entries});

  final List<RhythmSettingsEntry> entries;

  @override
  State<RhythmSettingsSearch> createState() => _RhythmSettingsSearchState();
}

class _RhythmSettingsSearchState extends State<RhythmSettingsSearch> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final results = q.isEmpty
        ? const <RhythmSettingsEntry>[]
        : widget.entries
              .where(
                (e) =>
                    e.title.toLowerCase().contains(q) ||
                    e.section.toLowerCase().contains(q) ||
                    e.keywords.any((k) => k.toLowerCase().contains(q)),
              )
              .toList();
    return Column(
      children: [
        SearchBar(
          hintText: 'Search settings',
          leading: const Icon(Icons.search_rounded),
          onChanged: (v) => setState(() => _q = v),
        ),
        if (results.isNotEmpty)
          RhythmSettingsSection(
            children: [
              for (final e in results)
                RhythmSettingsTile(
                  title: e.title,
                  subtitle: e.section,
                  icon: e.icon,
                  onTap: e.onOpen,
                ),
            ],
          ),
      ],
    );
  }
}
