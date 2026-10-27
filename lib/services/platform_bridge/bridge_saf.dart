part of '../platform_bridge.dart';

/// Folder picked via the native iOS document picker: the filesystem path plus
/// the security-scoped bookmark that re-grants access across app launches.
class IosPickedDirectory {
  final String path;
  final String bookmark;

  const IosPickedDirectory({required this.path, required this.bookmark});
}

/// Outcome of importing songs through the iOS file picker.
class IosImportResult {
  final int imported;
  final int skipped;
  final int failed;

  const IosImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
  });
}

class IosSecurityScopedAccess {
  final String path;
  final String token;

  const IosSecurityScopedAccess({required this.path, required this.token});
}

class ContentUriPlaybackLease {
  final String path;
  final String token;

  final String? displayName;

  const ContentUriPlaybackLease({
    required this.path,
    required this.token,
    this.displayName,
  });
}