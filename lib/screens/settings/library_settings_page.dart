import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tango/widgets/app_alert_dialog.dart';
import 'package:tango/widgets/app_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/models/settings.dart';
import 'package:tango/providers/settings_provider.dart';
import 'package:tango/providers/download_history_provider.dart';
import 'package:tango/providers/local_library_provider.dart';
import 'package:tango/services/library_database.dart';
import 'package:tango/services/platform_bridge.dart';
import 'package:tango/utils/adaptive_layout.dart';
import 'package:tango/widgets/duplicate_review_sheet.dart';
import 'package:tango/widgets/app_bottom_sheet.dart';
import 'package:tango/widgets/settings_group.dart';
import 'package:tango/widgets/app_icon.dart';
import 'package:tango/widgets/app_loading_indicator.dart';
import 'package:tango/widgets/app_progress_indicator.dart';
import 'package:tango/widgets/expressive_button.dart';
import 'package:tango/widgets/app_sliver_header.dart';
import 'package:tango/widgets/ios_library_folder_sheet.dart';

part 'library_settings_page_widgets.dart';

class LibrarySettingsPage extends ConsumerStatefulWidget {
  const LibrarySettingsPage({super.key});

  @override
  ConsumerState<LibrarySettingsPage> createState() =>
      _LibrarySettingsPageState();
}

class _LibrarySettingsPageState extends ConsumerState<LibrarySettingsPage> {
  int _androidSdkVersion = 0;
  bool _hasStoragePermission = false;
  bool _isCleaningMissingFiles = false;

  String _getDisplayPath(String path) {
    if (!path.startsWith('content://')) return path;
    try {
      final uri = Uri.parse(path);
      final treePath = uri.pathSegments.last;
      final decoded = Uri.decodeComponent(treePath);
      if (decoded.startsWith('primary:')) {
        return '/storage/emulated/0/${decoded.substring('primary:'.length)}';
      }
      return decoded;
    } catch (_) {
      return path;
    }
  }

  @override
  void initState() {
    super.initState();
    _initDeviceInfo();
  }

