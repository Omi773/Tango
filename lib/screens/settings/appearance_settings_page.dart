import 'package:flutter/material.dart';
import 'package:tango/widgets/app_bottom_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/constants/language_choices.dart';
import 'package:tango/providers/runtime_profile_provider.dart';
import 'package:tango/providers/settings_provider.dart';
import 'package:tango/providers/theme_provider.dart';
import 'package:tango/models/theme_settings.dart';
import 'package:tango/theme/tango_theme.dart';
import 'package:tango/widgets/tango_chrome.dart';
import 'package:tango/utils/adaptive_layout.dart';
import 'package:tango/widgets/settings_group.dart';
import 'package:tango/widgets/app_icon.dart';
import 'package:tango/widgets/app_sliver_header.dart';
import 'package:tango/widgets/custom_font_setting.dart';

part 'appearance_settings_page_widgets.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final settings = ref.watch(settingsProvider);

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            AppSliverHeader.page(title: context.l10n.appearanceTitle),

            SliverToBoxAdapter(
              child: SettingsSectionHeader(title: context.l10n.appearanceStyle),
            ),
            SliverToBoxAdapter(
              child: SettingsGroup(
                children: [
                  for (final style in AppThemeStyle.values)
                    ListTile(
                      title: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(switch (style) {
                            AppThemeStyle.tango => 'Tango',
                            AppThemeStyle.rhythm => 'Rhythm',
                            AppThemeStyle.material => 'Material',
                          }),
                          if (style == AppThemeStyle.tango)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Beta',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      leading: context.isTango
                          ? null
                          : AppIcon(
                              style == AppThemeStyle.tango
                                  ? Icons.music_note_outlined
                                  : Icons.palette_outlined,
                            ),
                      trailing: themeSettings.style == style
                          ? AppIcon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      selected: themeSettings.style == style,
                      onTap: () =>
                          ref.read(themeProvider.notifier).setStyle(style),
                    ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16 + wideListInset(context),
                  vertical: 8,
                ),
                child: _ThemePreviewCard(),
              ),
            ),

            if (themeSettings.style == AppThemeStyle.tango) ...[
              SliverToBoxAdapter(
                child: SettingsSectionHeader(title: context.l10n.sectionColor),
              ),
              SliverToBoxAdapter(
                child: SettingsGroup(
                  children: [
                    _TangoAccentPicker(
                      selected: themeSettings.tangoAccent,
                      onChanged: ref
                          .read(themeProvider.notifier)
                          .setTangoAccent,
                    ),
                    const _TangoGlassClaritySlider(),
                    SettingsSwitchItem(
                      key: const ValueKey('tango-glass-outlines'),
                      icon: Icons.rounded_corner,
                      title: context.l10n.appearanceGlassOutlines,
                      subtitle: context.l10n.appearanceGlassOutlinesSubtitle,
                      value: themeSettings.tangoGlassOutlines,
                      onChanged: ref
                          .read(themeProvider.notifier)
                          .setTangoGlassOutlines,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(
                child: SettingsSectionHeader(title: context.l10n.sectionColor),
              ),

              SliverToBoxAdapter(
                child: SettingsGroup(
                  children: [
                    SettingsSwitchItem(
                      icon: Icons.wallpaper,
                      title: context.l10n.appearanceDynamicColor,
                      subtitle: context.l10n.appearanceDynamicColorSubtitle,
                      value: themeSettings.useDynamicColor,
                      onChanged: (value) => ref
                          .read(themeProvider.notifier)
                          .setUseDynamicColor(value),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              if (!themeSettings.useDynamicColor)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _ColorPalettePicker(
                      currentColor: themeSettings.seedColorValue,
                      onColorSelected: (color) =>
                          ref.read(themeProvider.notifier).setSeedColor(color),
                    ),
                  ),
                ),
            ],

            SliverToBoxAdapter(
              child: SettingsSectionHeader(title: context.l10n.sectionTheme),
            ),
            SliverToBoxAdapter(
              child: SettingsGroup(
                connected: true,
                children: [
                  _ThemeModeSelector(
                    currentMode: themeSettings.themeMode,
                    onChanged: (mode) =>
                        ref.read(themeProvider.notifier).setThemeMode(mode),
                  ),
                  if (themeSettings.style != AppThemeStyle.tango &&
                      Theme.of(context).brightness == Brightness.dark)
                    SettingsSwitchItem(
                      icon: Icons.brightness_2,
                      title: context.l10n.appearanceAmoledDark,
                      subtitle: context.l10n.appearanceAmoledDarkSubtitle,
                      value: themeSettings.useAmoled,
                      onChanged: (value) =>
                          ref.read(themeProvider.notifier).setUseAmoled(value),
                      showDivider: false,
                    ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: SettingsGroup(
                connected: true,
                children: [
                  SettingsSwitchItem(
                    icon: Icons.font_download_outlined,
                    title: context.l10n.appearanceUseSystemFont,
                    subtitle: context.l10n.appearanceUseSystemFontSubtitle,
                    value: themeSettings.useSystemFont,
                    onChanged: ref
                        .read(themeProvider.notifier)
                        .setUseSystemFont,
                  ),
                  SettingsSwitchItem(
                    icon: Icons.animation,
                    title: context.l10n.appearanceHeroAnimations,
                    subtitle: context.l10n.appearanceHeroAnimationsSubtitle,
                    value: settings.heroAnimationsEnabled,
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setHeroAnimationsEnabled(value),
                  ),
                  const CustomFontSetting(),
                  SettingsSwitchItem(
                    icon: Icons.blur_on,
                    title: context.l10n.appearanceForceBlur,
                    subtitle: context.l10n.appearanceForceBlurSubtitle,
                    value: settings.forceBackdropBlur,
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setForceBackdropBlur(value),
                    showDivider: false,
                  ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: SettingsSectionHeader(title: context.l10n.sectionLanguage),
            ),
            SliverToBoxAdapter(
              child: SettingsGroup(
                connected: true,
                children: [
                  _LanguageSelector(
                    currentLocale: settings.locale,
                    onChanged: (locale) =>
                        ref.read(settingsProvider.notifier).setLocale(locale),
                  ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: SettingsSectionHeader(title: context.l10n.sectionLayout),
            ),
            SliverToBoxAdapter(
              child: SettingsGroup(
                connected: true,
                children: [
                  _HistoryViewSelector(
                    currentMode: settings.historyViewMode,
                    onChanged: (mode) => ref
                        .read(settingsProvider.notifier)
                        .setHistoryViewMode(mode),
                  ),
                ],
              ),
            ),

            const SliverFillRemaining(
              hasScrollBody: false,
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }
}
