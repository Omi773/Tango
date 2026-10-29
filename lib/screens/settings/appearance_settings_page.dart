import 'package:flutter/material.dart';
import 'package:tango/widgets/app_bottom_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/constants/language_choices.dart';
import 'package:tango/providers/runtime_profile_provider.dart';
import 'package:tango/providers/settings_provider.dart';
import 'package:tango/providers/theme_provider.dart';
import 'package:tango/models/theme_settings.dart';
import 'package:tango/utils/adaptive_layout.dart';
import 'package:tango/widgets/settings_group.dart';
import 'package:tango/widgets/app_icon.dart';
import 'package:tango/widgets/app_sliver_header.dart';
import 'package:tango/widgets/custom_font_setting.dart';
import 'package:tango/widgets/rhythm/rhythm_player_controls.dart';
import 'package:tango/widgets/rhythm/rhythm_mini_player.dart';

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
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16 + wideListInset(context),
                  vertical: 8,
                ),
                child: _ThemePreviewCard(),
              ),
            ),

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
                  if (Theme.of(context).brightness == Brightness.dark)
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

            if (themeSettings.style == AppThemeStyle.rhythm) ...[
              const SliverToBoxAdapter(
                child: SettingsSectionHeader(title: 'Player progress'),
              ),
              const SliverToBoxAdapter(
                child: SettingsGroup(
                  connected: true,
                  children: [RhythmProgressStyleSelector()],
                ),
              ),
              const SliverToBoxAdapter(
                child: SettingsSectionHeader(title: 'Mini player'),
              ),
              const SliverToBoxAdapter(
                child: SettingsGroup(
                  connected: true,
                  children: [RhythmMiniPlayerSelector()],
                ),
              ),
            ],

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
