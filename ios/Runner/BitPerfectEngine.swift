import AVFoundation
import Flutter
import os

// Native "bit-perfect" local playback for iOS.
//
// iOS apps cannot claim a USB audio device, so a DAC is always driven by the
// system (CoreAudio). What an app *can* control is everything before that:
//   - decode FLAC / ALAC / WAV / AIFF losslessly (AVAudioFile -> Float32; every
//     integer sample up to 24 bits is exactly representable in Float32),
//   - ask the session for the file's own sample rate so the system does not
//     resample (setPreferredSampleRate),
//   - keep the whole path at unity gain: no EQ tap, no AVPlayer volume, no
//     mixer gain, no rate change, no ReplayGain/AutoMix (Dart bypasses those).
//
// This speaks the same channel protocol as Android's direct-USB engine
// (`app.tango/usb_pcm`), so the Dart deck needs no new transport.

// MARK: - Ring buffer

/// Planar Float32 ring shared by one decode thread (producer) and the audio
/// render thread (consumer). The lock only guards indices and counters; the
/// sample copies happen outside it, in regions each side owns exclusively.
final class PlanarRing {
    let channels: Int
    let capacity: Int
    private var planes: [UnsafeMutablePointer<Float>] = []
    private let lock: UnsafeMutablePointer<os_unfair_lock>
    private var readIndex = 0
    private var writeIndex = 0
    private var count = 0
    private var epoch = 0
    private var played: Int64 = 0
    private var ended = false

    init(channels: Int, capacity: Int) {
        self.channels = channels
        self.capacity = capacity
        lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        for _ in 0..<channels {
            let plane = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
            plane.initialize(repeating: 0, count: capacity)
            planes.append(plane)
        }
    }

    deinit {
        for plane in planes { plane.deallocate() }
        lock.deallocate()
    }

    /// Frames of real audio rendered since the last `reset()`.
    var playedFrames: Int64 {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return played
    }

    var filledFrames: Int {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return count
    }

    /// True once the decoder hit end of file and every frame has been rendered.
    var isFinished: Bool {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return ended && count == 0
    }

    func markEnd() {
        os_unfair_lock_lock(lock)
        ended = true
        os_unfair_lock_unlock(lock)
    }

    /// Drops buffered audio. The decode thread must be stopped first; a render
    /// call that is mid-copy discards its bookkeeping via the epoch check.
    func reset() {
        os_unfair_lock_lock(lock)
        epoch += 1
        readIndex = 0
        writeIndex = 0
        count = 0
        played = 0
        ended = false
        os_unfair_lock_unlock(lock)
    }

    /// Producer side. Returns how many frames were accepted.
    func write(_ source: UnsafePointer<UnsafeMutablePointer<Float>>, offset: Int, frames: Int) -> Int {
        os_unfair_lock_lock(lock)
        let n = min(frames, capacity - count)
        let start = writeIndex
        let writeEpoch = epoch
        os_unfair_lock_unlock(lock)
        if n <= 0 { return 0 }
        let size = MemoryLayout<Float>.size
        let first = min(n, capacity - start)
        for channel in 0..<channels {
            memcpy(planes[channel] + start, source[channel] + offset, first * size)
            if n > first {
                memcpy(planes[channel], source[channel] + offset + first, (n - first) * size)
            }
        }
        os_unfair_lock_lock(lock)
        if epoch == writeEpoch {
            writeIndex = (start + n) % capacity
            count += n
        }
        os_unfair_lock_unlock(lock)
        return n
    }

    /// Consumer side (render thread). Fills `list` and zero-pads any shortfall.
    /// Padding is silence and is not counted as played.
    func read(into list: UnsafeMutableAudioBufferListPointer, frames: Int) -> Int {
        os_unfair_lock_lock(lock)
        let n = min(frames, count)
        let start = readIndex
        let readEpoch = epoch
        os_unfair_lock_unlock(lock)
        let size = MemoryLayout<Float>.size
        let first = min(n, capacity - start)
        for channel in 0..<list.count {
            guard let destination = list[channel].mData?.assumingMemoryBound(to: Float.self) else { continue }
            let plane = planes[min(channel, channels - 1)]
            if n > 0 {
                memcpy(destination, plane + start, first * size)
                if n > first { memcpy(destination + first, plane, (n - first) * size) }
            }
            if n < frames { memset(destination + n, 0, (frames - n) * size) }
        }
        if n > 0 {
            os_unfair_lock_lock(lock)
            if epoch == readEpoch {
                readIndex = (start + n) % capacity
                count -= n
                played += Int64(n)
            }
            os_unfair_lock_unlock(lock)
        }
        return n
    }
}

