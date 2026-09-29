import Foundation
import OSLog
import Security

/// Secrets live in the Keychain only (AGENTS.md rule 4) — never UserDefaults or the bundle.
nonisolated enum KeychainStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "BillFixer") + ".auth"

    private static func base(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        let data = Data(value.utf8)
        let query = base(key)
        let update: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add.merge(update) { $1 }
            let added = SecItemAdd(add as CFDictionary, nil)
            if added != errSecSuccess { AppLog.auth.error("Keychain add failed: \(added, privacy: .public)") }
            return added == errSecSuccess
        }
        if status != errSecSuccess { AppLog.auth.error("Keychain update failed: \(status, privacy: .public)") }
        return status == errSecSuccess
    }

    static func get(_ key: String) -> String? {
        var query = base(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete(base(key) as CFDictionary)
    }
}

/// In-memory mirror of the session tokens, persisted to the Keychain.
actor TokenStore {
    static let shared = TokenStore()
    private var access: String?
    private var refresh: String?
    private var loaded = false

    private func load() {
        guard !loaded else { return }
        access = KeychainStore.get("accessToken")
        refresh = KeychainStore.get("refreshToken")
        loaded = true
    }

    func accessToken() -> String? { load(); return access }
    func refreshToken() -> String? { load(); return refresh }
    func hasSession() -> Bool { load(); return refresh != nil }

    func save(access: String, refresh: String) {
        self.access = access
        self.refresh = refresh
        loaded = true
        KeychainStore.set(access, for: "accessToken")
        KeychainStore.set(refresh, for: "refreshToken")
    }

    func clear() {
        access = nil
        refresh = nil
        loaded = true
        KeychainStore.delete("accessToken")
        KeychainStore.delete("refreshToken")
    }
}
