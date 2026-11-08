// Device types are experimental in audio_session. Keep their interpretation
// here so platform route changes do not leak into transport or settings code.
// ignore_for_file: experimental_member_use

import 'package:audio_session/audio_session.dart';

/// Serializes automatic transport requests triggered by output route changes.
/// A route change must never undo an explicit pause.
class PlaybackAutomation {
  PlaybackAutomation({
    required bool Function() isPlaying,
    required bool Function() canResume,
    required Future<void> Function() pause,
    required Future<void> Function() play,
    required void Function(Object) onError,
  }) : _isPlaying = isPlaying,
       _canResume = canResume,
       _pause = pause,
       _play = play,
       _onError = onError;

  final bool Function() _isPlaying;
  final bool Function() _canResume;
  final Future<void> Function() _pause;
  final Future<void> Function() _play;
  final void Function(Object) _onError;
  bool _playOnHeadphonesConnected = false;
  bool _disposed = false;
  int _intentRevision = 0;
  Set<String>? _headphones;
  Future<void> _tail = Future<void>.value();

  Future<void> configure({required bool playOnHeadphonesConnected}) {
    if (_playOnHeadphonesConnected == playOnHeadphonesConnected) {
      return _tail;
    }
    cancelPendingActions();
    _headphones = null;
    _playOnHeadphonesConnected = playOnHeadphonesConnected;
    return _tail;
  }

  void cancelPendingActions() {
    _intentRevision++;
  }

  Future<void> devicesChanged(Set<AudioDevice> devices) {
    final headphones = devices
        .where(_isHeadphoneOutput)
        .map((device) => device.id)
        .toSet();
    final previous = _headphones;
    _headphones = headphones;
    // The initial device inventory is not a connection gesture.
    if (previous == null || !_playOnHeadphonesConnected) return _tail;
    if (previous.isNotEmpty && headphones.isEmpty) {
      cancelPendingActions();
      return _enqueue(() async {
        if (_isPlaying()) await _pause();
      });
    }
    if (headphones.difference(previous).isEmpty) return _tail;
    return _enqueue(() async {
      if (_playOnHeadphonesConnected &&
          !_isPlaying() &&
          _canResume()) {
        await _play();
      }
    });
  }

  static bool _isHeadphoneOutput(AudioDevice device) =>
      device.isOutput &&
      const {
        AudioDeviceType.wiredHeadset,
        AudioDeviceType.wiredHeadphones,
        AudioDeviceType.usbAudio,
        AudioDeviceType.bluetoothA2dp,
        AudioDeviceType.bluetoothLe,
        AudioDeviceType.hearingAid,
      }.contains(device.type);

  Future<void> _enqueue(Future<void> Function() action) {
    final revision = _intentRevision;
    _tail = _tail.then((_) async {
      if (_disposed || revision != _intentRevision) return;
      try {
        await action();
      } catch (error) {
        _onError(error);
      }
    });
    return _tail;
  }

  Future<void> dispose() async {
    _disposed = true;
    cancelPendingActions();
    await _tail;
  }
}
