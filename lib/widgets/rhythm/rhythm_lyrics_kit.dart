import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A timed word inside a lyric line (word-by-word / karaoke lyrics).
class RhythmLyricWord {
  const RhythmLyricWord({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final Duration start;
  final Duration end;
}

/// One lyric line. [words] is optional; without it the whole line lights up.
class RhythmLyricLine {
  const RhythmLyricLine({
    required this.time,
    required this.text,
    this.words,
    this.translation,
  });

  final Duration time;
  final String text;
  final List<RhythmLyricWord>? words;
  final String? translation;
}

/// Parses standard `[mm:ss.xx] text` LRC into lines (unsynced text becomes
/// zero-time lines).
List<RhythmLyricLine> parseRhythmLrc(String lrc) {
  final stamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final out = <RhythmLyricLine>[];
  for (final raw in lrc.split('\n')) {
    final matches = stamp.allMatches(raw).toList();
    if (matches.isEmpty) continue;
    final text = raw.substring(matches.last.end).trim();
    for (final m in matches) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final fracRaw = m.group(3) ?? '0';
      final ms = int.parse(fracRaw.padRight(3, '0').substring(0, 3));
      out.add(
        RhythmLyricLine(
          time: Duration(minutes: min, seconds: sec, milliseconds: ms),
          text: text,
        ),
      );
    }
  }
  out.sort((a, b) => a.time.compareTo(b.time));
  return out;
}

/// Index of the line active at [position], or -1 before the first line.
int rhythmActiveLyricIndex(List<RhythmLyricLine> lines, Duration position) {
  var lo = 0;
  var hi = lines.length - 1;
  var ans = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].time <= position) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans;
}

/// Synced lyrics list. The active line is large and bright, others dim and
/// slightly smaller. Auto-scrolls to the active line; dragging pauses
/// auto-scroll for a few seconds. Tapping a line calls [onSeek].
class RhythmSyncedLyricsView extends StatefulWidget {
  const RhythmSyncedLyricsView({
    super.key,
    required this.lines,
    required this.position,
    this.onSeek,
    this.textAlign = TextAlign.start,
    this.fontSize = 28,
    this.activeColor,
    this.inactiveColor,
    this.padding = const EdgeInsets.fromLTRB(24, 120, 24, 200),
    this.showTranslation = true,
  });

  final List<RhythmLyricLine> lines;
  final ValueListenable<Duration> position;
  final ValueChanged<Duration>? onSeek;
  final TextAlign textAlign;
  final double fontSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final EdgeInsets padding;
  final bool showTranslation;

  @override
  State<RhythmSyncedLyricsView> createState() => _RhythmSyncedLyricsViewState();
}

