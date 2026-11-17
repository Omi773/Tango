import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tango/services/music_player_runtime.dart';
import 'package:tango/utils/logger.dart';

final _log = AppLogger('ResumePlayback');

/// Lets the native "Resume Tango" App Intent start playback after iOS has
/// dropped the app from Now Playing and killed its process. The intent
/// relaunches the app in the background; this restores the saved queue and
/// position, then plays. No UI is needed.
class IosResumePlayback {
  IosResumePlayback._();

  static const _channel = MethodChannel('app.tango/resume_playback');
  static bool _installed = false;

  static void install() {
    if (!Platform.isIOS || _installed) return;
    _installed = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'resume') throw MissingPluginException();
      return _resume();
    });
  }

  static Future<bool> _resume() async {
    try {
      var handler = await musicPlayerRuntime.initialize();
      if (handler.mediaItem.value == null) {
        await musicPlayerRuntime.restoreSession();
        handler = await musicPlayerRuntime.initialize();
      }
      if (handler.mediaItem.value == null) {
        _log.w('Nothing to resume: no saved queue');
        return false;
      }
      await handler.play();
      return true;
    } catch (error) {
      _log.w('Resume from system control failed: $error');
      return false;
    }
  }
}
