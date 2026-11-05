import 'package:flutter/material.dart';

/// Single-line text that scrolls horizontally when it does not fit
/// (Rhythm's MarqueeText).
class RhythmMarquee extends StatefulWidget {
  const RhythmMarquee(
    this.text, {
    super.key,
    this.style,
    this.velocity = 36,
    this.pause = const Duration(milliseconds: 1200),
    this.gap = 40,
  });

  final String text;
  final TextStyle? style;

  /// Logical pixels per second.
  final double velocity;
  final Duration pause;
  final double gap;

  @override
  State<RhythmMarquee> createState() => _RhythmMarqueeState();
}

class _RhythmMarqueeState extends State<RhythmMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  double _cycle = 0;
  bool _running = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _start(double distance) async {
    if (_running) return;
    _running = true;
    while (mounted && _running) {
      await Future<void>.delayed(widget.pause);
      if (!mounted) return;
      _c.duration = Duration(
        milliseconds: (distance / widget.velocity * 1000).round().clamp(300, 600000),
      );
      await _c.forward(from: 0).orCancel.catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final textWidth = painter.width;
        if (!constraints.hasBoundedWidth || textWidth <= constraints.maxWidth) {
          _running = false;
          return Text(widget.text, style: style, maxLines: 1, softWrap: false);
        }
        _cycle = textWidth + widget.gap;
        _start(_cycle);
        return SizedBox(
          height: painter.height,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final dx = -_c.value * _cycle;
                return OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: Transform.translate(
                    offset: Offset(dx, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.text, style: style, maxLines: 1, softWrap: false),
                        SizedBox(width: widget.gap),
                        Text(widget.text, style: style, maxLines: 1, softWrap: false),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
