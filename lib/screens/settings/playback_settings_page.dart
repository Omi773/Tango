import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/providers/settings_provider.dart';
import 'package:tango/services/music_playback_deck.dart';
import 'package:tango/screens/listening_statistics_screen.dart';
import 'package:tango/screens/equalizer_screen.dart';
import 'package:tango/utils/desktop_platform.dart';
import 'package:tango/widgets/animation_utils.dart';
import 'package:tango/widgets/app_alert_dialog.dart';
import 'package:tango/widgets/app_icon.dart';
import 'package:tango/widgets/app_sliver_header.dart';
import 'package:tango/widgets/beta_badge.dart';
import 'package:tango/widgets/player_volume_control.dart';
import 'package:tango/widgets/settings_group.dart';
import 'package:tango/widgets/discord_presence_settings.dart';
import 'package:tango/widgets/music_haptics_settings.dart';
import 'package:tango/widgets/playback_normalization_settings.dart';

class PlaybackSettingsPage extends ConsumerStatefulWidget {
  const PlaybackSettingsPage({super.key});

  @override
  ConsumerState<PlaybackSettingsPage> createState() =>
      _PlaybackSettingsPageState();
}

class _PlaybackSettingsPageState extends ConsumerState<PlaybackSettingsPage> {
  Future<bool> _confirmAudioVolume(String message) async {
    return await showAppDialog<bool>(
          context: context,
          builder: (context) => AppAlertDialog(
            title: Text(context.l10n.usbVolumeWarningTitle),
            content: Text(message),
            actions: [
              AppDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.dialogCancel),
              ),
              AppDialogAction(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.usbVolumeAccept),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          AppSliverHeader.page(title: context.l10n.libraryPlayback),
          SliverToBoxAdapter(
            child: SettingsSectionHeader(
              title: context.l10n.sectionVolumeAndTransitions,
            ),
          ),
          SliverToBoxAdapter(
            child: SettingsGroup(
              children: [
                SettingsItem(
                  icon: Icons.equalizer,
                  title: context.l10n.equalizerTitle,
                  titleTrailing: const BetaBadge(),
                  subtitle: context.l10n.equalizerDescription,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                  ),
                ),
                SettingsSwitchItem(
                  icon: Icons.graphic_eq,
                  title: context.l10n.libraryPlaybackNormalization,
                  subtitle: context.l10n.libraryPlaybackNormalizationSubtitle,
                  value: settings.playbackNormalization,
                  enabled: !settings.usbBitPerfect,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setPlaybackNormalization(value),
                ),
                if (settings.playbackNormalization)
                  PlaybackNormalizationSettings(
                    enabled: !settings.usbBitPerfect,
                  ),
                if (!isDesktopPlatform) ...[
                  SettingsSwitchItem(
                    icon: Icons.vibration,
                    title: context.l10n.musicHaptics,
                    subtitle: context.l10n.musicHapticsDescription,
                    value: settings.musicHaptics,
                    enabled: settings.playerMode == 'internal',
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setMusicHaptics(value),
                  ),
                  if (settings.musicHaptics)
                    MusicHapticsSettings(
                      enabled: settings.playerMode == 'internal',
                    ),
                ],
              ],
            ),
          ),
          // Mute and headphone routes come from mobile system audio.
          if (!isDesktopPlatform) ...[
            SliverToBoxAdapter(
              child: SettingsSectionHeader(
                title: context.l10n.playbackAutomation,
              ),
            ),
            SliverToBoxAdapter(
              child: SettingsGroup(
                children: [
                  SettingsSwitchItem(
                    icon: Icons.headphones_outlined,
                    title: context.l10n.playbackOnHeadphonesConnected,
                    subtitle:
                        context.l10n.playbackOnHeadphonesConnectedDescription,
                    value: settings.playOnHeadphonesConnected,
                    enabled: settings.playerMode == 'internal',
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setPlayOnHeadphonesConnected(value),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: SettingsSectionHeader(title: context.l10n.playerCoverStyle),
          ),
          SliverToBoxAdapter(
            child: SettingsGroup(
              children: [
                for (final (style, icon, title, subtitle) in [
                  (
                    'default',
                    Icons.crop_square,
                    context.l10n.playerCoverStyleDefault,
                    context.l10n.playerCoverStyleDefaultDescription,
                  ),
                  (
                    'fullscreen',
                    Icons.fullscreen,
                    context.l10n.playerCoverStyleFullScreen,
                    context.l10n.playerCoverStyleFullScreenDescription,
                  ),
                ])
                  SettingsItem(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    selected: settings.playerCoverStyle == style,
                    trailing: settings.playerCoverStyle == style
                        ? AppIcon(Icons.check, color: colorScheme.primary)
                        : null,
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setPlayerCoverStyle(style),
                    showDivider: style != 'fullscreen',
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SettingsSectionHeader(title: context.l10n.motionArtwork),
          ),
          SliverToBoxAdapter(
            child: SettingsGroup(
              children: [
                SettingsSwitchItem(
                  icon: Icons.motion_photos_on_outlined,
                  title: context.l10n.motionArtwork,
                  subtitle: context.l10n.motionArtworkDescription,
                  value: settings.motionArtworkEnabled,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setMotionArtworkEnabled(value),
                  showDivider: false,
                ),
              ],
            ),
          ),
          if (Platform.isAndroid || Platform.isIOS || isDesktopPlatform) ...[
            const SliverToBoxAdapter(
              child: SettingsSectionHeader(title: 'Discord'),
            ),
            const SliverToBoxAdapter(child: DiscordPresenceSettings()),
          ],
          if (Platform.isAndroid || Platform.isIOS)
            SliverToBoxAdapter(
              child: SettingsSectionHeader(
                title: context.l10n.sectionAudioOutput,
              ),
            ),
          if (Platform.isAndroid || Platform.isIOS)
            SliverToBoxAdapter(
              child: SettingsGroup(
                connected: true,
                children: [
                  ValueListenableBuilder<UsbAudioStatus>(
                    valueListenable: usbAudioStatus,
                    builder: (context, status, _) => SettingsSwitchItem(
                      icon: Icons.usb,
                      title: context.l10n.usbBitPerfect,
                      titleTrailing: const BetaBadge(),
                      subtitle: [
                        Platform.isIOS
                            ? 'Decodes FLAC, ALAC and WAV itself and asks iOS to run your DAC at the file\'s own sample rate, with no EQ, AutoMix, normalization or volume processing. Applies from the next track. Use the iPhone volume buttons.'
                            : context.l10n.usbBitPerfectDescription,
                        if (settings.usbBitPerfect)
                          switch (status.reason) {
                            'active' =>
                              '${status.device} · ${status.transport == 'pcm'
                                  ? '${status.bitDepth ?? '?'}-bit PCM'
                                  : status.transport == 'dop'
                                  ? 'DSD (DoP)'
                                  : 'DSD (Native)'} · ${(status.sampleRate! / 1000).toStringAsFixed(1)} kHz',
                            'dsd_unsupported' => context.l10n.usbDsdUnsupported,
                            'volume_unavailable' =>
                              context.l10n.usbVolumeUnavailable,
                            'exclusive_unavailable' =>
                              context.l10n.dapExclusiveUnavailable,
                            'permission_denied' =>
                              context.l10n.usbPermissionDenied,
                            'no_usb' => context.l10n.usbBitPerfectNoDevice,
                            'route_changed' =>
                              context.l10n.usbBitPerfectRouteChanged,
                            'android_version' ||
                            'unsupported' ||
                            'format' => context.l10n.usbBitPerfectFallback,
                            _ => context.l10n.usbBitPerfectPending,
                          },
                      ].join('\n\n'),
                      value: settings.usbBitPerfect,
                      onChanged: (value) async {
                        if (value &&
                            Platform.isAndroid &&
                            !await _confirmAudioVolume(
                              context.l10n.usbVolumeWarning,
                            )) {
                          return;
                        }
                        if (mounted) {
                          ref
                              .read(settingsProvider.notifier)
                              .setUsbBitPerfect(value);
                        }
                      },
                      showDivider: settings.usbBitPerfect && Platform.isAndroid,
                    ),
                  ),
                  if (settings.usbBitPerfect && Platform.isAndroid) ...[
                    SettingsSwitchItem(
                      icon: Icons.usb,
                      title: context.l10n.usbDirect,
                      subtitle: context.l10n.usbDirectDescription,
                      value: settings.usbDirect,
                      onChanged: (value) async {
                        if (value &&
                            !await _confirmAudioVolume(
                              context.l10n.usbVolumeWarning,
                            )) {
                          return;
                        }
                        if (mounted) {
                          ref
                              .read(settingsProvider.notifier)
                              .setUsbDirect(value);
                        }
                      },
                    ),
                    if (settings.usbDirect) ...[
                      SettingsSwitchItem(
                        icon: Icons.graphic_eq,
                        title: context.l10n.usbDsdOverPcm,
                        subtitle: context.l10n.usbDsdOverPcmDescription,
                        value: settings.usbDsdOverPcm,
                        onChanged: (value) => ref
                            .read(settingsProvider.notifier)
                            .setUsbDsdOverPcm(value),
                      ),
                      SettingsSwitchItem(
                        icon: Icons.volume_up_outlined,
                        title: context.l10n.usbFixedVolume,
                        subtitle: context.l10n.usbFixedVolumeDescription,
                        value: settings.usbAllowFixedVolume,
                        onChanged: (value) async {
                          if (value &&
                              !await _confirmAudioVolume(
                                context.l10n.usbFixedVolumeWarning,
                              )) {
                            return;
                          }
                          if (mounted) {
                            ref
                                .read(settingsProvider.notifier)
                                .setUsbAllowFixedVolume(value);
                          }
                        },
                      ),
                      ValueListenableBuilder<UsbVolumeState?>(
                        valueListenable: usbHardwareVolume,
                        builder: (context, volume, _) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.usbHardwareVolume,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                volume == null
                                    ? context.l10n.usbBitPerfectPending
                                    : volume.available
                                    ? '${volume.currentDb.toStringAsFixed(1)} dB'
                                    : context.l10n.usbVolumeUnavailable,
                              ),
                              if (volume?.available == true)
                                PlayerVolumeControl(
                                  foreground: colorScheme.onSurface,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    SettingsSwitchItem(
                      icon: Icons.headphones,
                      title: context.l10n.dapExclusive,
                      titleTrailing: const BetaBadge(),
                      subtitle: context.l10n.dapExclusiveDescription,
                      value: settings.dapExclusive,
                      onChanged: (value) => ref
                          .read(settingsProvider.notifier)
                          .setDapExclusive(value),
                      showDivider: false,
                    ),
                  ],
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverToBoxAdapter(
            child: SettingsSectionHeader(title: context.l10n.listeningStats),
          ),
          SliverToBoxAdapter(
            child: SettingsGroup(
              children: [
                SettingsItem(
                  icon: Icons.insights_outlined,
                  title: context.l10n.listeningStats,
                  subtitle: context.l10n.listeningStatsDescription,
                  onTap: () => Navigator.of(context).push(
                    slidePageRoute<void>(
                      page: const ListeningStatisticsScreen(),
                    ),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
