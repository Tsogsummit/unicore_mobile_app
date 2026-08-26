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
        delete(usernameKey)
        delete(passwordKey)
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
