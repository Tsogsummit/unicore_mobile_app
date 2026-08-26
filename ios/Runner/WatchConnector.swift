import Foundation
import WatchConnectivity

/// Pushes the signed-in account's credentials to the paired Apple Watch app
/// using WatchConnectivity's application-context channel (persisted and
/// delivered even if the watch app is not currently running).
final class WatchConnector: NSObject {
    static let shared = WatchConnector()

    /// Context queued while the session finishes activating.
    private var pendingContext: [String: Any]?

    private override init() {
        super.init()
    }

    /// Activates the WCSession. Call once at app launch.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Mirrors the given credentials to the watch.
    func sync(username: String, password: String) {
        send(["username": username, "password": password])
    }

    /// Clears the credentials mirrored to the watch.
    func clear() {
        send(["username": "", "password": ""])
    }

    private func send(_ context: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState == .activated {
            try? session.updateApplicationContext(context)
        } else {
            // Not ready yet — remember it and flush once activated.
            pendingContext = context
            session.activate()
        }
    }
}

extension WatchConnector: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        guard activationState == .activated, let context = pendingContext else { return }
        pendingContext = nil
        try? session.updateApplicationContext(context)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate to keep serving a possibly re-paired watch.
        WCSession.default.activate()
    }
}
