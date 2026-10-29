import AuthenticationServices
import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
    // Widget playback intents can launch the process before any scene exists.
    // Keep one headless-capable engine and attach that same player to the UI.
    lazy var playerEngine = FlutterEngine(name: "tango-player", project: nil, allowHeadlessExecution: true)
    private let CHANNEL = "app.tango/backend"
    private let DOWNLOAD_PROGRESS_STREAM_CHANNEL = "app.tango/download_progress_stream"
    private let LIBRARY_SCAN_PROGRESS_STREAM_CHANNEL = "app.tango/library_scan_progress_stream"
    private let LARGE_JSON_RESULT_FILE_KEY = "__json_file"
    private let LARGE_JSON_RESULT_FILE_THRESHOLD_BYTES = 256 * 1024
    private let streamQueue = DispatchQueue(label: "app.tango.progress_stream", qos: .utility)
    private lazy var downloadProgressSubscription = DownloadProgressSubscription(connect: { [weak self] in
        guard let self else { throw NSError(domain: "CoreBackend", code: 1) }
        return try self.coreBackend.openDownloadProgress()
    })
    private var libraryScanProgressTimer: DispatchSourceTimer?
    private var libraryScanProgressEventSink: FlutterEventSink?
    private var lastLibraryScanProgressPayload: String?
    private var libraryScanProgressGeneration: UInt64 = 0
    private var backendChannel: FlutterMethodChannel?
    private var concertCalendar: ConcertCalendarBridge?
    private var playbackNotification: PlaybackNotificationBridge?
    private var audioRouteInfo: AudioRouteInfoBridge?
    private var audioDiagnostics: AudioDiagnosticsBridge?
    private var bitPerfect: BitPerfectBridge?
    private var musicHaptics: MusicHapticsBridge?
    private let coreBackend: CoreBackend = createCoreBackend()
    private var pendingSessionGrantEvents: [[String: Any]] = []
    private let securityScopedAccessLock = NSLock()
    private var securityScopedAccesses: [String: (URL, CoreDirectoryScope)] = [:]
    
    // Folders picked through Files stay open for the whole process so songs in
    // them can be played in place, without copying them into the app.
    private let libraryBookmarksKey = "tango.pickedFolderBookmarks"
    private let heldLibraryAccessLock = NSLock()
    private var heldLibraryAccess: [String: URL] = [:]

    private var pendingDirectoryPickerResult: FlutterResult?
    private var importPickerResult: FlutterResult?
    private weak var importPicker: UIDocumentPickerViewController?

    /// Whether a download queue is active; while true a background assertion
    /// is acquired before work starts and renewed on later background entries.
    /// Main-thread only.
    private var downloadsActive = false
    private var downloadBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    /// Library scans and similar user-started work, by kind. Separate from
    /// downloads so ending one never drops the other's assertion.
    private var backgroundWorkTasks: [String: UIBackgroundTaskIdentifier] = [:]

    /// Strong reference to the in-flight ASWebAuthenticationSession; the
    /// session is deallocated (and its sheet dismissed) without it.
    private var activeWebAuthSession: ASWebAuthenticationSession?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        restoreLibraryFolderAccess()
        playerEngine.run()
        configureFlutterEngine(playerEngine.binaryMessenger, registry: playerEngine)
        if let url = launchOptions?[.url] as? URL {
            _ = handleExtensionOAuthRedirect(url: url)
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func configureFlutterEngine(_ messenger: FlutterBinaryMessenger, registry: FlutterPluginRegistry) {
        concertCalendar = ConcertCalendarBridge(messenger: messenger) { [weak self] in
            self?.activeWindow?.rootViewController
        }
        PlayerWidgetBridge.shared.attach(messenger)
        let channel = FlutterMethodChannel(
            name: CHANNEL,
            binaryMessenger: messenger
        )
        backendChannel = channel
        if !pendingSessionGrantEvents.isEmpty {
            let events = pendingSessionGrantEvents
            pendingSessionGrantEvents.removeAll()
            for event in events {
                channel.invokeMethod("extensionSessionGrantCompleted", arguments: event)
            }
        }
        let downloadProgressEvents = FlutterEventChannel(
            name: DOWNLOAD_PROGRESS_STREAM_CHANNEL,
            binaryMessenger: messenger
        )
        let libraryScanProgressEvents = FlutterEventChannel(
            name: LIBRARY_SCAN_PROGRESS_STREAM_CHANNEL,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call: call, result: result)
        }
        downloadProgressEvents.setStreamHandler(
            ClosureStreamHandler(
                onListen: { [weak self] _, events in
                    self?.startDownloadProgressStream(events)
                    return nil
                },
                onCancel: { [weak self] _ in
                    self?.stopDownloadProgressStream()
                    return nil
                }
            )
        )
        libraryScanProgressEvents.setStreamHandler(
            ClosureStreamHandler(
                onListen: { [weak self] _, events in
                    self?.startLibraryScanProgressStream(events)
                    return nil
                },
                onCancel: { [weak self] _ in
                    self?.stopLibraryScanProgressStream()
                    return nil
                }
            )
        )

        GeneratedPluginRegistrant.register(with: registry)
        playbackNotification = PlaybackNotificationBridge(messenger: messenger)
        audioRouteInfo = AudioRouteInfoBridge(messenger: messenger)
        audioDiagnostics = AudioDiagnosticsBridge(messenger: messenger)
        bitPerfect = BitPerfectBridge(messenger: messenger)
        musicHaptics = MusicHapticsBridge(messenger: messenger)
        registry.registrar(forPlugin: "AudioOutputView")?.register(
            AudioOutputViewFactory(messenger: messenger),
            withId: "app.tango/audio_output"
        )
    }

    /// The window of the foreground scene. Under the UIScene lifecycle the
    /// app delegate's own `window` is never set.
    var activeWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return active?.windows.first { $0.isKeyWindow } ?? active?.windows.first ?? window
    }

    /// Extension return URLs:
    /// - OAuth: tango://callback?code=...&state=<one_time_nonce>
    /// - Signed session: tango://session-grant?grant=...&state=<one_time_nonce>
    @discardableResult
    func handleExtensionOAuthRedirect(url: URL) -> Bool {
        if url.scheme == "tango", url.host == "player" {
            Task { _ = await PlayerWidgetBridge.shared.perform("open") }
            return true
        }
        guard let route = ExtensionCallbackParser.parse(url) else { return false }
        streamQueue.async {
            var extensionId = ""
            do {
                try self.coreBackend.completeAuthCallback(state: route.state, code: route.code, sessionGrant: route.isSessionGrant) {
                    extensionId = $0
                }
                if route.isSessionGrant {
                    DispatchQueue.main.async { [weak self] in
                        self?.notifySessionGrantCompleted(extensionId: extensionId)
                    }
                }
            } catch {
                if extensionId.isEmpty {
                    NSLog("Tango: Rejected invalid or expired extension callback")
                } else {
                    NSLog("Tango: Extension callback failed (code \((error as NSError).code))")
                }
            }
        }
        return true
    }

    private func notifySessionGrantCompleted(extensionId: String) {
        let payload: [String: Any] = [
            "extension_id": extensionId,
            "success": true,
        ]
        if let channel = backendChannel {
            channel.invokeMethod("extensionSessionGrantCompleted", arguments: payload)
        } else {
            pendingSessionGrantEvents.append(payload)
        }
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if handleExtensionOAuthRedirect(url: url) {
            return true
        }
        return super.application(app, open: url, options: options)
    }

    deinit {
        stopDownloadProgressStream()
        stopLibraryScanProgressStream()
    }

    private func startDownloadProgressStream(_ eventSink: @escaping FlutterEventSink) {
        downloadProgressSubscription.start(eventSink)
    }

    private func stopDownloadProgressStream() {
        downloadProgressSubscription.stop()
    }

    private func startLibraryScanProgressStream(_ eventSink: @escaping FlutterEventSink) {
        stopLibraryScanProgressStream()
        libraryScanProgressGeneration &+= 1
        let generation = libraryScanProgressGeneration
        libraryScanProgressEventSink = eventSink
        lastLibraryScanProgressPayload = nil

        let timer = DispatchSource.makeTimerSource(queue: streamQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(800))
        timer.setEventHandler { [weak self] in
            guard let self, self.libraryScanProgressGeneration == generation else { return }
            let payload = (try? self.coreBackend.getLibraryScanProgress()) ?? "{}"
            if payload == self.lastLibraryScanProgressPayload {
                return
            }
            self.lastLibraryScanProgressPayload = payload
            DispatchQueue.main.async { [weak self] in
                guard let self, self.libraryScanProgressGeneration == generation else { return }
                eventSink(self.parseJsonPayload(payload))
            }
        }
        libraryScanProgressTimer = timer
        timer.resume()
    }

    private func stopLibraryScanProgressStream() {
        libraryScanProgressGeneration &+= 1
        libraryScanProgressTimer?.setEventHandler {}
        libraryScanProgressTimer?.cancel()
        libraryScanProgressTimer = nil
        libraryScanProgressEventSink = nil
        lastLibraryScanProgressPayload = nil
    }

    private func parseJsonPayload(_ payload: String) -> Any {
        guard let data = payload.data(using: .utf8) else {
            return payload
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            return payload
        }
    }

    private func bridgeJsonResult(_ payload: String) -> Any {
        if payload.utf8.count < LARGE_JSON_RESULT_FILE_THRESHOLD_BYTES {
            return payload
        }

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("bridge_json_\(UUID().uuidString).json")
            try payload.write(to: url, atomically: true, encoding: .utf8)
            return [LARGE_JSON_RESULT_FILE_KEY: url.path]
        } catch {
            NSLog("Tango: failed to spill large bridge JSON result to file: \(error.localizedDescription)")
            return payload
        }
    }

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let osMethods: Set<String> = ["getBackendImplementations", "startWebAuthSession", "beginBackgroundDownloadTask", "endBackgroundDownloadTask",
            "startBackgroundWork", "updateBackgroundWork", "stopBackgroundWork",
            "pickIosDirectory", "importIosAudio", "startAccessingIosBookmark", "stopAccessingIosBookmark", "downloadCoverToFile", "releaseMemory", "releaseMemoryUnderPressure",
            "setLibraryCoverCacheDir", "scanLibraryFolderToNDJSONFile", "scanLibraryFolderIncremental",
            "getLibraryScanProgress", "cancelLibraryScan", "pauseLibraryScan", "resumeLibraryScan",
            "parseCueSheet", "extractCoverToFile",
            "rewriteSplitArtistTags", "writeM4AFreeformTags", "ensureAC4Config", "writeAC4Metadata", "reEnrichFile",
            "checkHiResAuthenticity"]
        if call.method == "setScreenAwake" {
            let args = call.arguments as? [String: Any]
            UIApplication.shared.isIdleTimerDisabled = args?["enabled"] as? Bool ?? false
            result(nil)
            return
        }
        if !osMethods.contains(call.method) {
            if call.method == "cancelNativeDataJob" {
                do {
                    result(try coreBackend.invokeApplication(method: call.method, arguments: call.arguments))
                } catch {
                    result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                }
                return
            }
            let arguments: Any?
            do {
                arguments = try coreBackend.prepareApplicationArguments(method: call.method, arguments: call.arguments)
            } catch {
                result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let value = try self.coreBackend.invokeApplication(method: call.method, arguments: arguments)
                    let response = call.method == "runNativeDataJob" && value is String
                        ? self.bridgeJsonResult(value as! String) : value
                    DispatchQueue.main.async { result(response) }
                } catch {
                    DispatchQueue.main.async { result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil)) }
                }
            }
            return
        }
        switch call.method {
        case "beginBackgroundDownloadTask":
            downloadsActive = true
            // Request the assertion before the long-running backend call starts.
            // Waiting for applicationDidEnterBackground is too late: iOS may
            // suspend the process before the assertion is granted.
            beginBackgroundDownloadTask()
            result(nil)
            return
        case "endBackgroundDownloadTask":
            downloadsActive = false
            endBackgroundDownloadTask()
            result(nil)
            return
        case "startBackgroundWork":
            let kind = (call.arguments as? [String: Any])?["kind"] as? String ?? ""
            beginBackgroundWorkTask(kind: kind)
            result(true)
            return
        case "updateBackgroundWork":
            result(nil)
            return
        case "stopBackgroundWork":
            let kind = (call.arguments as? [String: Any])?["kind"] as? String ?? ""
            endBackgroundWorkTask(kind: kind)
            result(nil)
            return
        case "pickIosDirectory":
            let useBrowser = (call.arguments as? [String: Any])?["useBrowser"] as? Bool ?? false
            pickIosDirectory(useBrowser: useBrowser, result: result)
            return
        case "importIosAudio":
            importIosAudio(result: result)
            return
        case "startWebAuthSession":
            let args = call.arguments as? [String: Any] ?? [:]
            let urlString = (args["url"] as? String) ?? ""
            let callbackScheme = (args["callback_scheme"] as? String) ?? "tango"
            startWebAuthSession(
                urlString: urlString,
                callbackScheme: callbackScheme,
                result: result
            )
            return
        default:
            break
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let response = try self.invokeOsMethod(call: call)
                DispatchQueue.main.async {
                    result(response)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    /// Runs a verification/OAuth page inside ASWebAuthenticationSession. The
    /// session intercepts the callback scheme in-process — no OS-level URL
    /// scheme registration is involved — so the flow completes even where the
    /// app's scheme is not registered with iOS (sideload containers such as
    /// LiveContainer). The callback URL is fed into the same deep-link handler
    /// the OS path uses. Returns whether the session was presented; completion
    /// is delivered later through the existing grant-event plumbing.
    private func startWebAuthSession(
        urlString: String,
        callbackScheme: String,
        result: @escaping FlutterResult
    ) {
        guard let url = URL(string: urlString), url.scheme?.lowercased() == "https" else {
            result(false)
            return
        }
        let scheme = callbackScheme.isEmpty ? "tango" : callbackScheme
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: scheme
        ) { [weak self] callbackURL, error in
            self?.activeWebAuthSession = nil
            guard let callbackURL = callbackURL else {
                if let error = error {
                    NSLog("Tango: web auth session ended: \(error.localizedDescription)")
                }
                return
            }
            _ = self?.handleExtensionOAuthRedirect(url: callbackURL)
        }
        session.presentationContextProvider = self
        // Share Safari's cookie store so captcha providers see an established
        // browsing context instead of a blank ephemeral one.
        session.prefersEphemeralWebBrowserSession = false
        activeWebAuthSession = session
        let started = session.start()
        if !started {
            activeWebAuthSession = nil
        }
        result(started)
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        didEnterBackground()
    }

    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        willEnterForeground()
    }

    /// Called by the application callbacks above and, under the UIScene
    /// lifecycle (where UIKit no longer sends those), by SceneDelegate.
    func didEnterBackground() {
        if downloadsActive {
            beginBackgroundDownloadTask()
        }
    }

    func willEnterForeground() {
        endBackgroundDownloadTask()
    }

    private func beginBackgroundDownloadTask() {
        if downloadBackgroundTask != .invalid { return }
        downloadBackgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "TangoDownloads"
        ) { [weak self] in
            if self?.downloadsActive == true {
                NSLog("Tango: download background task expired")
                // Flutter channel delivery is asynchronous and iOS may suspend
                // us immediately after this callback. Cancel live requests
                // synchronously first; Dart then persists/requeues the items.
                let cancelledItemIDs = (try? self?.coreBackend.cancelActiveDownloads()) ?? "[]"
                self?.backendChannel?.invokeMethod(
                    "iosBackgroundDownloadExpired",
                    arguments: cancelledItemIDs
                )
            }
            self?.endBackgroundDownloadTask()
        }
    }

    private func endBackgroundDownloadTask() {
        if downloadBackgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(downloadBackgroundTask)
            downloadBackgroundTask = .invalid
        }
    }

    /// iOS grants a short grace period after the app leaves the foreground,
    /// enough for a screen lock during a small scan. On expiry a scan is
    /// cancelled cleanly instead of being suspended mid-write.
    private func beginBackgroundWorkTask(kind: String) {
        guard !kind.isEmpty, backgroundWorkTasks[kind] == nil else { return }
        backgroundWorkTasks[kind] = UIApplication.shared.beginBackgroundTask(
            withName: "Tango-\(kind)"
        ) { [weak self] in
            NSLog("Tango: \(kind) background task expired")
            if kind == "library_scan" {
                try? self?.coreBackend.cancelLibraryScan()
            }
            self?.endBackgroundWorkTask(kind: kind)
        }
    }

    private func endBackgroundWorkTask(kind: String) {
        guard let task = backgroundWorkTasks.removeValue(forKey: kind) else { return }
        if task != .invalid {
            UIApplication.shared.endBackgroundTask(task)
        }
    }

    private func invokeOsMethod(call: FlutterMethodCall) throws -> Any? {

        switch call.method {
        case "getBackendImplementations":
            return [
                "filename": coreBackend.implementation,
                "file_metadata": coreBackend.fileMetadataImplementation(path: (call.arguments as? [String: Any])?["file_path"] as? String ?? ""),
                "extensions": coreBackend.implementation,
                "downloads": coreBackend.implementation,
            ]

        case "rewriteSplitArtistTags":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let artist = args["artist"] as! String
            let albumArtist = args["album_artist"] as! String
            return try coreBackend.rewriteSplitArtistTags(path: filePath, artist: artist, albumArtist: albumArtist)

        case "writeM4AFreeformTags":
            let args = call.arguments as! [String: Any]
            return try coreBackend.writeM4aFreeformTags(path: args["file_path"] as! String, metadataJson: args["metadata_json"] as? String ?? "{}")

        case "ensureAC4Config":
            let args = call.arguments as! [String: Any]
            return try coreBackend.ensureAc4Config(path: args["file_path"] as! String, reference: args["source_path"] as? String ?? "")

        case "writeAC4Metadata":
            let args = call.arguments as! [String: Any]
            return try coreBackend.writeAc4Metadata(path: args["file_path"] as! String, metadataJson: args["metadata_json"] as? String ?? "{}", coverPath: args["cover_path"] as? String ?? "")


        case "downloadCoverToFile":
            let args = call.arguments as! [String: Any]
            let coverURL = args["cover_url"] as! String
            let outputPath = args["output_path"] as! String
            let maxDimension = max(0, (args["max_dimension"] as? NSNumber)?.int64Value ?? 0)
            let temporary = outputPath.isEmpty ? try coreBackend.createTemporaryMediaFile(prefix: "cover_", suffix: ".jpg") : nil
            do {
                try coreBackend.downloadCoverToFileSized(url: coverURL, outputPath: temporary?.path ?? outputPath, maxDimension: maxDimension)
            } catch {
                if let temporary = temporary { try? FileManager.default.removeItem(at: temporary) }
                throw error
            }
            if let temporary = temporary {
                return String(decoding: try JSONSerialization.data(withJSONObject: ["success": true, "file_path": temporary.path]), as: UTF8.self)
            }
            return "{\"success\":true}"

        case "extractCoverToFile":
            let args = call.arguments as! [String: Any]
            let audioPath = args["audio_path"] as! String
            let outputPath = args["output_path"] as! String
            try coreBackend.extractCoverToFile(audioPath: audioPath, outputPath: outputPath)
            return "{\"success\":true}"


        case "reEnrichFile":
            let args = call.arguments as! [String: Any]
            let requestJson = args["request_json"] as? String ?? "{}"
            return try coreBackend.reEnrichFile(requestJson: requestJson)

        case "checkHiResAuthenticity":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            return try coreBackend.checkHiResAuthenticity(path: filePath, optionsJson: args["options_json"] as? String ?? "")

        case "releaseMemory":
            try coreBackend.releaseIdleResources()
            return nil

        case "releaseMemoryUnderPressure":
            try coreBackend.releaseMemoryUnderPressure()
            NSLog("Tango: Backend memory pressure release completed")
            return nil



        case "setLibraryCoverCacheDir":
            let args = call.arguments as! [String: Any]
            let cacheDir = args["cache_dir"] as! String
            try coreBackend.setLibraryCoverCacheDirectory(path: cacheDir)
            return nil

        case "scanLibraryFolderToNDJSONFile":
            guard
                let args = call.arguments as? [String: Any],
                let folderPath = args["folder_path"] as? String,
                !folderPath.isEmpty,
                let outputPath = args["output_path"] as? String,
                !outputPath.isEmpty
            else {
                throw invalidArgumentsError(call.method)
            }
            let count = try coreBackend.scanLibraryFolderToNdjsonFile(folder: folderPath, output: outputPath)
            guard let progress = parseJsonPayload(try coreBackend.getLibraryScanProgress()) as? [String: Any],
                  let errorCount = progress["error_count"] as? Int else {
                throw invalidArgumentsError("scanLibraryFolderToNDJSONFile: missing scan summary")
            }
            return ["path": outputPath, "count": count, "error_count": errorCount]

        case "scanLibraryFolderIncremental":
            let args = call.arguments as! [String: Any]
            let folderPath = args["folder_path"] as! String
            let existingFiles = args["existing_files"] as? String ?? "{}"
            return bridgeJsonResult(try coreBackend.scanLibraryFolderIncremental(folder: folderPath, existing: existingFiles))

        case "getLibraryScanProgress":
            return parseJsonPayload(try coreBackend.getLibraryScanProgress())

        case "cancelLibraryScan":
            try coreBackend.cancelLibraryScan()
            return nil

        case "pauseLibraryScan":
            try coreBackend.pauseLibraryScan()
            return nil

        case "resumeLibraryScan":
            try coreBackend.resumeLibraryScan()
            return nil


        case "startAccessingIosBookmark":
            guard
                let args = call.arguments as? [String: Any],
                let bookmarkBase64 = args["bookmark"] as? String,
                !bookmarkBase64.isEmpty
            else {
                throw invalidArgumentsError(call.method)
            }
            return try startAccessingIosBookmark(bookmarkBase64)

        case "stopAccessingIosBookmark":
            guard
                let args = call.arguments as? [String: Any],
                let token = args["token"] as? String,
                !token.isEmpty
            else {
                throw invalidArgumentsError(call.method)
            }
            stopAccessingIosBookmark(token: token)
            return nil


        case "parseCueSheet":
            let args = call.arguments as! [String: Any]
            let cuePath = args["cue_path"] as! String
            let audioDir = args["audio_dir"] as? String ?? ""
            return try coreBackend.parseCueSheet(path: cuePath, audioDirectory: audioDir)

        default:
            throw NSError(
                domain: "Tango",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Method not implemented: \(call.method)"]
            )
        }
    }

    // MARK: - Native Folder Picker

    /// Present a native folder picker and return `{path, bookmark}` where the
    /// security-scoped bookmark is created inside the picker callback, while
    /// the picker's access grant is still active. Returns nil on cancel.
    private func pickIosDirectory(useBrowser: Bool, result: @escaping FlutterResult) {
        if pendingDirectoryPickerResult != nil || importPickerResult != nil {
            result(FlutterError(
                code: "PICKER_ACTIVE",
                message: "A folder picker is already active",
                details: nil
            ))
            return
        }
        guard var topController = activeWindow?.rootViewController else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "No view controller available to present the folder picker",
                details: nil
            ))
            return
        }
        while let presented = topController.presentedViewController {
            topController = presented
        }
        pendingDirectoryPickerResult = result
        if useBrowser {
            // Full Files browser instead of the picker sheet. A folder tapped
            // here is reported through documentBrowser(_:didPickDocumentsAt:).
            let browser = UIDocumentBrowserViewController(forOpening: [UTType.folder])
            browser.delegate = self
            browser.allowsDocumentCreation = false
            browser.allowsPickingMultipleItems = false
            browser.modalPresentationStyle = .fullScreen
            browser.additionalLeadingNavigationBarButtonItems = [
                UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self, weak browser] _ in
                    browser?.dismiss(animated: true) { self?.finishDirectoryPick(urls: []) }
                })
            ]
            topController.present(browser, animated: true)
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        topController.present(picker, animated: true)
    }

    // MARK: - Import songs (copy into the app's Documents folder)

    /// Presents a picker that returns app-owned copies of the chosen audio
    /// files, so no security-scoped access to the original location is needed.
    private func importIosAudio(result: @escaping FlutterResult) {
        if pendingDirectoryPickerResult != nil || importPickerResult != nil {
            result(FlutterError(code: "PICKER_ACTIVE", message: "A picker is already active", details: nil))
            return
        }
        guard var topController = activeWindow?.rootViewController else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "No view controller available to present the file picker",
                details: nil
            ))
            return
        }
        while let presented = topController.presentedViewController {
            topController = presented
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        importPickerResult = result
        importPicker = picker
        topController.present(picker, animated: true)
    }

    fileprivate func finishAudioImport(urls: [URL]) {
        guard let result = importPickerResult else { return }
        importPickerResult = nil
        importPicker = nil
        guard !urls.isEmpty else {
            result(nil)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = documents.appendingPathComponent("Imported", isDirectory: true)
            try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
            func size(_ url: URL) -> Int64 {
                ((try? fm.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? -1
            }
            var imported = 0, skipped = 0, failed = 0
            for source in urls {
                let started = source.startAccessingSecurityScopedResource()
                defer { if started { source.stopAccessingSecurityScopedResource() } }
                let base = source.deletingPathExtension().lastPathComponent
                let ext = source.pathExtension
                var target = destination.appendingPathComponent(source.lastPathComponent)
                var counter = 2
                var duplicate = false
                while fm.fileExists(atPath: target.path) {
                    if size(target) == size(source) {
                        duplicate = true
                        break
                    }
                    let name = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
                    target = destination.appendingPathComponent(name)
                    counter += 1
                }
                if duplicate {
                    skipped += 1
                    continue
                }
                do {
                    try fm.moveItem(at: source, to: target)
                    imported += 1
                } catch {
                    do {
                        try fm.copyItem(at: source, to: target)
                        imported += 1
                    } catch {
                        failed += 1
                    }
                }
            }
            DispatchQueue.main.async {
                result(["imported": imported, "skipped": skipped, "failed": failed, "path": destination.path])
            }
        }
    }

    // MARK: - iOS Security-Scoped Bookmark Helpers

    private func invalidArgumentsError(_ method: String) -> NSError {
        return NSError(
            domain: "Tango",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid arguments for \(method)"]
        )
    }

    /// Starts an independently owned security-scoped lease.
    private func startAccessingIosBookmark(_ bookmarkBase64: String) throws -> [String: String] {
        guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
            throw NSError(
                domain: "Tango",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid base64 bookmark data"]
            )
        }

        var isStale = false
        let url: URL
        do {
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = .withSecurityScope
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw NSError(
                domain: "Tango",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to resolve bookmark: \(error.localizedDescription)"]
            )
        }

        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(
                domain: "Tango",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start accessing security-scoped resource at \(url.path)"]
            )
        }

        let scope: CoreDirectoryScope
        do {
            scope = try coreBackend.openDownloadDirectory(path: url.path)
        } catch {
            url.stopAccessingSecurityScopedResource()
            throw error
        }
        let token = UUID().uuidString
        securityScopedAccessLock.lock()
        securityScopedAccesses[token] = (url, scope)
        securityScopedAccessLock.unlock()
        return ["path": url.path, "token": token]
    }

    /// Releases only the lease identified by the caller's token.
    private func stopAccessingIosBookmark(token: String) {
        securityScopedAccessLock.lock()
        let lease = securityScopedAccesses.removeValue(forKey: token)
        securityScopedAccessLock.unlock()
        lease?.1.close()
        lease?.0.stopAccessingSecurityScopedResource()
    }

    // MARK: - Persistent access to picked library folders

    /// Remembers a folder picked through Files and keeps its security-scoped
    /// access open for the life of the process.
    fileprivate func rememberLibraryFolder(url: URL, bookmark: Data) {
        var stored = UserDefaults.standard.dictionary(forKey: libraryBookmarksKey) as? [String: String] ?? [:]
        stored[url.path] = bookmark.base64EncodedString()
        UserDefaults.standard.set(stored, forKey: libraryBookmarksKey)
        holdLibraryAccess(to: url)
    }

    fileprivate func holdLibraryAccess(to url: URL) {
        heldLibraryAccessLock.lock()
        defer { heldLibraryAccessLock.unlock() }
        if heldLibraryAccess[url.path] != nil { return }
        if url.startAccessingSecurityScopedResource() {
            heldLibraryAccess[url.path] = url
        }
    }

    /// Re-opens every folder picked in an earlier session so playback and
    /// scans can read it right after launch.
    private func restoreLibraryFolderAccess() {
        var stored = UserDefaults.standard.dictionary(forKey: libraryBookmarksKey) as? [String: String] ?? [:]
        guard !stored.isEmpty else { return }
        var changed = false
        for (path, encoded) in stored {
            guard let data = Data(base64Encoded: encoded) else {
                stored[path] = nil
                changed = true
                continue
            }
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }
            holdLibraryAccess(to: url)
            if isStale,
               let fresh = try? url.bookmarkData(
                   options: [],
                   includingResourceValuesForKeys: nil,
                   relativeTo: nil
               ) {
                stored[path] = fresh.base64EncodedString()
                changed = true
            }
        }
        if changed {
            UserDefaults.standard.set(stored, forKey: libraryBookmarksKey)
        }
    }
}

