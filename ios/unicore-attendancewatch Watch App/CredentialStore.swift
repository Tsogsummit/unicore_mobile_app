import Foundation
import Security

/// Credentials mirrored from the paired iPhone app.
struct WatchCredentials: Equatable {
    let username: String
    let password: String
}

/// Keychain-backed storage for the credentials the phone pushes to the watch.
/// Nothing is baked into the binary — the store is empty until the phone syncs.
enum CredentialStore {
    private static let service = "systems.unicore.unicoreMobileApp.watch"
    private static let usernameKey = "username"
    private static let passwordKey = "password"

    static func save(_ credentials: WatchCredentials) {
        set(credentials.username, for: usernameKey)
        set(credentials.password, for: passwordKey)
    }

    static func load() -> WatchCredentials? {
        guard
            let username = get(usernameKey), !username.isEmpty,
            let password = get(passwordKey), !password.isEmpty
        else {
            return nil
        }
        return WatchCredentials(username: username, password: password)
    }

    static func clear() {
        if let username = get(usernameKey) { clearSession(account: username) }
        delete(usernameKey)
        delete(passwordKey)
    }

    static func saveSession(account: String, uid: String, platform: String, token: String, lookupToken: String = "") {
        let data = ["uid": uid, "platform": platform, "token": token, "lookup_token": lookupToken]
        if let bytes = try? JSONSerialization.data(withJSONObject: data), let text = String(data: bytes, encoding: .utf8) {
            set(text, for: "session.tenant_65." + account.lowercased())
        }
    }

    static func loadSession(account: String) -> [String: String]? {
        guard let text = get("session.tenant_65." + account.lowercased()), let bytes = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: bytes)) as? [String: String]
    }

    static func clearSession(account: String) {
        delete("session.tenant_65." + account.lowercased())
    }

    // MARK: - Keychain primitives

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    private static func set(_ value: String, for key: String) {
        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func get(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }
}
