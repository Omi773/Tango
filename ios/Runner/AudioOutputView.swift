import AVKit
import ExternalAccessory
import Flutter
import MediaPlayer
import UIKit

/// iOS owns the lock-screen layout, transport glyphs and AirPlay button.
/// Supply its favorite command with the same state/action as the Tango player.
final class PlaybackNotificationBridge {
    private let channel: FlutterMethodChannel
    private var target: Any?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "app.tango/playback_notification", binaryMessenger: messenger)
        let command = MPRemoteCommandCenter.shared().likeCommand
        target = command.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.channel.invokeMethod("favorite", arguments: nil)
            return .success
        }
        command.isEnabled = false
        channel.setMethodCallHandler { call, result in
            guard call.method == "update", let values = call.arguments as? [String: Any] else {
                result(FlutterMethodNotImplemented)
                return
            }
            command.isEnabled = values["enabled"] as? Bool ?? false
            command.isActive = values["loved"] as? Bool ?? false
            command.localizedTitle = values["label"] as? String ?? "Favorite"
            result(nil)
        }
    }

    deinit {
        if let target { MPRemoteCommandCenter.shared().likeCommand.removeTarget(target) }
        channel.setMethodCallHandler(nil)
    }
}

/// Read-only route and stream facts for the player's audio information sheet.
final class AudioRouteInfoBridge {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "app.tango/audio_route", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard call.method == "read" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let path = (call.arguments as? [String: Any])?["path"] as? String
            Task {
                var info = Self.route()
                if let path { info["stream"] = await Self.stream(path) }
                let payload = info
                await MainActor.run { result(payload) }
            }
        }
    }

    private static func route() -> [String: Any] {
        let session = AVAudioSession.sharedInstance()
        var info: [String: Any] = [
            "platform": "ios",
            "mixerSampleRate": Int(session.sampleRate.rounded()),
            "ioBufferMs": session.ioBufferDuration * 1000,
            "outputLatencyMs": session.outputLatency * 1000,
            "outputChannels": session.outputNumberOfChannels,
            "maxOutputChannels": session.maximumOutputNumberOfChannels,
            "volume": Double(session.outputVolume),
        ]
        if let output = session.currentRoute.outputs.first {
            info["device"] = [
                "type": portType(output.portType),
                "name": output.portName,
                "channelCounts": [output.channels?.count ?? 0].filter { $0 > 0 },
                "spatial": output.isSpatialAudioEnabled,
            ] as [String: Any]
        }
        return info
    }

    private static func portType(_ type: AVAudioSession.Port) -> String {
        switch type {
        case .builtInSpeaker: return "speaker"
        case .builtInReceiver: return "earpiece"
        case .headphones: return "wired_headphones"
        case .bluetoothA2DP, .bluetoothHFP: return "bluetooth"
        case .bluetoothLE: return "bluetooth_le"
        case .airPlay: return "airplay"
        case .usbAudio: return "usb"
        case .HDMI: return "hdmi"
        case .lineOut: return "line"
        case .carAudio: return "car"
        default: return "other"
        }
    }

    private static func stream(_ path: String) async -> [String: Any]? {
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : URL(string: path)
        guard let url, url.isFileURL else { return nil }
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let formats = try? await track.load(.formatDescriptions),
              let description = formats.first,
              let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee
        else { return nil }
        let rate = (try? await track.load(.estimatedDataRate)) ?? 0
        let id = basic.mFormatID
        let fourCC = String(
            bytes: [24, 16, 8, 0].map { UInt8((id >> $0) & 0xff) },
            encoding: .ascii
        )?.trimmingCharacters(in: .whitespaces) ?? ""
        return [
            "mime": fourCC,
            "sampleRate": Int(basic.mSampleRate.rounded()),
            "channels": Int(basic.mChannelsPerFrame),
            "pcmBits": Int(basic.mBitsPerChannel),
            "bitrate": Int(rate.rounded()),
        ].filter { ($0.value as? Int).map { $0 > 0 } ?? !(($0.value as? String)?.isEmpty ?? true) }
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }
}

final class AudioOutputViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        AudioOutputView(frame: frame, id: viewId, messenger: messenger, arguments: args)
    }
}

private final class AudioOutputView: NSObject, FlutterPlatformView, AVRoutePickerViewDelegate {
    private let picker: AVRoutePickerView
    private let channel: FlutterMethodChannel

