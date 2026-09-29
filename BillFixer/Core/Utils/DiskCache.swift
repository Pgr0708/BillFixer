import Foundation

/// Small offline cache for API responses (case list, case detail) so Home opens instantly and works offline.
/// Files are written with complete file protection and wiped on sign-out.
actor DiskCache {
    static let shared = DiskCache()
    private let dir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("api-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private func url(_ key: String) -> URL {
        dir.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_") + ".json")
    }

    func save<T: Encodable & Sendable>(_ value: T, key: String) {
        guard let data = try? JSONCoding.encoder().encode(value) else { return }
        try? data.write(to: url(key), options: [.atomic, .completeFileProtection])
    }

    func load<T: Decodable & Sendable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: url(key)) else { return nil }
        return try? JSONCoding.decoder().decode(T.self, from: data)
    }

    func remove(_ key: String) { try? FileManager.default.removeItem(at: url(key)) }

    func clear() {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
