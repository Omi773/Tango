import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tango/utils/logger.dart';

final _log = AppLogger('DAC');

class AudioLive {
  const AudioLive({required this.rows, this.sessionRate});

  final List<MapEntry<String, String>> rows;
  final double? sessionRate;
}

/// Sends iOS audio session and DAC events into Tango's log and reads the
/// live session details for the Audio info sheet.
class AudioDiagnostics {
  AudioDiagnostics._();

  static const _channel = MethodChannel('app.tango/audio_diag');
  static bool _started = false;

  /// Increments whenever the output route changes (headphones or a DAC
  /// connecting or disconnecting, a Bluetooth switch, and so on).
  static final ValueNotifier<int> routeChanges = ValueNotifier<int>(0);

  static Future<void> start() async {
    if (_started || !Platform.isIOS) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'event') _handle(call.arguments);
      if (call.method == 'routeChanged') routeChanges.value++;
      return null;
    });
    // Wait for the first frame so the log setting is loaded before the
    // events that happened during startup are written.
    await WidgetsBinding.instance.endOfFrame;
    try {
      final pending = await _channel.invokeListMethod<Object?>('drain');
      for (final item in pending ?? const <Object?>[]) {
        _handle(item);
      }
    } catch (error) {
      _log.w('Could not read audio events: $error');
    }
  }

  static void _handle(Object? raw) {
    if (raw is! Map) return;
    final message = '${raw['message'] ?? ''}';
    if (message.isEmpty) return;
    switch (raw['level']) {
      case 'WARN':
        _log.w(message);
      case 'ERROR':
        _log.e(message);
      default:
        _log.i(message);
    }
  }

  static Future<AudioLive?> readLive() async {
    if (!Platform.isIOS) return null;
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('live');
      if (map == null) return null;
      final rows = <MapEntry<String, String>>[];
      final raw = map['rows'];
      if (raw is List) {
        for (final row in raw) {
          if (row is Map) {
            rows.add(MapEntry('${row['key']}', '${row['value']}'));
          }
        }
      }
      return AudioLive(
        rows: rows,
        sessionRate: (map['sessionRate'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}