import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/providers/music_player_provider.dart';
import 'package:tango/utils/string_utils.dart';
import 'package:tango/widgets/audio_quality_badges.dart';
import 'package:tango/widgets/overflow_marquee.dart';
import 'package:tango/widgets/rhythm/rhythm_player_controls.dart';
import 'package:tango/widgets/rhythm/rhythm_ui.dart';

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Rhythm's mini player looks.
///
/// - [card]: Rhythm's Material mini player, a rounded card with a drag handle,
///   a progress bar and a time pill.
/// - [pill]: Rhythm's Expressive mini player, a stadium whose fill is the
///   progress.
/// - [compact]: Rhythm's horizontal tablet layout (previous, play, next) in a
///   shorter pill, with a progress ring around the play button.
enum RhythmMiniPlayerStyle { card, pill, compact }

@immutable
class RhythmMiniPlayerPrefs {
  const RhythmMiniPlayerPrefs({
    this.style = RhythmMiniPlayerStyle.pill,
    this.wavyProgress = true,
  });

  final RhythmMiniPlayerStyle style;

  /// The card's progress bar waves while playing (Rhythm's WAVY style).
  final bool wavyProgress;

  RhythmMiniPlayerPrefs copyWith({
    RhythmMiniPlayerStyle? style,
    bool? wavyProgress,
  }) => RhythmMiniPlayerPrefs(
    style: style ?? this.style,
    wavyProgress: wavyProgress ?? this.wavyProgress,
  );
}

const _styleKey = 'rhythm_mini_player_style';
const _wavyKey = 'rhythm_mini_player_wavy';

final rhythmMiniPlayerPrefsProvider =
    NotifierProvider<RhythmMiniPlayerPrefsNotifier, RhythmMiniPlayerPrefs>(
      RhythmMiniPlayerPrefsNotifier.new,
    );

class RhythmMiniPlayerPrefsNotifier extends Notifier<RhythmMiniPlayerPrefs> {
  @override
  RhythmMiniPlayerPrefs build() {
    _load();
    return const RhythmMiniPlayerPrefs();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      final name = prefs.getString(_styleKey);
      var next = state;
      for (final style in RhythmMiniPlayerStyle.values) {
        if (style.name == name) next = next.copyWith(style: style);
      }
      final wavy = prefs.getBool(_wavyKey);
      if (wavy != null) next = next.copyWith(wavyProgress: wavy);
      state = next;
    } catch (_) {}
  }

  Future<void> setStyle(RhythmMiniPlayerStyle style) async {
    state = state.copyWith(style: style);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_styleKey, style.name);
    } catch (_) {}
  }

  Future<void> setWavyProgress(bool value) async {
    state = state.copyWith(wavyProgress: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_wavyKey, value);
    } catch (_) {}
  }
}

/// Picker for the Appearance page.
class RhythmMiniPlayerSelector extends ConsumerWidget {
  const RhythmMiniPlayerSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(rhythmMiniPlayerPrefsProvider);
    final notifier = ref.read(rhythmMiniPlayerPrefsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<RhythmMiniPlayerStyle>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: RhythmMiniPlayerStyle.card,
                  label: Text('Card'),
                  icon: Icon(Icons.view_agenda_rounded),
                ),
                ButtonSegment(
                  value: RhythmMiniPlayerStyle.pill,
                  label: Text('Pill'),
                  icon: Icon(Icons.horizontal_rule_rounded),
                ),
                ButtonSegment(
                  value: RhythmMiniPlayerStyle.compact,
                  label: Text('Compact'),
                  icon: Icon(Icons.album_rounded),
                ),
              ],
              selected: {prefs.style},
              onSelectionChanged: (value) {
                HapticFeedback.selectionClick();
                notifier.setStyle(value.first);
              },
            ),
          ),
          if (prefs.style == RhythmMiniPlayerStyle.card)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wavy progress'),
              subtitle: const Text('The bar waves while music plays'),
              value: prefs.wavyProgress,
              onChanged: notifier.setWavyProgress,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Surface
// ---------------------------------------------------------------------------

/// Builds the track artwork at [size] with [radius] corners. The caller owns
/// the Hero and the geometry key.
typedef RhythmMiniArtworkBuilder =
    Widget Function(double size, BorderRadius radius);

