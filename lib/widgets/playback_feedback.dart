import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/providers/music_player_provider.dart';
import 'package:tango/widgets/app_snack_bar.dart';

/// Receives transient playback feedback across all foreground app routes.
class PlaybackFeedback extends ConsumerStatefulWidget {
  const PlaybackFeedback({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlaybackFeedback> createState() => _PlaybackFeedbackState();
}

class _PlaybackFeedbackState extends ConsumerState<PlaybackFeedback> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      playbackStateProvider.select((state) => state.value?.errorMessage),
      (previous, message) {
        if (message == null ||
            message == previous ||
            !mounted ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          return;
        }
        showAppSnackBar(
          context,
          content: Text(
            context.l10n.snackbarCannotOpenFile(context.friendlyError(message)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
