import 'package:flutter/foundation.dart';
import 'package:tango/utils/desktop_platform.dart';

class AppInfo {
  static const String version = '1.0.0';
  static const String buildNumber = '1';

  static const String gitCommit = String.fromEnvironment('GIT_COMMIT');
  static String get shortGitCommit =>
      gitCommit.length > 8 ? gitCommit.substring(0, 8) : gitCommit;

  /// The version shown to people; desktop builds are still in beta.
  static String get displayVersion => versionLabel();

  @visibleForTesting
  static String versionLabel({bool debug = kDebugMode, bool? desktop}) {
    if (debug) return 'Internal';
    return desktop ?? isDesktopPlatform ? '$version (beta)' : version;
  }

  static const String appName = 'Tango';
  static const String copyright = '© 2026 Omi773 & Claude AI';

  static const String mobileAuthor = 'Omi773';

  static const String githubRepo = 'Omi773/Tango';
  static const String githubUrl = 'https://github.com/$githubRepo';

  /// Desktop packages are published here; the source stays in [githubRepo].
  static const String desktopGithubRepo = 'Omi773/Tango';
  // The server keeps the endpoint name from before the rename.
  static const String remoteConfigApiUrl =
      'https://invalid.invalid/config';

  static const String kofiUrl = 'https://ko-fi.com/zarzet';
  static const String githubSponsorsUrl = 'https://github.com/sponsors/zarzet/';
}
