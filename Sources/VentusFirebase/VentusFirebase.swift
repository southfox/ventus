//
//  VentusFirebase.swift
//  VentusFirebase package target
//
//  Firebase is deliberately isolated from the core Ventus UI target. This
//  prevents a SwiftUI preview from linking the Firebase dependency graph.
//

import Foundation
import Ventus

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

public final class VentusFirebase: AnalyticsLogging, @unchecked Sendable {
    private static let deviceIdentifierKey = "ventusFirebaseDeviceIdentifier"

    public init() {}

    private var deviceIdentifier: String {
        if let existing = UserDefaults.standard.string(forKey: Self.deviceIdentifierKey) {
            return existing
        }

        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: Self.deviceIdentifierKey)
        return generated
    }

    public func configure() {
#if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
#endif
#if canImport(FirebaseAnalytics)
        Analytics.setUserID(deviceIdentifier)
#endif
#if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(deviceIdentifier)
#endif
    }

    public func logEvent(_ name: String, parameters: [String: Any]? = nil) {
#if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
#endif
    }

    public func setUserProperty(_ value: String?, forName name: String) {
#if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
#endif
    }

    public func log(_ message: String) {
#if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
#endif
    }

    public func recordError(_ error: Error) {
#if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error)
#endif
    }
}