extension AppDelegate: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return activeWindow ?? ASPresentationAnchor()
    }
}

extension AppDelegate: UIDocumentPickerDelegate, UIDocumentBrowserViewControllerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        if controller === importPicker {
            finishAudioImport(urls: urls)
        } else {
            finishDirectoryPick(urls: urls)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        if controller === importPicker {
            finishAudioImport(urls: [])
        } else {
            finishDirectoryPick(urls: [])
        }
    }

    func documentBrowser(
        _ controller: UIDocumentBrowserViewController,
        didPickDocumentsAt documentURLs: [URL]
    ) {
        // Create the bookmark first, while the browser's grant is active.
        finishDirectoryPick(urls: documentURLs)
        controller.dismiss(animated: true)
    }

    fileprivate func finishDirectoryPick(urls: [URL]) {
        guard let result = pendingDirectoryPickerResult else { return }
        pendingDirectoryPickerResult = nil
        guard let url = urls.first else {
            result(nil)
            return
        }
        // The bookmark must be created here, from the picker's own URL, while
        // its security-scoped grant is active. A URL rebuilt from the path
        // string later has no grant, so bookmark creation either fails or
        // yields a bookmark that cannot re-open the folder.
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let bookmarkData = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            rememberLibraryFolder(url: url, bookmark: bookmarkData)
            result([
                "path": url.path,
                "bookmark": bookmarkData.base64EncodedString(),
            ])
        } catch {
            result(FlutterError(
                code: "BOOKMARK_FAILED",
                message: "Failed to create bookmark for \(url.path): \(error.localizedDescription)",
                details: nil
            ))
        }
    }
}