private final class CancelFlag {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
}

// MARK: - Engine

enum BitPerfectError: Error {
    case notPrepared
}

/// One loaded track: decode thread -> ring -> AVAudioSourceNode -> hardware.
final class BitPerfectEngine {
    struct Prepared {
        let durationMs: Int
        let fileRate: Double
        let outputRate: Double
        let bits: Int?
        let device: String
        let channels: Int
    }

    enum Rejection: Error {
        case format(String)
        case noRoute
    }

    private static let wiredPorts: Set<AVAudioSession.Port> = [.usbAudio, .headphones, .lineOut, .HDMI]

    private var file: AVAudioFile?
    private var ring: PlanarRing?
    private var engine: AVAudioEngine?
    private var decodeFlag: CancelFlag?
    private var decodeDone: DispatchSemaphore?
    private var baseFrames: Int64 = 0
    private var fileRate: Double = 44100
    private(set) var isPlaying = false

    var isLoaded: Bool { engine != nil }

    // MARK: Prepare

    func prepare(path: String) throws -> Prepared {
        teardown()

        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let wired = outputs.contains { port in
            Self.wiredPorts.contains(port.portType) || Self.looksLikeDac(port.portName)
        }
        guard wired else { throw Rejection.noRoute }

        let url = Self.fileURL(path)
        let opened: AVAudioFile
        do {
            opened = try AVAudioFile(forReading: url)
        } catch {
            throw Rejection.format("cannot open: \(error.localizedDescription)")
        }
        let description = opened.fileFormat.streamDescription.pointee
        let id = description.mFormatID
        guard id == kAudioFormatFLAC || id == kAudioFormatAppleLossless || id == kAudioFormatLinearPCM else {
            throw Rejection.format("lossy or unsupported codec")
        }
        let format = opened.processingFormat
        let channels = Int(format.channelCount)
        guard channels == 1 || channels == 2 else {
            throw Rejection.format("\(channels) channels")
        }
        guard opened.length > 0, format.sampleRate > 0 else {
            throw Rejection.format("empty file")
        }

        try configureSession(rate: format.sampleRate)

        let capacity = max(Int(format.sampleRate * 1.5), 16384)
        let ring = PlanarRing(channels: channels, capacity: capacity)

        let engine = AVAudioEngine()
        let node = AVAudioSourceNode(format: format) { isSilence, _, frameCount, audioBufferList in
            let list = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let n = ring.read(into: list, frames: Int(frameCount))
            if n == 0 { isSilence.pointee = true }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()

        self.file = opened
        self.ring = ring
        self.engine = engine
        self.fileRate = format.sampleRate
        self.baseFrames = 0
        startDecoding()

        // Let the decoder get a little ahead so playback starts without a gap.
        let deadline = Date().addingTimeInterval(0.15)
        while ring.filledFrames < Int(format.sampleRate * 0.2) && !ring.isFinished
            && Date() < deadline
        {
            usleep(5_000)
        }

        let outputRate = session.sampleRate
        return Prepared(
            durationMs: Int((Double(opened.length) / format.sampleRate * 1000).rounded()),
            fileRate: format.sampleRate,
            outputRate: outputRate,
            bits: Self.sourceBits(opened),
            device: outputs.first?.portName ?? "",
            channels: channels
        )
    }

    private func configureSession(rate: Double) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setPreferredSampleRate(rate)
        try session.setActive(true)
        if abs(session.sampleRate - rate) > 0.5 {
            // The first activation can keep the previous track's rate. Cycle
            // the session once so the hardware renegotiates.
            try? session.setActive(false, options: [])
            try session.setPreferredSampleRate(rate)
            try session.setActive(true)
        }
    }