/// The visible mini player in the Rhythm style. The caller keeps Tango's
/// swipe handling around it and supplies the actions.
class RhythmMiniPlayerSurface extends ConsumerWidget {
  const RhythmMiniPlayerSurface({
    super.key,
    required this.surfaceKey,
    required this.artworkBuilder,
    required this.trackKey,
    required this.title,
    required this.artist,
    required this.explicit,
    required this.duration,
    required this.isPlaying,
    required this.isLoading,
    required this.onOpen,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    this.bottomPadding = 8,
  });

  final GlobalKey surfaceKey;
  final RhythmMiniArtworkBuilder artworkBuilder;

  /// Changes with the track; triggers the small song-change bounce.
  final Object trackKey;
  final String title;
  final String artist;
  final bool explicit;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onOpen;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(rhythmMiniPlayerPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final play = RhythmMorphPlayPauseButton(
      isPlaying: isPlaying,
      isLoading: isLoading,
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPlayPause();
      },
      size: switch (prefs.style) {
        RhythmMiniPlayerStyle.card => 44,
        RhythmMiniPlayerStyle.pill => 56,
        RhythmMiniPlayerStyle.compact => 40,
      },
    );

    final content = switch (prefs.style) {
      RhythmMiniPlayerStyle.card => _CardBody(
        artworkBuilder: artworkBuilder,
        title: title,
        artist: artist,
        explicit: explicit,
        trackKey: trackKey,
        duration: duration,
        isPlaying: isPlaying,
        wavy: prefs.wavyProgress,
        playButton: play,
        nextButton: RhythmControlButton(
          icon: Icons.skip_next_rounded,
          size: 36,
          iconSize: 20,
          tooltip: l10n.nowPlayingNextTrack,
          onPressed: onNext,
        ),
      ),
      RhythmMiniPlayerStyle.pill => _PillBody(
        artworkBuilder: artworkBuilder,
        title: title,
        artist: artist,
        explicit: explicit,
        trackKey: trackKey,
        duration: duration,
        playButton: play,
      ),
      RhythmMiniPlayerStyle.compact => _CompactBody(
        artworkBuilder: artworkBuilder,
        title: title,
        artist: artist,
        explicit: explicit,
        trackKey: trackKey,
        duration: duration,
        playButton: play,
        previousButton: RhythmControlButton(
          icon: Icons.skip_previous_rounded,
          size: 36,
          iconSize: 20,
          tooltip: l10n.nowPlayingPreviousTrack,
          containerColor: Colors.transparent,
          contentColor: scheme.onSurface,
          onPressed: onPrevious,
        ),
        nextButton: RhythmControlButton(
          icon: Icons.skip_next_rounded,
          size: 36,
          iconSize: 20,
          tooltip: l10n.nowPlayingNextTrack,
          containerColor: Colors.transparent,
          contentColor: scheme.onSurface,
          onPressed: onNext,
        ),
      ),
    };

    final isCard = prefs.style == RhythmMiniPlayerStyle.card;
    final shape = isCard
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))
        : const StadiumBorder();
    final height = switch (prefs.style) {
      RhythmMiniPlayerStyle.card => null,
      RhythmMiniPlayerStyle.pill => 72.0,
      RhythmMiniPlayerStyle.compact => 64.0,
    };

    // The pill and compact styles fill from the left as the track plays, so
    // their progress is part of the surface; the card draws its own bar.
    final Widget body = isCard
        ? content
        : Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: _PillFill(
                  duration: duration,
                  color: prefs.style == RhythmMiniPlayerStyle.pill
                      ? scheme.primaryContainer
                      : scheme.primaryContainer.withValues(alpha: 0.45),
                ),
              ),
              content,
            ],
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPadding),
      child: _SpringPress(
        bounceKey: trackKey,
        child: Material(
          key: surfaceKey,
          color: scheme.surfaceContainer,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onOpen();
            },
            customBorder: shape,
            child: SizedBox(height: height, child: body),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

class _TrackText extends StatelessWidget {
  const _TrackText({
    required this.trackKey,
    required this.title,
    required this.artist,
    required this.explicit,
    required this.titleSize,
    required this.artistSize,
    required this.titleWeight,
    this.trailing,
  });

  final Object trackKey;
  final String title;
  final String artist;
  final bool explicit;
  final double titleSize;
  final double artistSize;
  final FontWeight titleWeight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OverflowMarquee(
          resetKey: (trackKey, title),
          child: ExplicitTrackTitle(
            title: title,
            explicit: explicit,
            style: text.titleMedium?.copyWith(
              fontSize: titleSize,
              fontWeight: titleWeight,
              color: scheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: OverflowMarquee(
                resetKey: (trackKey, artist),
                child: Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    fontSize: artistSize,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
      ],
    );
  }
}

/// Rhythm's Material mini player: handle, progress bar, then art, text with a
/// time pill, the morphing play button and a tonal next button.
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.artworkBuilder,
    required this.title,
    required this.artist,
    required this.explicit,
    required this.trackKey,
    required this.duration,
    required this.isPlaying,
    required this.wavy,
    required this.playButton,
    required this.nextButton,
  });

  final RhythmMiniArtworkBuilder artworkBuilder;
  final String title;
  final String artist;
  final bool explicit;
  final Object trackKey;
  final Duration duration;
  final bool isPlaying;
  final bool wavy;
  final Widget playButton;
  final Widget nextButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _LineProgress(
            duration: duration,
            playing: isPlaying,
            wavy: wavy,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            children: [
              artworkBuilder(56, BorderRadius.circular(14)),
              const SizedBox(width: 16),
              Expanded(
                child: _TrackText(
                  trackKey: trackKey,
                  title: title,
                  artist: artist,
                  explicit: explicit,
                  titleSize: 16,
                  artistSize: 13,
                  titleWeight: FontWeight.w600,
                  trailing: _TimePill(duration: duration),
                ),
              ),
              const SizedBox(width: 10),
              playButton,
              const SizedBox(width: 10),
              nextButton,
            ],
          ),
        ),
      ],
    );
  }
}

