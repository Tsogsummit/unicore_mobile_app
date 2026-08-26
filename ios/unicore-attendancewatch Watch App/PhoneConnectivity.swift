import Foundation
import WatchConnectivity

/// Receives credentials pushed from the paired iPhone app and persists them to
/// the Keychain, publishing the current value so the UI can react.
@MainActor
final class PhoneConnectivity: NSObject, ObservableObject {
    static let shared = PhoneConnectivity()

    @Published private(set) var credentials: WatchCredentials?

    private override init() {
        credentials = CredentialStore.load()
        super.init()
    }

    /// Activates the WCSession. Call once when the app launches.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    fileprivate func apply(_ context: [String: Any]) {
        guard
            let username = context["username"] as? String,
            let password = context["password"] as? String
        else {
            return
        }

        if username.isEmpty || password.isEmpty {
            // Phone logged out — drop the mirrored credentials.
            CredentialStore.clear()
            credentials = nil
            return
        }

        let creds = WatchCredentials(username: username, password: password)
        CredentialStore.save(creds)
        credentials = creds
    }
}

extension PhoneConnectivity: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let received = session.receivedApplicationContext
        guard !received.isEmpty else { return }
        Task { @MainActor in self.apply(received) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in self.apply(userInfo) }
    }
}
