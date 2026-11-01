import Foundation
import Security

struct Credentials: Codable, Equatable {
    var username: String
    var password: String
}

/// Stores the forum password in the system keychain so the app can silently
/// re-authenticate when the XenForo session cookie expires.
struct KeychainStore {
    private let service = "com.sinodefenceforum.reader.credentials"
    private let account = "xf"

    func load() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let credentials = try? JSONDecoder().decode(Credentials.self, from: data) else {
            return nil
        }
        return credentials
    }

    func save(_ credentials: Credentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status != errSecSuccess {
            // The item may have been removed, or the accessible attribute rejected an
            // update: recreate it rather than silently keeping stale credentials.
            SecItemDelete(query as CFDictionary)
            var insert = query
            insert.merge(attributes) { current, _ in current }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
