import Foundation

/// A deliberately non-production session used to verify an App Clip URL handoff.
///
/// The containing iOS app persists the invocation in its App Group so it can
/// reliably confirm the values it received from a universal-link handoff.
public struct AppClipDemoSession: Equatable, Sendable {
    public static let appGroupIdentifier = "group.org.forescoop.shared"

    public let bindingKey: String
    public let flowType: String
    public let receivedAt: Date

    public init?(invocationURL: URL?, receivedAt: Date = .now) {
        guard let invocationURL,
              invocationURL.path == "/account/autologin/" || invocationURL.path == "/account/autologin",
              let components = URLComponents(url: invocationURL, resolvingAgainstBaseURL: false),
              let bindingKey = components.queryItems?.first(where: { $0.name == "binding_key" })?.value,
              !bindingKey.isEmpty else {
            return nil
        }

        self.bindingKey = bindingKey
        self.flowType = components.queryItems?.first(where: { $0.name == "flow_type" })?.value ?? "unknown"
        self.receivedAt = receivedAt
    }

    public var displayToken: String {
        let visibleCharacters = 18
        guard bindingKey.count > visibleCharacters else { return bindingKey }
        return "\(bindingKey.prefix(visibleCharacters))…"
    }

    public func save() {
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
        defaults.set(bindingKey, forKey: "ventus.appClipDemo.bindingKey")
        defaults.set(flowType, forKey: "ventus.appClipDemo.flowType")
        defaults.set(receivedAt, forKey: "ventus.appClipDemo.receivedAt")
    }

    public static func load() -> Self? {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        guard let bindingKey = defaults.string(forKey: "ventus.appClipDemo.bindingKey"),
              let flowType = defaults.string(forKey: "ventus.appClipDemo.flowType") else {
            return nil
        }

        return Self(
            bindingKey: bindingKey,
            flowType: flowType,
            receivedAt: defaults.object(forKey: "ventus.appClipDemo.receivedAt") as? Date ?? .now
        )
    }

    private init(bindingKey: String, flowType: String, receivedAt: Date) {
        self.bindingKey = bindingKey
        self.flowType = flowType
        self.receivedAt = receivedAt
    }
}
