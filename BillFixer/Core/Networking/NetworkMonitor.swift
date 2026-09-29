import Foundation
import Network
import Observation

/// Live connectivity for the offline banner. Path updates arrive on a background queue.
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private(set) var isOnline = true
    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "BillFixer.NetworkMonitor", qos: .utility))
    }
}
