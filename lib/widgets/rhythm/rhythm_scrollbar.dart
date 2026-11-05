import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Draggable scrollbar with a floating label bubble (Rhythm's
/// ExpressiveScrollBar). Wrap any scrollable that uses [controller].
///
/// [labelBuilder] receives the scroll fraction (0..1) and returns the text
/// shown in the bubble while dragging, e.g. the current letter of an A-Z list.
class RhythmScrollBar extends StatefulWidget {
  const RhythmScrollBar({
    super.key,
    required this.controller,
    required this.child,
    this.labelBuilder,
    this.topPadding = 0,
    this.bottomPadding = 0,
    this.thumbHeight = 52,
  });

  final ScrollController controller;
  final Widget child;
  final String Function(double fraction)? labelBuilder;
  final double topPadding;
  final double bottomPadding;
  final double thumbHeight;

  @override
  State<RhythmScrollBar> createState() => _RhythmScrollBarState();
}

class _RhythmScrollBarState extends State<RhythmScrollBar> {
  bool _visible = false;
  bool _dragging = false;
  Timer? _hide;
  String _lastLetter = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(RhythmScrollBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hide?.cancel();
    super.dispose();
  }

  double get _fraction {
    final c = widget.controller;
    if (!c.hasClients) return 0;
    final max = c.position.maxScrollExtent;
    if (max <= 0) return 0;
    return (c.offset / max).clamp(0.0, 1.0);
  }

  bool get _scrollable =>
      widget.controller.hasClients &&
      widget.controller.position.maxScrollExtent > 200;

  void _onScroll() {
    if (!_scrollable) return;
    if (!_visible) setState(() => _visible = true);
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && !_dragging) setState(() => _visible = false);
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final track = constraints.maxHeight -
            widget.topPadding -
            widget.bottomPadding -
            widget.thumbHeight;
        final top = widget.topPadding + _fraction * (track < 0 ? 0 : track);
        final label = widget.labelBuilder?.call(_fraction);
        if (label != null && label != _lastLetter && _dragging) {
          _lastLetter = label;
          HapticFeedback.selectionClick();
        }
        return Stack(
          children: [
            widget.child,
            if (_scrollable)
              Positioned(
                right: 0,
                top: top,
                child: AnimatedOpacity(
                  opacity: _visible || _dragging ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Row(
                    children: [
                      AnimatedScale(
                        scale: _dragging && label != null ? 1 : 0.6,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _dragging && label != null ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              label ?? '',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (_) {
                          setState(() {
                            _dragging = true;
                            _visible = true;
                          });
                          _hide?.cancel();
                        },
                        onVerticalDragUpdate: (d) {
                          final c = widget.controller;
                          if (!c.hasClients || track <= 0) return;
                          final max = c.position.maxScrollExtent;
                          final next = (c.offset + d.delta.dy / track * max)
                              .clamp(0.0, max);
                          c.jumpTo(next);
                        },
                        onVerticalDragEnd: (_) {
                          setState(() => _dragging = false);
                          _onScroll();
                        },
                        child: Container(
                          width: 28,
                          height: widget.thumbHeight,
                          alignment: Alignment.centerRight,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: _dragging ? 10 : 6,
                            height: widget.thumbHeight - (_dragging ? 0 : 12),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: _dragging
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Helper: label of the first letter of the item at [fraction] in a sorted
/// list of titles.
String rhythmLetterFor(List<String> sortedTitles, double fraction) {
  if (sortedTitles.isEmpty) return '';
  final i = (fraction * (sortedTitles.length - 1)).round().clamp(
    0,
    sortedTitles.length - 1,
  );
  final t = sortedTitles[i].trim();
  if (t.isEmpty) return '#';
  final ch = t[0].toUpperCase();
  return RegExp(r'[A-Z]').hasMatch(ch) ? ch : '#';
}
