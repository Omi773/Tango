import AppIntents
import Flutter
import UIKit

/// Bridges the "Resume Tango" App Intent to the Dart player. The intent runs
/// in the app's own process; when iOS had killed Tango it launches it in the
/// background first (AppDelegate starts the headless-capable engine).
final class ResumePlaybackBridge {
    static let shared = ResumePlaybackBridge()

    /// Dart installs its handler a moment after a cold launch, so retry until
    /// it answers instead of failing the first call.
    @MainActor
    func resume() async -> Bool {
        for attempt in 0..<40 {
            guard let engine = (UIApplication.shared.delegate as? AppDelegate)?.playerEngine else {
                try? await Task.sleep(nanoseconds: 250_000_000)
                continue
            }
            let channel = FlutterMethodChannel(
                name: "app.tango/resume_playback",
                binaryMessenger: engine.binaryMessenger
            )
            let outcome: Bool? = await withCheckedContinuation { continuation in
                channel.invokeMethod("resume", arguments: nil) { reply in
                    if let flag = reply as? Bool {
                        continuation.resume(returning: flag)
                    } else {
                        // FlutterMethodNotImplemented / FlutterError: Dart not ready yet.
                        continuation.resume(returning: nil)
                    }
                }
            }
            if let outcome { return outcome }
            try? await Task.sleep(nanoseconds: attempt < 8 ? 250_000_000 : 500_000_000)
        }
        return false
    }
}

/// An AudioPlaybackIntent is the one App Intent kind iOS lets start audio from
/// the background (Siri, Shortcuts, Action Button, Lock Screen / Control Center
/// controls) without opening the app.
@available(iOS 17.0, *)
struct ResumeTangoIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Resume Tango"
    static var description = IntentDescription("Resume playing music in Tango where you left off.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await ResumePlaybackBridge.shared.resume()
        return .result()
    }
}

@available(iOS 17.0, *)
struct TangoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ResumeTangoIntent(),
            phrases: [
                "Resume \(.applicationName)",
                "Play \(.applicationName)",
                "Resume music in \(.applicationName)",
            ],
            shortTitle: "Resume Tango",
            systemImageName: "play.fill"
        )
    }
}
