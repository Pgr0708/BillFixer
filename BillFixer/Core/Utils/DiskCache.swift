import Foundation

/// Small offline cache for API responses (cases, letters, scripts, reference data) so screens open instantly and work offline.
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

    /// Returns a cached copy younger than `maxAge`; otherwise fetches and caches a fresh one.
    /// If the fetch fails (e.g. offline), falls back to any cached copy, however old.
    func fetch<T: Codable & Sendable>(_ key: String, maxAge: TimeInterval = 0, _ load: @Sendable () async throws -> T) async throws -> T {
        if maxAge > 0, let age = age(key), age < maxAge, let cached = self.load(T.self, key: key) { return cached }
        do {
            let fresh = try await load()
            save(fresh, key: key)
            return fresh
        } catch {
            if !(error is CancellationError), (error as? URLError)?.code != .cancelled, let cached = self.load(T.self, key: key) { return cached }
            throw error
        }
    }

    private func age(_ key: String) -> TimeInterval? {
        let modified = try? FileManager.default.attributesOfItem(atPath: url(key).path)[.modificationDate] as? Date
        return modified.map { -$0.timeIntervalSinceNow }
    }

    func remove(_ key: String) { try? FileManager.default.removeItem(at: url(key)) }

    func clear() {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