/// Rhythm's Expressive mini player: art inset in a stadium, bold text and a
/// large morphing play button. The fill behind it is the progress.
class _PillBody extends StatelessWidget {
  const _PillBody({
    required this.artworkBuilder,
    required this.title,
    required this.artist,
    required this.explicit,
    required this.trackKey,
    required this.duration,
    required this.playButton,
  });

  final RhythmMiniArtworkBuilder artworkBuilder;
  final String title;
  final String artist;
  final bool explicit;
  final Object trackKey;
  final Duration duration;
  final Widget playButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      child: Row(
        children: [
          artworkBuilder(60, BorderRadius.circular(18)),
          const SizedBox(width: 12),
          Expanded(
            child: _TrackText(
              trackKey: trackKey,
              title: title,
              artist: artist,
              explicit: explicit,
              titleSize: 16,
              artistSize: 13,
              titleWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          playButton,
        ],
      ),
    );
  }
}

/// Rhythm's horizontal tablet layout in a shorter pill: previous, play, next,
/// with the progress ring around the play button.
class _CompactBody extends StatelessWidget {
  const _CompactBody({
    required this.artworkBuilder,
    required this.title,
    required this.artist,
    required this.explicit,
    required this.trackKey,
    required this.duration,
    required this.playButton,
    required this.previousButton,
    required this.nextButton,
  });