    // MARK: Transport

    func resume() throws {
        guard let engine, ring != nil else { throw BitPerfectError.notPrepared }
        try AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning { try engine.start() }
        isPlaying = true
    }

    func pause() {
        engine?.pause()
        isPlaying = false
    }

    func seek(milliseconds: Int) {
        guard let file, let ring else { return }
        stopDecoding()
        let frames = AVAudioFramePosition(Double(milliseconds) / 1000 * fileRate)
        let target = min(max(frames, 0), file.length)
        file.framePosition = target
        ring.reset()
        baseFrames = target
        startDecoding()
    }

    func positionMs() -> Int {
        guard let ring, fileRate > 0 else { return 0 }
        let frames = baseFrames + ring.playedFrames
        return Int((Double(frames) / fileRate * 1000).rounded())
    }

    var isFinished: Bool { ring?.isFinished ?? false }

    func stop() {
        teardown()
    }

    private func teardown() {
        stopDecoding()
        engine?.stop()
        engine = nil
        ring = nil
        file = nil
        isPlaying = false
        baseFrames = 0
    }

    // MARK: Decoding

    private func startDecoding() {
        guard let file, let ring else { return }
        let flag = CancelFlag()
        let done = DispatchSemaphore(value: 0)
        decodeFlag = flag
        decodeDone = done
        let chunk: AVAudioFrameCount = 8192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else {
            ring.markEnd()
            done.signal()
            return
        }
        Thread.detachNewThread {
            defer { done.signal() }
            while !flag.isSet {
                if file.framePosition >= file.length {
                    ring.markEnd()
                    return
                }
                buffer.frameLength = 0
                do {
                    try file.read(into: buffer, frameCount: chunk)
                } catch {
                    ring.markEnd()
                    return
                }
                let frames = Int(buffer.frameLength)
                if frames == 0 {
                    ring.markEnd()
                    return
                }
                guard let data = buffer.floatChannelData else {
                    ring.markEnd()
                    return
                }
                var offset = 0
                while offset < frames && !flag.isSet {
                    let wrote = ring.write(data, offset: offset, frames: frames - offset)
                    offset += wrote
                    if wrote == 0 { usleep(5_000) }
                }
            }
        }
    }

    private func stopDecoding() {
        decodeFlag?.set()
        decodeDone?.wait()
        decodeFlag = nil
        decodeDone = nil
    }

    // MARK: Helpers

    static func looksLikeDac(_ name: String) -> Bool {
        let upper = name.uppercased()
        return ["CX31993", "JM7", "JCALLY"].contains { upper.contains($0) }
    }

    private static func fileURL(_ path: String) -> URL {
        if path.hasPrefix("file://"), let url = URL(string: path) { return url }
        return URL(fileURLWithPath: path)
    }

    private static func sourceBits(_ file: AVAudioFile) -> Int? {
        let description = file.fileFormat.streamDescription.pointee
        if description.mFormatID == kAudioFormatAppleLossless {
            switch description.mFormatFlags {
            case 1: return 16
            case 2: return 20
            case 3: return 24
            case 4: return 32
            default: break
            }
        }
        if let bits = file.fileFormat.settings[AVLinearPCMBitDepthKey] as? Int, bits > 0 {
            return bits
        }
        if description.mBitsPerChannel > 0 { return Int(description.mBitsPerChannel) }
        return nil
    }
}

// MARK: - Flutter bridge

private final class BitPerfectEvents: NSObject, FlutterStreamHandler {
    var sink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}

