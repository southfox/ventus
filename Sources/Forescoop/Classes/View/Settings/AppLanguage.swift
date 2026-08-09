//
//  AppLanguage.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/09/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI
import ObjectiveC
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
        case .system: Bundle.mainLocalizedString("System")
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

    /// `nil` for `.system`. `Text`/`String(localized:)` resolve their string
    /// table via `Bundle.main`, which only exposes a plain language code.
    var languageCode: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .spanish: "es"
        }
    }
}

/// Applies the selected language override's locale (date/number formatting)
/// to a complete app scene.
///
/// This does *not* by itself change which language `Text`/`String(localized:)`
/// display — that's `Bundle.main`'s own localization resolution, switched
/// live by `Bundle.applyLanguageOverride` (called from `AppLanguageStore`,
/// synchronously, whenever the preference changes). Once that override is
/// in place, the normal SwiftUI re-render triggered by the `appLanguage`
/// state change is enough to make every `Text` re-resolve its string — no
/// forced `.id()` reset is needed, which would otherwise dismiss any sheet
/// (like Settings) presented above this view.
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

/// Bridges `Bundle.main`'s string lookups to a specific language's
/// `.lproj`, independent of the device's system language. This is the
/// standard technique for live in-app language switching: SwiftUI's `Text`
/// and Foundation's `String(localized:)` both resolve through
/// `Bundle.localizedString(forKey:value:table:)`, which normally follows
/// the device's preferred languages and is otherwise fixed for the life of
/// the process.
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    nonisolated(unsafe) static var override: Bundle?

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let override = LocalizedBundle.override else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return override.localizedString(forKey: key, value: value, table: tableName)
    }
}

public extension Bundle {
    /// Pass a language code (e.g. `"es"`) to pin `Bundle.main` lookups to
    /// that language's `.lproj`, or `nil` to restore the device's language.
    static func applyLanguageOverride(_ languageCode: String?) {
        if object_getClass(Bundle.main) != LocalizedBundle.self {
            object_setClass(Bundle.main, LocalizedBundle.self)
        }
        guard let languageCode, let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") else {
            LocalizedBundle.override = nil
            return
        }
        LocalizedBundle.override = Bundle(path: path)
    }

    /// Looks a key up directly through `Bundle.main`'s localization,
    /// including any `applyLanguageOverride`. Unlike `Text` (which resolves
    /// `LocalizedStringKey` literals through the same legacy lookup), the
    /// newer `String(localized:)` API does not consistently honor a
    /// bundle-class override, so dynamically-built strings should call this
    /// instead. `format` arguments substitute into the looked-up value the
    /// same way `String(format:)` does, e.g. for `"%lld models"`-style keys.
    static func mainLocalizedString(_ key: String, _ formatArguments: CVarArg...) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        guard !formatArguments.isEmpty else { return format }
        return String(format: format, arguments: formatArguments)
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

    /// Reads the stored preference and (re-)applies its bundle override.
    /// Safe to call from every process that shares this app group,
    /// including widget extensions, so it doubles as the setup call each
    /// process needs at launch.
    @discardableResult
    public static func load() -> AppLanguage {
        let language = defaults().string(forKey: key).flatMap(AppLanguage.init(rawValue:)) ?? .system
        Bundle.applyLanguageOverride(language.languageCode)
        return language
    }

    public static func save(_ language: AppLanguage) {
        defaults().set(language.rawValue, forKey: key)
        Bundle.applyLanguageOverride(language.languageCode)
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
