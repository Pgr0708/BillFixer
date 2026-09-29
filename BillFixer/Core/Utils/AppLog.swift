import OSLog

/// Structured logging. Never pass document text, names, DOBs, member IDs or amounts (AGENTS.md privacy rules).
nonisolated enum AppLog {
    static let network = Logger(subsystem: "com.bhavik.BillFixer", category: "network")
    static let auth = Logger(subsystem: "com.bhavik.BillFixer", category: "auth")
    static let capture = Logger(subsystem: "com.bhavik.BillFixer", category: "capture")
    static let purchases = Logger(subsystem: "com.bhavik.BillFixer", category: "purchases")
    static let app = Logger(subsystem: "com.bhavik.BillFixer", category: "app")
}