class _RhythmSyncedLyricsViewState extends State<RhythmSyncedLyricsView> {
  final _keys = <int, GlobalKey>{};
  int _active = -1;
  DateTime _userScrollUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.position.addListener(_onPosition);
    _active = rhythmActiveLyricIndex(widget.lines, widget.position.value);
  }

  @override
  void didUpdateWidget(RhythmSyncedLyricsView old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position) {
      old.position.removeListener(_onPosition);
      widget.position.addListener(_onPosition);
    }
  }

  @override
  void dispose() {
    widget.position.removeListener(_onPosition);
    super.dispose();
  }

  void _onPosition() {
    final idx = rhythmActiveLyricIndex(widget.lines, widget.position.value);
    if (idx != _active) {
      setState(() => _active = idx);
      _scrollToActive();
    } else if (widget.lines.isNotEmpty &&
        idx >= 0 &&
        widget.lines[idx].words != null) {
      setState(() {});
    }
  }

  void _scrollToActive() {
    if (DateTime.now().isBefore(_userScrollUntil) || _active < 0) return;
    final ctx = _keys[_active]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.32,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? scheme.onSurface;
    final inactive =
        widget.inactiveColor ?? scheme.onSurface.withValues(alpha: 0.32);
    return NotificationListener<ScrollStartNotification>(
      onNotification: (n) {
        if (n.dragDetails != null) {
          _userScrollUntil = DateTime.now().add(const Duration(seconds: 4));
        }
        return false;
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: switch (widget.textAlign) {
            TextAlign.center => CrossAxisAlignment.center,
            TextAlign.end || TextAlign.right => CrossAxisAlignment.end,
            _ => CrossAxisAlignment.start,
          },
          children: [
            for (var i = 0; i < widget.lines.length; i++)
              _line(context, i, active, inactive),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, int i, Color active, Color inactive) {
    final line = widget.lines[i];
    final isActive = i == _active;
    final distance = (i - _active).abs();
    final key = _keys.putIfAbsent(i, GlobalKey.new);
    final size = widget.fontSize * (isActive ? 1 : 0.82);
    final base = Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontSize: size,
      height: 1.25,
      fontWeight: FontWeight.w800,
    );
    Widget text;
    if (isActive && line.words != null && line.words!.isNotEmpty) {
      text = _WordLine(
        words: line.words!,
        position: widget.position.value,
        style: base,
        active: active,
        inactive: inactive,
        align: widget.textAlign,
      );
    } else {
      text = AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        style: base.copyWith(color: isActive ? active : inactive),
        textAlign: widget.textAlign,
        child: Text(line.text.isEmpty ? '♪' : line.text, textAlign: widget.textAlign),
      );
    }
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSeek == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onSeek!(line.time);
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 380),
        opacity: _active < 0 ? 1 : (distance > 6 ? 0.5 : 1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              if (widget.showTranslation && line.translation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    line.translation!,
                    textAlign: widget.textAlign,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isActive ? active.withValues(alpha: 0.7) : inactive,
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

class _WordLine extends StatelessWidget {
  const _WordLine({
    required this.words,
    required this.position,
    required this.style,
    required this.active,
    required this.inactive,
    required this.align,
  });

  final List<RhythmLyricWord> words;
  final Duration position;
  final TextStyle style;
  final Color active;
  final Color inactive;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: switch (align) {
        TextAlign.center => WrapAlignment.center,
        TextAlign.end || TextAlign.right => WrapAlignment.end,
        _ => WrapAlignment.start,
      },
      children: [
        for (final w in words)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Word(
              word: w,
              progress: _progress(w),
              style: style,
              active: active,
              inactive: inactive,
            ),
          ),
      ],
    );
  }

  double _progress(RhythmLyricWord w) {
    if (position <= w.start) return 0;
    if (position >= w.end) return 1;
    final total = (w.end - w.start).inMicroseconds;
    if (total <= 0) return 1;
    return (position - w.start).inMicroseconds / total;
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.word,
    required this.progress,
    required this.style,
    required this.active,
    required this.inactive,
  });

  final RhythmLyricWord word;
  final double progress;
  final TextStyle style;
  final Color active;
  final Color inactive;

  @override
  Widget build(BuildContext context) {
    // Soft left-to-right fill with a lifted baseline while it is sung.
    return Transform.translate(
      offset: Offset(0, -3 * (progress > 0 && progress < 1 ? 1 : 0)),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          colors: [active, active, inactive, inactive],
          stops: [0, progress, (progress + 0.12).clamp(0.0, 1.0), 1],
        ).createShader(rect),
        child: Text(word.text, style: style.copyWith(color: Colors.white)),
      ),
    );
  }
}

/// Minimal editor surface for a single LRC text. Returns text via [onSave].
class RhythmLyricsEditor extends StatefulWidget {
  const RhythmLyricsEditor({
    super.key,
    required this.initial,
    required this.onSave,
    this.hint = '[00:12.00] First line...',
  });

  final String initial;
  final ValueChanged<String> onSave;
  final String hint;

  @override
  State<RhythmLyricsEditor> createState() => _RhythmLyricsEditorState();
}

class _RhythmLyricsEditorState extends State<RhythmLyricsEditor> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _c,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', height: 1.5),
              decoration: InputDecoration(
                hintText: widget.hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => widget.onSave(_c.text),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Save lyrics'),
        ),
      ],
    );
  }
}
