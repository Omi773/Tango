import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/widgets/rhythm/rhythm_button_group.dart';
import 'package:tango/widgets/rhythm/rhythm_shapes.dart';

/// One onboarding step. [body] adds custom content under the text
/// (permission buttons, pickers, switches...).
class RhythmOnboardingPage {
  const RhythmOnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    this.body,
    this.canContinue = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? body;
  final bool canContinue;
}

/// Rhythm's onboarding: big rotating cookie hero, springy page indicator
/// and pill Back / Next buttons.
class RhythmOnboarding extends StatefulWidget {
  const RhythmOnboarding({
    super.key,
    required this.pages,
    required this.onFinish,
    this.onSkip,
    this.finishLabel = 'Get started',
  });

  final List<RhythmOnboardingPage> pages;
  final VoidCallback onFinish;
  final VoidCallback? onSkip;
  final String finishLabel;

  @override
  State<RhythmOnboarding> createState() => _RhythmOnboardingState();
}

class _RhythmOnboardingState extends State<RhythmOnboarding> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) => _controller.animateToPage(
    i,
    duration: const Duration(milliseconds: 460),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _index == widget.pages.length - 1;
    final page = widget.pages[_index];
    const presets = RhythmShapePreset.values;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: AnimatedOpacity(
                  opacity: !last && widget.onSkip != null ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: !last ? widget.onSkip : null,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.pages.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _index = i);
                },
                itemBuilder: (context, i) {
                  final p = widget.pages[i];
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final page = _controller.hasClients && _controller.position.haveDimensions
                          ? _controller.page ?? _index.toDouble()
                          : _index.toDouble();
                      final delta = (page - i).clamp(-1.0, 1.0);
                      return Opacity(
                        opacity: (1 - delta.abs() * 0.8).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(-delta * 40, 0),
                          child: child,
                        ),
                      );
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          RhythmCookieIcon(
                            icon: p.icon,
                            size: 168,
                            iconSize: 76,
                            color: scheme.primaryContainer,
                            preset: presets[i % (presets.length - 1)],
                            rotation: i * 0.4,
                          ),
                          const SizedBox(height: 36),
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            p.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          if (p.body != null) ...[
                            const SizedBox(height: 24),
                            p.body!,
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutBack,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 32 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? scheme.primary
                                : scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: _index == 0
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: RhythmButton(
                                  icon: Icons.arrow_back_rounded,
                                  type: RhythmButtonType.tonal,
                                  size: RhythmButtonSize.extraLarge,
                                  onPressed: () => _go(_index - 1),
                                ),
                              ),
                      ),
                      Expanded(
                        child: RhythmButton(
                          label: last ? widget.finishLabel : 'Next',
                          icon: last
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: RhythmButtonSize.extraLarge,
                          expand: true,
                          onPressed: page.canContinue
                              ? () => last ? widget.onFinish() : _go(_index + 1)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
