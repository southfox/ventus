//
//  NetworkConnectionMonitor.swift
//  VentusPackage
//

#if !os(watchOS)
import Combine
import Network

/// Keeps the forecast UI informed of an unavailable network path. This does
/// not test a particular server: it reports whether the device has a usable
/// network connection at all, which makes Airplane Mode immediate.
@MainActor
final class NetworkConnectionMonitor: ObservableObject {
    enum State: Equatable {
        case checking
        case connected
        case disconnected
    }

    @Published private(set) var state: State = .checking

    var isDisconnected: Bool { state == .disconnected }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mobilepatagonia.ventus.network-monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.state = path.status == .satisfied ? .connected : .disconnected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
#endif
