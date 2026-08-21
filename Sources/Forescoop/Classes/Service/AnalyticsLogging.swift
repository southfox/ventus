//
//  AnalyticsLogging.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/20/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation
import SwiftUI

/// Everything the app needs from an analytics/crash-reporting backend.
/// View models take a conformer through their initializer (matching how
/// `forecastService: ForecastWindguruProtocol` is already injected), and
/// views read one from `@Environment(\.analytics)` — this is what makes
/// `VentusFirebase` swappable for a spy/no-op in tests and previews instead
/// of every call site being hardwired to Firebase.
public protocol AnalyticsLogging: Sendable {
    func configure()
    func logEvent(_ name: String, parameters: [String: Any]?)
    func setUserProperty(_ value: String?, forName name: String)
    /// Crashlytics breadcrumb: shows up alongside the next crash/non-fatal
    /// report, not as its own event.
    func log(_ message: String)
    func recordError(_ error: Error)
}

public extension AnalyticsLogging {
    func log(_ event: AnalyticsEvent) {
        logEvent(event.name, parameters: event.parameters)
    }
}

/// Drops every call on the floor. Used as the default in Xcode previews and
/// in tests that don't care about analytics, so nothing has to reach for
/// real Firebase just to render a view or exercise a view model.
public final class NoOpAnalyticsLogger: AnalyticsLogging {
    public init() {}
    public func configure() {}
    public func logEvent(_ name: String, parameters: [String: Any]?) {}
    public func setUserProperty(_ value: String?, forName name: String) {}
    public func log(_ message: String) {}
    public func recordError(_ error: Error) {}
}

private struct AnalyticsLoggingKey: EnvironmentKey {
    static let defaultValue: AnalyticsLogging = NoOpAnalyticsLogger()
}

public extension EnvironmentValues {
    var analytics: AnalyticsLogging {
        get { self[AnalyticsLoggingKey.self] }
        set { self[AnalyticsLoggingKey.self] = newValue }
    }
}

private struct AnalyticsScreenViewModifier: ViewModifier {
    @Environment(\.analytics) private var analytics
    let screenName: String

    func body(content: Content) -> some View {
        content.onAppear {
            analytics.log("screen: \(screenName)")
            analytics.log(.screenView(screenName))
        }
    }
}

public extension View {
    /// Logs a `screen_view` Analytics event, and a matching Crashlytics
    /// breadcrumb, every time this view appears — using whichever
    /// `AnalyticsLogging` is in the environment.
    func trackScreenView(_ screenName: String) -> some View {
        modifier(AnalyticsScreenViewModifier(screenName: screenName))
    }
}