  final RhythmMiniArtworkBuilder artworkBuilder;
  final String title;
  final String artist;
  final bool explicit;
  final Object trackKey;
  final Duration duration;
  final Widget playButton;
  final Widget previousButton;
  final Widget nextButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 0, 10, 0),
      child: Row(
        children: [
          artworkBuilder(46, BorderRadius.circular(14)),
          const SizedBox(width: 12),
          Expanded(
            child: _TrackText(
              trackKey: trackKey,
              title: title,
              artist: artist,
              explicit: explicit,
              titleSize: 14,
              artistSize: 12,
              titleWeight: FontWeight.w700,
            ),
          ),
          previousButton,
          _ProgressRing(
            duration: duration,
            size: 50,
            color: scheme.primary,
            trackColor: scheme.onSurface.withValues(alpha: 0.12),
            child: playButton,
          ),
          nextButton,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress pieces
// ---------------------------------------------------------------------------

double _progressOf(Duration position, Duration duration) {
  final total = duration.inMilliseconds;
  if (total <= 0) return 0;
  return (position.inMilliseconds / total).clamp(0.0, 1.0);
}

class _TimePill extends ConsumerWidget {
  const _TimePill({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playbackPositionProvider);
    if (duration <= Duration.zero || position <= Duration.zero) {
      return const SizedBox.shrink();
    }
    return RhythmTimePill(
      text:
          '${formatClock(position.inSeconds)}/${formatClock(duration.inSeconds)}',
    );
  }
}

/// Fills the stadium from the start as the track plays.
class _PillFill extends ConsumerWidget {
  const _PillFill({required this.duration, required this.color});

  final Duration duration;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = _progressOf(ref.watch(playbackPositionProvider), duration);
    final reduce = MediaQuery.disableAnimationsOf(context);
    // Playback progress fills left to right in right-to-left layouts too.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.001, 1.0),
              heightFactor: 1,
              child: value <= 0.002
                  ? const SizedBox.shrink()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin progress line that waves while playing (Rhythm's WAVY style) and
/// settles flat when paused. The ticker stops once the wave is flat.
class _LineProgress extends ConsumerStatefulWidget {
  const _LineProgress({
    required this.duration,
    required this.playing,
    required this.wavy,
  });

  final Duration duration;
  final bool playing;
  final bool wavy;

  @override
  ConsumerState<_LineProgress> createState() => _LineProgressState();
}

class _LineProgressState extends ConsumerState<_LineProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool get _animate =>
      widget.playing &&
      widget.wavy &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_LineProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_animate) {
      if (!_phase.isAnimating) _phase.repeat();
    } else {
      _phase.stop();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _progressOf(
      ref.watch(playbackPositionProvider),
      widget.duration,
    );
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _animate ? 3.0 : 0.0),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
          builder: (context, amplitude, _) => RepaintBoundary(
            child: AnimatedBuilder(
              animation: _phase,
              builder: (context, _) => CustomPaint(
                size: const Size(double.infinity, 12),
                painter: _LinePainter(
                  progress: progress,
                  phase: _phase.value * 2 * math.pi,
                  amplitude: amplitude,
                  color: scheme.primary,
                  trackColor: scheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.progress,
    required this.phase,
    required this.amplitude,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double phase;
  final double amplitude;
  final Color color;
  final Color trackColor;

  static const _stroke = 4.0;
  static const _waveLength = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final activeEnd = size.width * progress;
    final track = Paint()
      ..color = trackColor
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), track);
    if (activeEnd <= 0) return;

    final active = Paint()
      ..color = color
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (amplitude <= 0.01) {
      canvas.drawLine(Offset(0, midY), Offset(activeEnd, midY), active);
      return;
    }
    final path = Path()..moveTo(0, midY);
    for (var x = 0.0; x <= activeEnd; x += 1.5) {
      // Taper toward both ends of the played part.
      final taper = math.min(math.min(x, activeEnd - x) / 12, 1.0);
      final y =
          midY +
          math.sin(x / _waveLength * 2 * math.pi - phase) * amplitude * taper;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, active);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.amplitude != amplitude ||
      old.color != color ||
      old.trackColor != trackColor;
}

/// A circular progress ring around [child].
class _ProgressRing extends ConsumerWidget {
  const _ProgressRing({
    required this.duration,
    required this.size,
    required this.color,
    required this.trackColor,
    required this.child,
  });

  final Duration duration;
  final double size;
  final Color color;
  final Color trackColor;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = _progressOf(ref.watch(playbackPositionProvider), duration);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress,
                    color: color,
                    trackColor: trackColor,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  static const _stroke = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _stroke / 2,
      _stroke / 2,
      size.width - _stroke,
      size.height - _stroke,
    );
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (progress <= 0) return;
    final active = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _stroke;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, active);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}

// ---------------------------------------------------------------------------
// Spring press
// ---------------------------------------------------------------------------

/// Presses in on touch and springs back, and gives a small bounce when the
/// track changes (Rhythm's tap scale and song-change bounce). It listens to
/// raw pointers, so the swipe gestures and buttons around it keep working.
class _SpringPress extends StatefulWidget {
  const _SpringPress({required this.bounceKey, required this.child});

  final Object bounceKey;
  final Widget child;

  @override
  State<_SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<_SpringPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.55,
  );

  bool get _motion => !MediaQuery.disableAnimationsOf(context);

  void _to(double target) {
    if (!_motion) {
      _scale.value = 1;
      return;
    }
    _scale.animateWith(
      SpringSimulation(_spring, _scale.value, target, _scale.velocity),
    );
  }

  @override
  void didUpdateWidget(_SpringPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bounceKey != widget.bounceKey && _motion) {
      _scale.value = 1.03;
      _to(1);
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _to(0.97),
      onPointerUp: (_) => _to(1),
      onPointerCancel: (_) => _to(1),
      child: AnimatedBuilder(
        animation: _scale,
        child: widget.child,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
      ),
    );
  }
}