private final class ClosureStreamHandler: NSObject, FlutterStreamHandler {
    typealias ListenHandler = (_ arguments: Any?, _ events: @escaping FlutterEventSink) -> FlutterError?
    typealias CancelHandler = (_ arguments: Any?) -> FlutterError?

    private let onListenHandler: ListenHandler
    private let onCancelHandler: CancelHandler

    init(
        onListen: @escaping ListenHandler,
        onCancel: @escaping CancelHandler = { _ in nil }
    ) {
        self.onListenHandler = onListen
        self.onCancelHandler = onCancel
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListenHandler(arguments, events)
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onCancelHandler(arguments)
    }
}

/// UIScene lifecycle entry point (required from iOS 27). FlutterSceneDelegate
/// hosts the shared engine's FlutterViewController; this subclass forwards what
/// UIKit now delivers to the scene instead of the app delegate: OAuth
/// redirect URLs and the background/foreground transitions that keep
/// downloads alive.
class SceneDelegate: FlutterSceneDelegate {
    private var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let windowScene = scene as? UIWindowScene, let appDelegate {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = FlutterViewController(engine: appDelegate.playerEngine, nibName: nil, bundle: nil)
            self.window = window
            window.makeKeyAndVisible()
        }
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        for context in connectionOptions.urlContexts {
            _ = appDelegate?.handleExtensionOAuthRedirect(url: context.url)
        }
    }

    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        let unhandled = URLContexts.filter {
            appDelegate?.handleExtensionOAuthRedirect(url: $0.url) != true
        }
        if !unhandled.isEmpty {
            super.scene(scene, openURLContexts: unhandled)
        }
    }

    override func sceneDidEnterBackground(_ scene: UIScene) {
        super.sceneDidEnterBackground(scene)
        appDelegate?.didEnterBackground()
    }

    override func sceneWillEnterForeground(_ scene: UIScene) {
        super.sceneWillEnterForeground(scene)
        appDelegate?.willEnterForeground()
    }
}