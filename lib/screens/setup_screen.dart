import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/providers/local_library_provider.dart';
import 'package:tango/providers/settings_provider.dart';
import 'package:tango/theme/material_expressive.dart';
import 'package:tango/theme/tango_theme.dart';
import 'package:tango/utils/desktop_folders.dart';
import 'package:tango/utils/desktop_platform.dart';
import 'package:tango/utils/logger.dart';
import 'package:tango/widgets/app_icon.dart';
import 'package:tango/widgets/app_loading_indicator.dart';
import 'package:tango/widgets/rhythm/rhythm_onboarding_kit.dart';

final _log = AppLogger('SetupScreen');

/// First-open screen: one welcome page. The library folder is created
/// automatically (no language, permission or folder steps).
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  bool _isLoading = false;

  Future<String> _defaultDirectory() async {
    if (isDesktopPlatform) {
      final desktopDir = await resolveDesktopDefaultOutputDirectory();
      if (desktopDir != null && desktopDir.isNotEmpty) return desktopDir;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final downloadDir = Directory('/storage/emulated/0/Download/Tango');
      try {
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      } catch (e) {
        debugPrint('Cannot create Download folder: $e');
      }
    }
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/Tango';
  }

  /// Best effort: scanning local audio on Android needs the audio permission.
  Future<void> _requestAndroidAudioAccess() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Permission.audio.request();
      await Permission.notification.request();
    } catch (e, stack) {
      _log.e('Permission request failed', e, stack);
    }
  }

  Future<void> _completeSetup() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _requestAndroidAudioAccess();
      final directory = await _defaultDirectory();
      final dir = Directory(directory);
      if (!await dir.exists()) await dir.create(recursive: true);

      final settings = ref.read(settingsProvider.notifier);
      settings.setStorageMode('app');
      settings.setDownloadDirectory(directory);
      settings.setDownloadTreeUri('');
      settings.setLocalLibraryEnabled(true);
      final library = ref.read(localLibraryProvider.notifier);
      final source = await library.addSource(
        path: directory,
        displayName: directory,
        bookmark: '',
      );
      unawaited(library.startSourceScan(source.id));

      settings.setTutorialComplete();
      await settings.setFirstLaunchComplete();
      if (mounted) context.go('/');
    } catch (e, stack) {
      _log.e('Failed to complete setup', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.snackbarError(context.friendlyError(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _rhythmOnboarding(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        RhythmOnboarding(
          finishLabel: l10n.setupGetStarted,
          onFinish: _completeSetup,
          pages: [
            RhythmOnboardingPage(
              icon: Icons.music_note_rounded,
              title: l10n.appName,
              description: l10n.setupRhythmWelcomeDescription,
            ),
            RhythmOnboardingPage(
              icon: Icons.folder_special_rounded,
              title: l10n.setupRhythmLibraryTitle,
              description: l10n.setupRhythmLibraryDescription,
            ),
            RhythmOnboardingPage(
              icon: Icons.tune_rounded,
              title: l10n.setupRhythmCustomizeTitle,
              description: l10n.setupRhythmCustomizeDescription,
            ),
          ],
        ),
        if (_isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32),
              child: const Center(child: AppLoadingIndicator(size: 64)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isRhythm) return _rhythmOnboarding(context);
    final colorScheme = Theme.of(context).colorScheme;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = (shortestSide * 0.24).clamp(80.0, 104.0);
    final titleGap = (shortestSide * 0.06).clamp(16.0, 32.0);
    final subtitleGap = (shortestSide * 0.04).clamp(8.0, 16.0);

    final button = materialExpressiveEnabled(context)
        ? MaterialExpressiveScope(
            child: M3EExtendedFab(
              label: context.l10n.setupGetStarted,
              icon: _isLoading
                  ? AppLoadingIndicator(size: 24, color: colorScheme.onPrimary)
                  : const AppIcon(Icons.check),
              color: M3EFabColor.primaryFilled,
              onPressed: _isLoading ? null : _completeSetup,
            ),
          )
        : FloatingActionButton.extended(
            onPressed: _isLoading ? null : _completeSetup,
            label: Text(context.l10n.setupGetStarted),
            icon: const Icon(Icons.check),
          );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      floatingActionButton: button,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo-transparent.png',
                    width: logoSize,
                    height: logoSize,
                    color: colorScheme.primary,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: titleGap),
                  Text(
                    context.l10n.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: subtitleGap),
                  Text(
                    'Local Music player',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