  Future<void> _initDeviceInfo() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      if (mounted) {
        setState(() {
          _androidSdkVersion = sdkVersion;
          _hasStoragePermission = sdkVersion >= 29 ? true : false;
        });
        if (sdkVersion < 29) {
          final hasPermission = await Permission.storage.isGranted;
          if (mounted) {
            setState(() => _hasStoragePermission = hasPermission);
          }
        }
      }
    } else if (Platform.isIOS) {
      setState(() => _hasStoragePermission = true);
    } else {
      setState(() => _hasStoragePermission = true);
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    if (_androidSdkVersion >= 29) return true;

    final status = await Permission.storage.request();

    if (status.isGranted) {
      setState(() => _hasStoragePermission = true);
      return true;
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        final shouldOpen = await showAppDialog<bool>(
          context: context,
          builder: (context) => AppAlertDialog(
            title: Text(context.l10n.libraryStorageAccessRequired),
            content: Text(context.l10n.libraryStorageAccessMessage),
            actions: [
              AppDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.dialogCancel),
              ),
              AppDialogAction(
                filled: true,
                isDefault: true,
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.setupOpenSettings),
              ),
            ],
          ),
        );
        if (shouldOpen == true) {
          await openAppSettings();
        }
      }
    }
    return false;
  }

  Future<void> _pickLibraryFolder() async {
    if (Platform.isAndroid && _androidSdkVersion >= 29) {
      // Use SAF tree picker - no MANAGE_EXTERNAL_STORAGE needed
      final result = await PlatformBridge.pickSafTree();
      if (result != null) {
        final treeUri = result['tree_uri'] as String? ?? '';
        if (treeUri.isNotEmpty) {
          final source = await ref
              .read(localLibraryProvider.notifier)
              .addSource(
                path: treeUri,
                displayName:
                    result['display_name'] as String? ??
                    _getDisplayPath(treeUri),
                volumeId: result['volume_id'] as String?,
                isRemovable: result['is_removable'] == true,
              );
          await ref
              .read(localLibraryProvider.notifier)
              .startSourceScan(source.id);
        }
      }
    } else {
      // Older Android needs storage permission; iOS chooses internal or Files.
      if (!_hasStoragePermission) {
        final granted = await _requestStoragePermission();
        if (!granted) return;
      }
      if (Platform.isIOS) {
        if (!mounted) return;
        IosPickedDirectory? picked;
        try {
          // Straight to the Files folder picker: the folder is bookmarked and
          // played in place, so nothing is copied into the app.
          picked = await PlatformBridge.pickIosDirectory();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.snackbarFolderPickerFailed(
                    context.friendlyError(e),
                  ),
                ),
              ),
            );
          }
          return;
        }
        if (picked != null && mounted) {
          final library = ref.read(localLibraryProvider.notifier);
          final source = await library.addSource(
            path: picked.path,
            displayName: picked.bookmark.isEmpty
                ? context.l10n.setupAppDocumentsFolder
                : picked.path,
            bookmark: picked.bookmark,
          );
          await library.startSourceScan(source.id);
        }
        return;
      }
      String? result;
      try {
        result = await FilePicker.getDirectoryPath();
      } catch (e) {
        // Linux reaches the picker through the desktop portal, which a
        // session may not run.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.snackbarFolderPickerFailed(
                  context.friendlyError(e),
                ),
              ),
            ),
          );
        }
        return;
      }
      if (result != null) {
        final source = await ref
            .read(localLibraryProvider.notifier)
            .addSource(path: result, displayName: result);
        await ref
            .read(localLibraryProvider.notifier)
            .startSourceScan(source.id);
      }
    }
  }

  /// Adds individual audio files. iOS copies them into the app (Imported
  /// folder, scanned with the Documents source); other platforms copy them
  /// into the app's music folder.
  Future<void> _addSongs() async {
    try {
      final library = ref.read(localLibraryProvider.notifier);
      if (Platform.isIOS) {
        final imported = await PlatformBridge.importIosAudio();
        if (imported == null || !mounted) return;
        if (imported.imported + imported.skipped == 0) {
          throw const FormatException('No songs could be imported');
        }
        for (final source in ref.read(localLibraryProvider).sources) {
          await library.startSourceScan(source.id);
        }
        return;
      }
      final picked = await FilePicker.pickFiles(type: FileType.audio);
      if (picked.isEmpty || !mounted) return;
      final target = ref.read(settingsProvider).downloadDirectory;
      if (target.isEmpty || target.startsWith('content://')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a library folder first')),
        );
        return;
      }
      await Directory(target).create(recursive: true);
      for (final file in picked) {
        final path = file.path;
        if (path == null) continue;
        await File(path).copy('$target/${file.name}');
      }
      for (final source in ref.read(localLibraryProvider).sources) {
        await library.startSourceScan(source.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.snackbarError(context.friendlyError(e)))),
        );
      }
    }
  }

  Future<void> _startScan({bool forceFullScan = false}) async {
    final sources = ref.read(localLibraryProvider).sources;
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.libraryScanSelectFolderFirst)),
      );
      return;
    }
    await ref
        .read(localLibraryProvider.notifier)
        .scanAllSources(forceFullScan: forceFullScan);
  }

  Future<void> _cancelScan() async {
    await ref.read(localLibraryProvider.notifier).cancelScan();
  }

  Future<void> _pauseScan() async {
    await ref.read(localLibraryProvider.notifier).pauseScan();
  }

  Future<void> _resumeScan() async {
    await ref.read(localLibraryProvider.notifier).resumeScan();
  }

  Future<void> _clearLibrary() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.libraryClearConfirmTitle),
        content: Text(context.l10n.libraryClearConfirmMessage),
        actions: [
          AppDialogAction(
            isDefault: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.dialogCancel),
          ),
          AppDialogAction(
            filled: true,
            isDestructive: true,
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.dialogClear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(localLibraryProvider.notifier).clearLibrary();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.libraryCleared)));
      }
    }
  }

  Future<void> _cleanupMissingFiles() async {
    if (_isCleaningMissingFiles || ref.read(localLibraryProvider).isScanning) {
      return;
    }
    final library = ref.read(localLibraryProvider.notifier);
    final downloads = ref.read(downloadHistoryProvider.notifier);
    setState(() => _isCleaningMissingFiles = true);
    try {
      final missingLibraryEntries = await library.cleanupMissingFiles();
      final orphanedDownloads = await downloads.cleanupOrphanedDownloads();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.libraryRemovedMissingFiles(
              missingLibraryEntries + orphanedDownloads,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.snackbarError(context.friendlyError(error)),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCleaningMissingFiles = false);
    }
  }

  Future<void> _removeSource(LocalLibrarySource source) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.libraryRemoveFolder),
        content: Text(context.l10n.libraryRemoveFolderMessage),
        actions: [
          AppDialogAction(
            isDefault: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.dialogCancel),
          ),
          AppDialogAction(
            filled: true,
            isDestructive: true,
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.dialogRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(localLibraryProvider.notifier).removeSource(source.id);
    final settings = ref.read(settingsProvider);
    if (settings.localLibraryPath == source.path) {
      ref
          .read(settingsProvider.notifier)
          .setLocalLibraryPathAndBookmark('', '');
    }
  }

  String _getAutoScanLabel(BuildContext context, String mode) {
    switch (mode) {
      case 'on_open':
        return context.l10n.libraryAutoScanOnOpen;
      case 'daily':
        return context.l10n.libraryAutoScanDaily;
      case 'weekly':
        return context.l10n.libraryAutoScanWeekly;
      default:
        return context.l10n.libraryAutoScanOff;
    }
  }

  void _showAutoScanPicker(BuildContext context, String current) {
    showAppScrollableBottomSheet<void>(
      context: context,
      title: context.l10n.libraryAutoScan,
      subtitle: context.l10n.libraryAutoScanSubtitle,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AutoScanOption(
              icon: Icons.block,
              title: context.l10n.libraryAutoScanOff,
              selected: current == 'off',
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .setLocalLibraryAutoScan('off');
                Navigator.pop(context);
              },
            ),
            _AutoScanOption(
              icon: Icons.open_in_new,
              title: context.l10n.libraryAutoScanOnOpen,
              selected: current == 'on_open',
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .setLocalLibraryAutoScan('on_open');
                Navigator.pop(context);
              },
            ),
            _AutoScanOption(
              icon: Icons.today,
              title: context.l10n.libraryAutoScanDaily,
              selected: current == 'daily',
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .setLocalLibraryAutoScan('daily');
                Navigator.pop(context);
              },
            ),
            _AutoScanOption(
              icon: Icons.date_range,
              title: context.l10n.libraryAutoScanWeekly,
              selected: current == 'weekly',
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .setLocalLibraryAutoScan('weekly');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // The app Documents source is managed automatically (it also scans
    // imported songs), so it is not listed.
    final librarySources = ref
        .watch(localLibraryProvider.select((state) => state.sources))
        .where((source) => source.displayName != 'App Documents Folder')
        .toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          AppSliverHeader.page(title: context.l10n.libraryTitle),

          // Scan snapshots land ~2.5x/s; keep the per-snapshot rebuild scoped
          // to the widgets that actually display scan state instead of the
          // whole settings page.
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, _) {
                final libraryState = ref.watch(localLibraryProvider);
                return _LibraryHeroCard(
                  itemCount: libraryState.totalCount,
                  excludedDownloadedCount: libraryState.excludedDownloadedCount,
                  isScanning: libraryState.isScanning,
                  scanIsFinalizing: libraryState.scanIsFinalizing,
                  scanIsPaused: libraryState.scanIsPaused,
                  scanProgress: libraryState.scanProgress,
                  scanCurrentFile: libraryState.scanCurrentFile,
                  scanTotalFiles: libraryState.scanTotalFiles,
                  scannedFiles: libraryState.scannedFiles,
                  lastScannedAt: libraryState.lastScannedAt,
                );
              },
            ),
          ),

          SliverToBoxAdapter(
            child: SettingsSectionHeader(
              title: context.l10n.libraryScanSettings,
            ),
          ),
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, _) {
                final status = ref.watch(
                  localLibraryProvider.select(
                    (state) =>
                        (loading: state.isLoading, failed: state.loadFailed),
                  ),
                );
                if (!status.loading && !status.failed) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: status.loading
                      ? const AppLoadingIndicator(size: 24, strokeWidth: 2)
                      : AppIcon(Icons.error_outline, color: colorScheme.error),
                  title: Text(
                    status.loading
                        ? context.l10n.libraryLoading
                        : context.l10n.libraryLoadFailed,
                  ),
                  trailing: status.loading
                      ? null
                      : ExpressiveButton(
                          text: true,
                          onPressed: () => ref
                              .read(localLibraryProvider.notifier)
                              .reloadFromStorage(),
                          child: Text(context.l10n.dialogRetry),
                        ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SettingsGroup(
              connected: true,
              children: [
                for (final source in librarySources)
                  Consumer(
                    builder: (context, ref, _) {
                      final scan = ref.watch(
                        localLibraryProvider.select((state) {
                          final active = state.scanningSourceId == source.id;
                          return (
                            active: active,
                            finalizing: active && state.scanIsFinalizing,
                            paused: active && state.scanIsPaused,
                            scanned: active ? state.scannedFiles : 0,
                            total: active ? state.scanTotalFiles : 0,
                            progress: active ? state.scanProgress : 0.0,
                          );
                        }),
                      );
                      return _LibrarySourceSettingsItem(
                        source: source,
                        isScanning: scan.active,
                        isFinalizing: scan.finalizing,
                        isPaused: scan.paused,
                        scannedFiles: scan.scanned,
                        totalFiles: scan.total,
                        progress: scan.progress,
                        enabled: settings.localLibraryEnabled,
                        locked:
                            Platform.isIOS &&
                            !source.path.startsWith('network://') &&
                            (source.bookmark == null ||
                                source.bookmark!.trim().isEmpty),
                        onEnabledChanged: (value) => ref
                            .read(localLibraryProvider.notifier)
                            .setSourceEnabled(source.id, value),
                        onScan: () => ref
                            .read(localLibraryProvider.notifier)
                            .startSourceScan(source.id),
                        onFullScan: () => ref
                            .read(localLibraryProvider.notifier)
                            .startSourceScan(source.id, forceFullScan: true),
                        onRemove: () => _removeSource(source),
                      );
                    },
                  ),
                Opacity(
                  opacity: settings.localLibraryEnabled ? 1.0 : 0.5,
                  child: SettingsItem(
                    icon: Icons.create_new_folder_outlined,
                    title: context.l10n.libraryAddFolder,
                    subtitle: librarySources.isEmpty
                        ? context.l10n.libraryFolderHint
                        : context.l10n.libraryAddFolderSubtitle,
                    onTap: settings.localLibraryEnabled
                        ? _pickLibraryFolder
                        : null,
                  ),
                ),
                Opacity(
                  opacity: settings.localLibraryEnabled ? 1.0 : 0.5,
                  child: SettingsItem(
                    icon: Icons.library_music_outlined,
                    title: 'Add songs',
                    subtitle: 'Pick audio files to add to your library',
                    onTap: settings.localLibraryEnabled ? _addSongs : null,
                  ),
                ),
                SettingsSwitchItem(
                  icon: Icons.content_copy_outlined,
                  title: context.l10n.libraryShowDuplicateIndicator,
                  subtitle: settings.localLibraryShowDuplicates
                      ? context.l10n.libraryShowDuplicateIndicatorSubtitle
                      : context.l10n.extensionsDisabled,
                  value: settings.localLibraryShowDuplicates,
                  enabled: settings.localLibraryEnabled,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setLocalLibraryShowDuplicates(value),
                ),
                SettingsItem(
                  icon: Icons.difference_outlined,
                  title: context.l10n.libraryReviewDuplicates,
                  subtitle: context.l10n.libraryReviewDuplicatesSubtitle,
                  onTap: () => DuplicateReviewSheet.show(context),
                ),
                Opacity(
                  opacity: settings.localLibraryEnabled ? 1.0 : 0.5,
                  child: SettingsItem(
                    icon: Icons.autorenew_rounded,
                    title: context.l10n.libraryAutoScan,
                    subtitle: _getAutoScanLabel(
                      context,
                      settings.localLibraryAutoScan,
                    ),
                    onTap: settings.localLibraryEnabled
                        ? () => _showAutoScanPicker(
                            context,
                            settings.localLibraryAutoScan,
                          )
                        : null,
                    showDivider: false,
                  ),
                ),
              ],
            ),
          ),

          if (settings.localLibraryEnabled) ...[
            SliverToBoxAdapter(
              child: SettingsSectionHeader(title: context.l10n.libraryActions),
            ),
            if (ref.watch(
              localLibraryProvider.select((s) => s.scanWasCancelled),
            ))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        AppIcon(
                          Icons.warning_amber_outlined,
                          color: colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.libraryScanCancelled,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onTertiaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.libraryScanCancelledSubtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onTertiaryContainer
                                          .withValues(alpha: 0.8),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        ExpressiveButton(
                          text: true,
                          onPressed: _startScan,
                          child: Text(context.l10n.dialogRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, _) {
                  final libraryState = ref.watch(localLibraryProvider);
                  final hasDownloads = ref.watch(
                    downloadHistoryProvider.select(
                      (state) => state.totalCount > 0,
                    ),
                  );
                  final canCleanup =
                      !_isCleaningMissingFiles &&
                      !libraryState.isScanning &&
                      (libraryState.totalCount > 0 ||
                          hasDownloads ||
                          librarySources.isNotEmpty);
                  return SettingsGroup(
                    connected: true,
                    children: [
                      if (libraryState.isScanning)
                        _ScanProgressTile(
                          isFinalizing: libraryState.scanIsFinalizing,
                          isPaused: libraryState.scanIsPaused,
                          progress: libraryState.scanProgress,
                          currentFile: libraryState.scanCurrentFile,
                          scannedFiles: libraryState.scannedFiles,
                          totalFiles: libraryState.scanTotalFiles,
                          onPause: _pauseScan,
                          onResume: _resumeScan,
                          onCancel: _cancelScan,
                        )
                      else ...[
                        Opacity(
                          opacity: librarySources.isNotEmpty ? 1.0 : 0.5,
                          child: SettingsItem(
                            icon: Icons.refresh,
                            title: context.l10n.libraryScan,
                            subtitle: librarySources.isEmpty
                                ? context.l10n.libraryScanSelectFolderFirst
                                : context.l10n.libraryScanSubtitle,
                            onTap: librarySources.isNotEmpty
                                ? _startScan
                                : null,
                          ),
                        ),
                        Opacity(
                          opacity: librarySources.isNotEmpty ? 1.0 : 0.5,
                          child: SettingsItem(
                            icon: Icons.sync,
                            title: context.l10n.libraryForceFullScan,
                            subtitle: context.l10n.libraryForceFullScanSubtitle,
                            onTap: librarySources.isNotEmpty
                                ? () => _startScan(forceFullScan: true)
                                : null,
                          ),
                        ),
                      ],
                      Opacity(
                        opacity: canCleanup || _isCleaningMissingFiles
                            ? 1.0
                            : 0.5,
                        child: SettingsItem(
                          icon: Icons.cleaning_services_outlined,
                          title: context.l10n.libraryCleanupMissingFiles,
                          subtitle:
                              context.l10n.libraryCleanupMissingFilesSubtitle,
                          trailing: _isCleaningMissingFiles
                              ? const AppLoadingIndicator(
                                  size: 20,
                                  strokeWidth: 2,
                                )
                              : null,
                          onTap: canCleanup ? _cleanupMissingFiles : null,
                        ),
                      ),
                      Opacity(
                        opacity: libraryState.totalCount > 0 ? 1.0 : 0.5,
                        child: SettingsItem(
                          icon: Icons.delete_outline,
                          title: context.l10n.libraryClear,
                          subtitle: context.l10n.libraryClearSubtitle,
                          onTap: libraryState.totalCount > 0
                              ? _clearLibrary
                              : null,
                          showDivider: false,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: SettingsInfoCard(
              glass: true,
              icon: Icons.info_outline,
              title: context.l10n.libraryAbout,
              message: context.l10n.libraryAboutDescription,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}