import 'package:flutter/material.dart';
import 'package:tango/widgets/rhythm/rhythm.dart';

/// Shows every Rhythm kit component. Push it from anywhere:
/// `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RhythmKitGalleryScreen()));`
class RhythmKitGalleryScreen extends StatefulWidget {
  const RhythmKitGalleryScreen({super.key});

  @override
  State<RhythmKitGalleryScreen> createState() => _RhythmKitGalleryScreenState();
}

class _RhythmKitGalleryScreenState extends State<RhythmKitGalleryScreen> {
  String _mode = 'all';
  bool _switch = true;
  double _slider = 0.5;
  String _choice = 'b';
  bool _eqOn = true;
  final _gains = <double>[0, 2, 4, 1, -1, 0, 2, 3, 1, 0];
  final _position = ValueNotifier<Duration>(Duration.zero);

  static final _lines = parseRhythmLrc(
    '[00:00.00] Rhythm lyrics preview\n'
    '[00:04.00] Tap a line to jump\n'
    '[00:08.00] Active line is big and bright\n'
    '[00:12.00] Others fade into the background\n'
    '[00:16.00] Scroll to browse, it follows when you stop',
  );

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RhythmSettingsScaffold(
      title: 'Rhythm kit',
      hero: const RhythmSettingsHeroCard(
        title: 'Rhythm UI',
        subtitle: 'Every component in one place',
        icon: Icons.palette_rounded,
      ),
      children: [
        RhythmSettingsSection(
          title: 'Buttons',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  RhythmToggleButtonGroup<String>(
                    options: const [
                      RhythmToggleOption(value: 'all', label: 'All'),
                      RhythmToggleOption(value: 'songs', label: 'Songs'),
                      RhythmToggleOption(value: 'albums', label: 'Albums'),
                    ],
                    selected: _mode,
                    onChanged: (v) => setState(() => _mode = v),
                  ),
                  const SizedBox(height: 16),
                  RhythmActionButtonRow(
                    actions: [
                      RhythmDetailAction(
                        icon: Icons.play_arrow_rounded,
                        label: 'Play',
                        primary: true,
                        onTap: () {},
                      ),
                      RhythmDetailAction(
                        icon: Icons.shuffle_rounded,
                        label: 'Shuffle',
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        RhythmSettingsSection(
          title: 'Settings tiles',
          children: [
            RhythmSettingsSwitchTile(
              title: 'Switch',
              subtitle: 'Grouped tile with a tonal icon',
              icon: Icons.tune_rounded,
              value: _switch,
              onChanged: (v) => setState(() => _switch = v),
            ),
            RhythmSettingsSliderTile(
              title: 'Slider',
              icon: Icons.volume_up_rounded,
              tone: RhythmMenuTone.tertiary,
              value: _slider,
              min: 0,
              max: 1,
              format: (v) => '${(v * 100).round()}%',
              onChanged: (v) => setState(() => _slider = v),
            ),
            RhythmSettingsChoiceTile<String>(
              title: 'Choice',
              icon: Icons.style_rounded,
              options: const [
                RhythmOption(value: 'a', title: 'Option A', subtitle: 'First'),
                RhythmOption(value: 'b', title: 'Option B', subtitle: 'Second'),
                RhythmOption(value: 'c', title: 'Option C', subtitle: 'Third'),
              ],
              value: _choice,
              onChanged: (v) => setState(() => _choice = v),
            ),
          ],
        ),
        RhythmSettingsSection(
          title: 'Dialogs and sheets',
          children: [
            RhythmSettingsTile(
              title: 'Confirm dialog',
              icon: Icons.warning_amber_rounded,
              tone: RhythmMenuTone.error,
              onTap: () => showRhythmConfirmDialog(
                context,
                title: 'Delete playlist?',
                message: 'This cannot be undone.',
                confirmLabel: 'Delete',
                destructive: true,
                icon: Icons.delete_rounded,
              ),
            ),
            RhythmSettingsTile(
              title: 'Playback speed',
              icon: Icons.speed_rounded,
              onTap: () => showRhythmSpeedDialog(context),
            ),
            RhythmSettingsTile(
              title: 'Playback pitch',
              icon: Icons.graphic_eq_rounded,
              onTap: () => showRhythmPitchDialog(context),
            ),
            RhythmSettingsTile(
              title: 'Sleep timer',
              icon: Icons.bedtime_rounded,
              tone: RhythmMenuTone.secondary,
              onTap: () => showRhythmSleepTimerSheet(context),
            ),
            RhythmSettingsTile(
              title: 'Speed and pitch sheet',
              icon: Icons.tune_rounded,
              onTap: () => showRhythmSpeedPitchSheet(
                context,
                speed: 1,
                pitch: 1,
                onChanged: (speed, pitch) {},
              ),
            ),
            RhythmSettingsTile(
              title: 'Song info',
              icon: Icons.info_outline_rounded,
              tone: RhythmMenuTone.secondary,
              onTap: () => showRhythmSongInfoSheet(
                context,
                title: 'Song title',
                artist: 'Artist',
                rows: const [
                  RhythmInfoRow('Album', 'Album name'),
                  RhythmInfoRow('Format', 'FLAC'),
                  RhythmInfoRow('Sample rate', '96 kHz'),
                  RhythmInfoRow('Bit depth', '24-bit'),
                ],
              ),
            ),
            RhythmSettingsTile(
              title: 'Add to playlist',
              icon: Icons.playlist_add_rounded,
              onTap: () => showRhythmAddToPlaylistSheet(
                context,
                songTitle: 'Song title',
                playlists: const [
                  RhythmPlaylistOption(id: '1', name: 'Favourites', trackCount: 24),
                  RhythmPlaylistOption(id: '2', name: 'Road trip', trackCount: 61),
                ],
              ),
            ),
            RhythmSettingsTile(
              title: 'Song picker',
              icon: Icons.library_add_check_rounded,
              onTap: () => showRhythmSongPickerSheet(
                context,
                items: [
                  for (var i = 1; i <= 30; i++)
                    RhythmPickerItem(
                      id: '$i',
                      title: 'Track $i',
                      subtitle: 'Artist $i',
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 260, child: RhythmCookieEmptyState(
          title: 'Nothing here yet',
          subtitle: 'The cookie cluster empty state',
        )),
        const Center(child: RhythmLoadingIndicator()),
        const SizedBox(height: 20),
        const RhythmWavyLoader(height: 16),
        const SizedBox(height: 20),
        const RhythmMarquee(
          'A very long song title that does not fit on a single line of the screen',
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 320,
          child: RhythmSyncedLyricsView(
            lines: _lines,
            position: _position,
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 120),
            fontSize: 24,
            onSeek: (d) => _position.value = d,
          ),
        ),
        const SizedBox(height: 16),
        RhythmEqualizerPanel(
          gains: _gains,
          labels: const ['32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'],
          enabled: _eqOn,
          onEnabledChanged: (v) => setState(() => _eqOn = v),
          onBandChanged: (i, g) => setState(() => _gains[i] = g),
          presets: const {
            'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            'Bass': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
          },
          onPreset: (name) => setState(() {
            final p = const {
              'Flat': [0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
              'Bass': [6.0, 5, 4, 2, 0, 0, 0, 0, 0, 0],
            }[name]!;
            for (var i = 0; i < _gains.length; i++) {
              _gains[i] = p[i].toDouble();
            }
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(
              child: RhythmStatCard(
                value: '128h',
                label: 'Listened',
                icon: Icons.headphones_rounded,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: RhythmStatCard(
                value: '2,431',
                label: 'Songs',
                icon: Icons.music_note_rounded,
                color: Color(0xFF3A5BA9),
                onColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const RhythmBarChart(
          values: [3, 5, 2, 8, 6, 9, 4],
          labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          highlight: 5,
        ),
      ],
    );
  }
}