/// Serves `app.tango/usb_pcm` on iOS with [BitPerfectEngine].
final class BitPerfectBridge {
    private let channel: FlutterMethodChannel
    private let events: FlutterEventChannel
    private let handler = BitPerfectEvents()
    private let engine = BitPerfectEngine()
    private var token = 0
    private var monitor: DispatchSourceTimer?
    private var observers: [NSObjectProtocol] = []

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "app.tango/usb_pcm", binaryMessenger: messenger)
        events = FlutterEventChannel(name: "app.tango/usb_pcm/events", binaryMessenger: messenger)
        events.setStreamHandler(handler)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterMethodNotImplemented)
                return
            }
            self.handle(call, result)
        }
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
            ) { [weak self] note in self?.routeChanged(note) })
        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
            ) { [weak self] note in self?.interrupted(note) })
    }

    deinit {
        monitor?.cancel()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        channel.setMethodCallHandler(nil)
        events.setStreamHandler(nil)
    }

    private func emit(_ name: String) {
        handler.sink?(["event": name, "token": token])
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {
        case "prepare":
            result(prepare(call.arguments as? [String: Any] ?? [:]))
        case "resume":
            do {
                try engine.resume()
                startMonitor()
                result(nil)
            } catch {
                result(FlutterError(code: "engine_failed", message: "\(error)", details: nil))
            }
        case "pause":
            engine.pause()
            stopMonitor()
            result(nil)
        case "seek":
            let args = call.arguments as? [String: Any]
            engine.seek(milliseconds: (args?["position"] as? NSNumber)?.intValue ?? 0)
            result(nil)
        case "position":
            result(engine.isLoaded ? engine.positionMs() : nil)
        case "stop":
            token += 1
            stopMonitor()
            engine.stop()
            result(nil)
        default:
            // "volume": iOS has no app-controlled DAC volume; the system owns it.
            result(FlutterMethodNotImplemented)
        }
    }

    private func prepare(_ args: [String: Any]) -> [String: Any] {
        token = (args["token"] as? NSNumber)?.intValue ?? token
        if args["requiresDsd"] as? Bool == true {
            return ["ready": false, "reason": "dsd_unsupported"]
        }
        guard let path = args["path"] as? String else {
            return ["ready": false, "reason": "unsupported"]
        }
        do {
            let info = try engine.prepare(path: path)
            let resampled = abs(info.outputRate - info.fileRate) > 0.5
            var response: [String: Any] = [
                "ready": true,
                "duration": info.durationMs,
                "device": info.device,
                // The rate the hardware actually runs at, not the file's.
                "sampleRate": Int(info.outputRate.rounded()),
                "fileSampleRate": Int(info.fileRate.rounded()),
                "resampled": resampled,
                "transport": "pcm",
                "driver": "ios_coreaudio",
                "volumeBlocked": false,
            ]
            if let bits = info.bits { response["bitDepth"] = bits }
            return response
        } catch BitPerfectEngine.Rejection.noRoute {
            return ["ready": false, "reason": "no_usb"]
        } catch BitPerfectEngine.Rejection.format(let detail) {
            return ["ready": false, "reason": "format", "detail": detail]
        } catch {
            return ["ready": false, "reason": "unsupported", "detail": "\(error)"]
        }
    }

    // Completion is polled so the render thread never touches Flutter.
    private func startMonitor() {
        stopMonitor()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in
            guard let self, self.engine.isPlaying, self.engine.isFinished else { return }
            self.stopMonitor()
            // Let the hardware buffer drain before announcing the end.
            let tail = AVAudioSession.sharedInstance().outputLatency + 0.05
            let finishedToken = self.token
            DispatchQueue.main.asyncAfter(deadline: .now() + tail) { [weak self] in
                guard let self, self.token == finishedToken, self.engine.isFinished else { return }
                self.engine.pause()
                self.emit("complete")
            }
        }
        monitor = timer
        timer.resume()
    }

    private func stopMonitor() {
        monitor?.cancel()
        monitor = nil
    }

    private func routeChanged(_ note: Notification) {
        guard engine.isLoaded,
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
        else { return }
        // The DAC went away. Never move bit-perfect playback to another output.
        engine.pause()
        stopMonitor()
        emit("paused")
    }

    private func interrupted(_ note: Notification) {
        guard engine.isLoaded,
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            AVAudioSession.InterruptionType(rawValue: raw) == .began,
            engine.isPlaying
        else { return }
        engine.pause()
        stopMonitor()
        emit("interrupted")
    }
}
