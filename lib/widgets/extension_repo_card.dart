import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tango/providers/runtime_profile_provider.dart';
import 'package:tango/theme/tango_theme.dart';
import 'package:tango/widgets/app_content_card.dart';
import 'package:tango/widgets/tango_chrome.dart';

/// Repo cards share the Tango glass material, including their detail pages.
class ExtensionRepoCard extends ConsumerWidget {
  const ExtensionRepoCard({
    super.key,
    required this.child,
    this.color,
    this.radius = 20,
    this.margin = const EdgeInsets.all(4),
  });

  final Widget child;
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!context.isTango) {
      return AppContentCard(
        elevation: 0,
        color: color,
        margin: margin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
    }
    return Padding(
      padding: margin,
      // Repo pages scroll these cards over the plain page background, where a
      // backdrop blur is invisible but re-filters the whole card every frame.
      child: TangoGlass.navigation(
        radius: 24,
        blurEnabled: ref.watch(tangoBlurEnabledProvider),
        samplesBackdrop: false,
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}
