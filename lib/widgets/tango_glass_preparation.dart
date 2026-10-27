import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tango/providers/runtime_profile_provider.dart';
import 'package:tango/services/tango_glass_warmup.dart';
import 'package:tango/theme/tango_theme.dart';

/// Starts the one-time preparation when the full glass theme is enabled,
/// including switching to Tango or enabling blur after the app has started.
class TangoGlassPreparation extends ConsumerWidget {
  const TangoGlassPreparation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (context.isTango &&
        ref.watch(tangoGlassLevelProvider) == TangoGlassLevel.liquid &&
        TangoTheme.glassClarityOf(context) > 0.2 &&
        !ref.watch(
          tangoGlassContrastBlockedProvider(
            MediaQuery.highContrastOf(context),
          ),
        )) {
      unawaited(TangoGlassWarmup.prepare(View.of(context)));
    }
    return child;
  }
}
