import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tango/l10n/l10n.dart';
import 'package:tango/services/audio_route_info.dart';
import 'package:tango/widgets/app_icon_button.dart';

/// Uses the system's real audio routes and keeps native discovery in native UI.
class AudioOutputButton extends StatefulWidget {
  const AudioOutputButton({
    super.key,
    this.color,
    this.onPickerChanged,
    this.showRoute = false,
  });

  final Color? color;

  /// Draws a pill with the connected output's icon and name (speaker,
  /// headphones, AirPods, AirPlay, ...) instead of the bare system glyph.
  final bool showRoute;
  final ValueChanged<bool>? onPickerChanged;

  @override
  State<AudioOutputButton> createState() => _AudioOutputButtonState();
}

class _AudioOutputButtonState extends State<AudioOutputButton> {
  static const _androidChannel = MethodChannel('app.tango/audio_output');
  MethodChannel? _viewChannel;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (widget.showRoute) AudioRouteWatcher.instance.acquire();
  }

  Map<String, Object> get _appearance => {
    // The route pill draws the glyph itself; the native picker only
    // catches the tap, so its own icon is made invisible.
    'color': widget.showRoute
        ? 0
        : (widget.color ?? Theme.of(context).colorScheme.onSurface).toARGB32(),
    'label': context.l10n.nowPlayingAudioOutput,
  };

  @override
  void didUpdateWidget(AudioOutputButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAppearance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAppearance();
  }

  void _updateAppearance() {
    final channel = _viewChannel;
    if (channel != null) {
      unawaited(channel.invokeMethod<void>('update', _appearance));
    }
  }

  void _attachView(int id) {
    _viewChannel?.setMethodCallHandler(null);
    _viewChannel = MethodChannel('app.tango/audio_output/$id')
      ..setMethodCallHandler((call) async {
        if (mounted && call.method == 'pickerChanged') {
          widget.onPickerChanged?.call(call.arguments == true);
        }
      });
    _updateAppearance();
  }

  Future<void> _showAndroidPicker() async {
    if (_opening) return;
    _opening = true;
    widget.onPickerChanged?.call(true);
    var opened = false;
    try {
      opened = await _androidChannel.invokeMethod<bool>('show') ?? false;
    } on PlatformException {
      // Show a visible failure instead of leaving an unresponsive control.
    } on MissingPluginException {
      // The native bridge is not available on unsupported builds.
    } finally {
      _opening = false;
      if (mounted) widget.onPickerChanged?.call(false);
    }
    if (mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nowPlayingAudioOutputUnavailable)),
      );
    }
  }

  @override
  void dispose() {
    _viewChannel?.setMethodCallHandler(null);
    if (widget.showRoute) AudioRouteWatcher.instance.release();
    super.dispose();
  }

  Widget _routePill(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pill = ValueListenableBuilder<AudioRouteDevice?>(
      valueListenable: AudioRouteWatcher.instance.device,
      builder: (context, device, _) {
        final (icon, label) = _describeRoute(device);
        return Container(
          height: 40,
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
    return Semantics(
      button: true,
      label: context.l10n.nowPlayingAudioOutput,
      child: switch (defaultTargetPlatform) {
        // The system route picker sits invisibly over the pill and takes
        // the tap, so discovery and selection stay in native UI.
        TargetPlatform.iOS => Stack(
          alignment: Alignment.center,
          children: [
            pill,
            Positioned.fill(
              child: UiKitView(
                viewType: 'app.tango/audio_output',
                creationParams: _appearance,
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: _attachView,
              ),
            ),
          ],
        ),
        TargetPlatform.android => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showAndroidPicker,
          child: pill,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  /// Icon and display name for the active output route.
  (IconData, String) _describeRoute(AudioRouteDevice? device) {
    final name = device?.name.trim() ?? '';
    final lower = name.toLowerCase();
    switch (device?.type) {
      case 'speaker':
        return (Icons.speaker_rounded, name.isEmpty ? 'Speaker' : name);
      case 'earpiece':
        return (Icons.phone_in_talk_rounded, name.isEmpty ? 'Receiver' : name);
      case 'wired_headphones':
        return (Icons.headphones_rounded, name.isEmpty ? 'Headphones' : name);
      case 'bluetooth':
      case 'bluetooth_le':
        final label = name.isEmpty ? 'Bluetooth' : name;
        if (lower.contains('airpods max')) {
          return (Icons.headphones_rounded, label);
        }
        if (lower.contains('airpods') ||
            lower.contains('buds') ||
            lower.contains('pods')) {
          return (Icons.earbuds_rounded, label);
        }
        return (Icons.bluetooth_audio_rounded, label);
      case 'airplay':
        return (Icons.airplay_rounded, name.isEmpty ? 'AirPlay' : name);
      case 'usb':
        return (Icons.usb_rounded, name.isEmpty ? 'USB audio' : name);
      case 'hdmi':
        return (Icons.tv_rounded, name.isEmpty ? 'HDMI' : name);
      case 'car':
        return (Icons.directions_car_rounded, name.isEmpty ? 'Car' : name);
      case 'line':
        return (Icons.cable_rounded, name.isEmpty ? 'Line out' : name);
      default:
        return (Icons.speaker_group_rounded, name.isEmpty ? 'Output' : name);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (widget.showRoute) return _routePill(context);
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return SizedBox.square(
          dimension: 48,
          child: UiKitView(
            viewType: 'app.tango/audio_output',
            creationParams: _appearance,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _attachView,
          ),
        );
      case TargetPlatform.android:
        return AppIconButton(
          tooltip: context.l10n.nowPlayingAudioOutput,
          color: widget.color,
          icon: const Icon(Icons.speaker_group_outlined),
          onPressed: _showAndroidPicker,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
