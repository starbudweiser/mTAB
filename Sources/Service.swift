// Installation en service système : agent launchd de l'utilisateur (démarre à l'ouverture de session,
// relancé automatiquement après un arrêt inattendu ; quitter avec ⌘Q ne le relance pas).
import AppKit

enum Service {
    static var label: String { (Bundle.main.bundleIdentifier ?? "fr.stephan.mtab") + ".service" }
    static var plistURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist") }
    static var isInstalled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }
    static var runsAsService: Bool { ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] == label }

    /// Installe ou retire le service, puis relance mTAB sous le bon régime (l'appli se ferme et revient en ≈ 2 s).
    @MainActor static func set(_ on: Bool) {
        let uid = getuid()
        let app = Bundle.main.bundlePath
        var script: String
        if on {
            guard let exe = Bundle.main.executablePath else { return }
            let plist: [String: Any] = [
                "Label": label, "ProgramArguments": [exe], "RunAtLoad": true,
                "KeepAlive": ["SuccessfulExit": false], "ProcessType": "Interactive",
                "LimitLoadToSessionType": "Aqua", "ThrottleInterval": 5,
            ]
            try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard (plist as NSDictionary).write(to: plistURL, atomically: true) else { return }
            script = "sleep 1; /bin/launchctl bootout gui/\(uid)/\(label) 2>/dev/null; /bin/launchctl bootstrap gui/\(uid) '\(plistURL.path)'"
        } else {
            try? FileManager.default.removeItem(at: plistURL)
            script = "sleep 0.5; /bin/launchctl bootout gui/\(uid)/\(label) 2>/dev/null; sleep 1; /usr/bin/open -g '\(app)'"
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        p.arguments = ["/bin/sh", "-c", script]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try? p.run()
        NSApp.terminate(nil)
    }
}
