//
//  VentusFirebase.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/20/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

public enum VentusFirebase {
    private static let deviceIdentifierKey = "ventusFirebaseDeviceIdentifier"

    public static var deviceIdentifier: String {
        if let existing = VentusPreferenceStore.value(forKey: deviceIdentifierKey) {
            return existing
        }
        let generated = UUID().uuidString
        VentusPreferenceStore.save(generated, forKey: deviceIdentifierKey)
        return generated
    }

    public static func configure() {
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

    public static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
#if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
#endif
    }

    public static func setUserProperty(_ value: String?, forName name: String) {
#if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
#endif
    }

    public static func log(_ message: String) {
#if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
#endif
    }

    public static func recordError(_ error: Error) {
#if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error)
#endif
    }
}
