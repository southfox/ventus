//
//  AppLanguage.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/09/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Overrides the app's display language independently of the device's
/// system language. "System" follows whatever language the device is set
/// to; the other cases pin the UI to a specific language's string table.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case spanish

    public var id: String { rawValue }

    /// English and Spanish are deliberately shown in their own language
    /// (matching Apple's own language pickers), so only "System" is
    /// translated.
    public var title: String {
        switch self {
        case .system: String(localized: "System")
        case .english: "English"
        case .spanish: "Español"
        }
    }

    /// `nil` for `.system`, meaning no override is applied and the device's
    /// current language is used.
    public var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .spanish: Locale(identifier: "es")
        }
    }
}

/// Applies the selected language override to a complete app scene. Views
/// that don't opt into an override keep following the device's language.
public extension View {
    @ViewBuilder
    func appLanguage(_ language: AppLanguage) -> some View {
        if let locale = language.locale {
            environment(\.locale, locale)
        } else {
            self
        }
    }
}

/// Language storage shared by every Forescoop target installed on this
/// device. The App Group is intentionally also used by the widget
/// extensions so their content follows the same language override.
public enum AppLanguageStore {
    private static let key = "appLanguage"
    private static let appGroupIdentifier = "group.org.forescoop.shared"
    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    public static func load() -> AppLanguage {
        defaults().string(forKey: key).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    public static func save(_ language: AppLanguage) {
        defaults().set(language.rawValue, forKey: key)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}

#if DEBUG
#Preview("App language") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(AppLanguage.allCases) { language in
            Text(language.title)
        }
    }
    .padding()
}
#endif