    init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, arguments: Any?) {
        picker = AVRoutePickerView(frame: frame)
        channel = FlutterMethodChannel(name: "app.tango/audio_output/\(id)", binaryMessenger: messenger)
        super.init()
        picker.backgroundColor = .clear
        picker.prioritizesVideoDevices = false
        picker.delegate = self
        update(arguments)
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "update" {
                self?.update(call.arguments)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func update(_ arguments: Any?) {
        guard let values = arguments as? [String: Any] else { return }
        if let value = values["color"] as? NSNumber {
            let argb = value.uint32Value
            picker.tintColor = UIColor(
                red: CGFloat((argb >> 16) & 0xff) / 255,
                green: CGFloat((argb >> 8) & 0xff) / 255,
                blue: CGFloat(argb & 0xff) / 255,
                alpha: CGFloat((argb >> 24) & 0xff) / 255
            )
            picker.activeTintColor = picker.tintColor
        }
        picker.accessibilityLabel = values["label"] as? String
    }

    func view() -> UIView { picker }

    func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        channel.invokeMethod("pickerChanged", arguments: true)
    }

    func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        channel.invokeMethod("pickerChanged", arguments: false)
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }
}
/// Watches the iOS audio session and reports changes to Tango's log.
final class AudioDiagnosticsBridge {
    private let channel: FlutterMethodChannel
    private let session = AVAudioSession.sharedInstance()
    private var timer: Timer?
    private var buffered: [[String: String]] = []
    private var dartListening = false
    private var lastRate = 0.0
    private var lastBuffer = 0.0
    private var lastChannels = 0
    private var lastCategory = ""
    private var usbConnected = false
    private var connects = 0
    private var disconnects = 0

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "app.tango/audio_diag", binaryMessenger: messenger)
        lastRate = session.sampleRate
        lastBuffer = session.ioBufferDuration
        lastChannels = session.outputNumberOfChannels
        lastCategory = categoryText()
        usbConnected = session.currentRoute.outputs.contains { $0.portType == .usbAudio }
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            switch call.method {
            case "drain":
                self.dartListening = true
                let pending = self.buffered
                self.buffered = []
                result(pending)
            case "live":
                result(self.liveSnapshot())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        observe()
        emit("INFO", "Audio monitor started · " + summary())
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    deinit {
        timer?.invalidate()
        channel.setMethodCallHandler(nil)
    }

    private func emit(_ level: String, _ message: String) {
        let item = ["level": level, "message": message]
        if dartListening {
            channel.invokeMethod("event", arguments: item)
        } else {
            buffered.append(item)
            if buffered.count > 200 { buffered.removeFirst() }
        }
    }

    private func observe() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] n in
            self?.routeChanged(n)
        }
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let raw = (n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? 0
            let began = AVAudioSession.InterruptionType(rawValue: raw) == .began
            var text = began ? "Interruption began" : "Interruption ended"
            if !began, let o = n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: o).contains(.shouldResume) {
                text += " (should resume)"
            }
            self?.emit(began ? "WARN" : "INFO", text)
        }
        nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            self?.emit("WARN", "Media services were reset")
            self?.poll()
        }
        nc.addObserver(forName: AVAudioSession.mediaServicesWereLostNotification, object: nil, queue: .main) { [weak self] _ in
            self?.emit("WARN", "Media services were lost")
        }
        nc.addObserver(forName: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil, queue: .main) { [weak self] n in
            let t = (n.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt) ?? 0
            self?.emit("INFO", "Silence-secondary-audio hint: \(t == 1 ? "begin" : "end")")
        }
        nc.addObserver(forName: .EAAccessoryDidConnect, object: nil, queue: .main) { [weak self] n in
            let a = n.userInfo?[EAAccessoryKey] as? EAAccessory
            self?.emit("INFO", "MFi accessory connected: \(a?.name ?? "?")")
        }
        nc.addObserver(forName: .EAAccessoryDidDisconnect, object: nil, queue: .main) { [weak self] n in
            let a = n.userInfo?[EAAccessoryKey] as? EAAccessory
            self?.emit("WARN", "MFi accessory disconnected: \(a?.name ?? "?")")
        }
        EAAccessoryManager.shared().registerForLocalNotifications()
    }

    private func routeChanged(_ n: Notification) {
        let raw = (n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
        let reason = AVAudioSession.RouteChangeReason(rawValue: raw).map { self.reasonName($0) } ?? "unknown(\(raw))"
        let previous = (n.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)
            .map { self.routeText($0) } ?? "-"
        emit("INFO", "Route change: \(reason) · was \(previous) · now \(routeText(session.currentRoute))")
        poll()
    }

    /// Runs twice a second and reports only what changed.
    private func poll() {
        let s = session
        let outs = s.currentRoute.outputs
        let usb = outs.contains { $0.portType == .usbAudio }
        if usb != usbConnected {
            usbConnected = usb
            if usb {
                connects += 1
                emit("INFO", "DAC connected: \(outs.first?.portName ?? "?") · " + summary())
            } else {
                disconnects += 1
                emit("WARN", "DAC disconnected")
            }
        }
        let rate = s.sampleRate
        if abs(rate - lastRate) > 0.5 {
            emit("INFO", String(format: "Session sample rate %.0f → %.0f Hz (preferred %.0f Hz)", lastRate, rate, s.preferredSampleRate))
            lastRate = rate
        }
        let buf = s.ioBufferDuration
        if abs(buf - lastBuffer) > 0.0005 {
            emit("INFO", String(format: "IO buffer %.2f → %.2f ms", lastBuffer * 1000, buf * 1000))
            lastBuffer = buf
        }
        let ch = s.outputNumberOfChannels
        if ch != lastChannels {
            emit("INFO", "Output channels \(lastChannels) → \(ch)")
            lastChannels = ch
        }
        let cat = categoryText()
        if cat != lastCategory {
            emit("INFO", "Audio session changed: \(lastCategory) → \(cat)")
            lastCategory = cat
        }
    }

    private func summary() -> String {
        let s = session
        return String(format: "%.0f Hz · IO %.1f ms · %d out ch · ", s.sampleRate, s.ioBufferDuration * 1000, s.outputNumberOfChannels)
            + routeText(s.currentRoute) + " · " + categoryText()
    }

    private func categoryText() -> String {
        let s = session
        return "\(s.category.rawValue) / \(s.mode.rawValue) / \(optionsText(s.categoryOptions))"
    }

    private func liveSnapshot() -> [String: Any] {
        let s = session
        let out = s.currentRoute.outputs.first
        var rows: [[String: String]] = []
        func add(_ key: String, _ value: String) { rows.append(["key": key, "value": value]) }
        add("Output device", out.map { "\($0.portName) [\($0.portType.rawValue)]" } ?? "none")
        add("Session sample rate", String(format: "%.0f Hz (preferred %.0f Hz)", s.sampleRate, s.preferredSampleRate))
        add("IO buffer", String(format: "%.2f ms (preferred %.2f ms)", s.ioBufferDuration * 1000, s.preferredIOBufferDuration * 1000))
        add("Output latency", String(format: "%.2f ms", s.outputLatency * 1000))
        add("Output channels", "\(s.outputNumberOfChannels) now · \(s.maximumOutputNumberOfChannels) max · \(s.preferredOutputNumberOfChannels) preferred")
        if let out = out {
            let chans = (out.channels ?? []).map { "\($0.channelNumber): \($0.channelName)" }
            if !chans.isEmpty { add("Channel map", chans.joined(separator: ", ")) }
            let sources = (out.dataSources ?? []).map { $0.dataSourceName }
            if !sources.isEmpty { add("Data sources", sources.joined(separator: ", ")) }
            if let selected = out.selectedDataSource { add("Selected data source", selected.dataSourceName) }
            add("Spatial audio", out.isSpatialAudioEnabled ? "on" : "off")
        }
        add("All outputs", routeText(s.currentRoute))
        add("Session category / mode", "\(s.category.rawValue) / \(s.mode.rawValue)")
        add("Category options", optionsText(s.categoryOptions))
        add("Route sharing policy", policyName(s.routeSharingPolicy))
        add("Other audio playing", s.isOtherAudioPlaying ? "yes" : "no")
        add("DAC (USB audio)", usbConnected ? "connected" : "not connected")
        add("DAC connects / disconnects", "\(connects) / \(disconnects)")
        return ["rows": rows, "sessionRate": s.sampleRate]
    }

    private func routeText(_ r: AVAudioSessionRouteDescription) -> String {
        r.outputs.isEmpty ? "none" : r.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
    }

    private func optionsText(_ o: AVAudioSession.CategoryOptions) -> String {
        var names: [String] = []
        if o.contains(.mixWithOthers) { names.append("mixWithOthers") }
        if o.contains(.duckOthers) { names.append("duckOthers") }
        if o.contains(.interruptSpokenAudioAndMixWithOthers) { names.append("interruptSpoken") }
        if o.contains(.allowBluetooth) { names.append("allowBluetooth") }
        if o.contains(.allowBluetoothA2DP) { names.append("allowBluetoothA2DP") }
        if o.contains(.allowAirPlay) { names.append("allowAirPlay") }
        if o.contains(.defaultToSpeaker) { names.append("defaultToSpeaker") }
        return names.isEmpty ? "none" : names.joined(separator: "+")
    }

    private func reasonName(_ r: AVAudioSession.RouteChangeReason) -> String {
        switch r {
        case .unknown: return "unknown"
        case .newDeviceAvailable: return "new device available"
        case .oldDeviceUnavailable: return "old device unavailable"
        case .categoryChange: return "category change"
        case .override: return "override"
        case .wakeFromSleep: return "wake from sleep"
        case .noSuitableRouteForCategory: return "no suitable route"
        case .routeConfigurationChange: return "route configuration change"
        @unknown default: return "other"
        }
    }

    private func policyName(_ p: AVAudioSession.RouteSharingPolicy) -> String {
        switch p {
        case .default: return "default"
        case .longFormAudio: return "long-form audio"
        case .longFormVideo: return "long-form video"
        case .independent: return "independent"
        @unknown default: return "other"
        }
    }
}