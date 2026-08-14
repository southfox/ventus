//
//  AppLanguage.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/09/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

/// Overrides the app's display language independently of the device's
/// system language. "System" follows whatever language the device is set to..
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case spanish
    case german
    case french
    case portugueseBrazil

    public var id: String { rawValue }

    public func title(locale: Locale) -> String {
        switch self {
        case .system: "🌐 " + "System".localized(locale: locale)
        case .english: "🇺🇸 English (US)"
        case .spanish: "🇪🇸 Español (España)"
        case .german: "🇩🇪 Deutsch"
        case .french: "🇫🇷 Français"
        case .portugueseBrazil: "🇧🇷 Português (Brasil)"
        }
    }

    /// `nil` for `.system`, meaning no override is applied and the device's
    /// current language is used.
    public var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .spanish: Locale(identifier: "es")
        case .german: Locale(identifier: "de")
        case .french: Locale(identifier: "fr")
        case .portugueseBrazil: Locale(identifier: "pt-BR")
        }
    }
}

/// Applies the selected language override to the scene; Text and String(localized:locale:) resolve using the environment locale when all languages are in Bundle.main (no bundle swap needed).
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

/// Per-app language preference.
public enum AppLanguageStore {
    private static let key = "appLanguage"

    public static func load() -> AppLanguage {
        UserDefaults.standard.string(forKey: key).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    public static func save(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: key)
    }

    /// For code outside the SwiftUI view hierarchy (model types, widget
    /// timeline providers) that can't read `@Environment(\.locale)`.
    public static var currentLocale: Locale {
        load().locale ?? .current
    }
}

public extension Bundle {
    /// The Forescoop package's own resource bundle, which carries every
    /// language's compiled `Localizable.xcstrings` regardless of the app
    /// target: several targets (including the `iOSnowatch` App Store
    /// target, both widget extensions, and `Forescoop_Tests`) don't embed
    /// `Localizable.xcstrings` into their own `Bundle.main` — only this
    /// package's `Bundle.module` reliably has every `.lproj` table on every
    /// target.
    static var forescoop: Bundle { .module }

    /// Looks up a key directly in the specified locale’s Localizable.strings (bypassing Bundle.localizedString and avoiding lproj bundle pitfalls) so translations respect the chosen app language rather than the device language.
    func localizedString(_ key: String, locale: Locale, formatArguments: [CVarArg] = []) -> String {
        guard let languageCode = locale.language.languageCode?.identifier else {
            return formatArguments.isEmpty ? key : String(format: key, arguments: formatArguments)
        }
        // Try the region-specific lproj (like "pt-BR.lproj") first, and fall back to the base language table (like "pt.lproj") if the regional one isn’t available.
        let regionQualified = locale.language.region.map { "\(languageCode)-\($0.identifier)" }
        for candidate in [regionQualified, languageCode].compactMap({ $0 }) {
            guard let lprojPath = path(forResource: candidate, ofType: "lproj"),
                  let stringsPath = Bundle(path: lprojPath)?.path(forResource: "Localizable", ofType: "strings"),
                  let table = NSDictionary(contentsOfFile: stringsPath) as? [String: String],
                  let format = table[key] else { continue }
            return formatArguments.isEmpty ? format : String(format: format, arguments: formatArguments)
        }
        return formatArguments.isEmpty ? key : String(format: key, arguments: formatArguments)
    }
}

public extension String {
    /// Localizes `self` using the app's current language override
    /// (`AppLanguageStore.currentLocale`), independent of the device's
    /// system language.
    var localized: String {
        Bundle.forescoop.localizedString(self, locale: AppLanguageStore.currentLocale)
    }

    /// Localizes `self` using an explicit locale, e.g. one read from
    /// `@Environment(\.locale)` at the call site.
    func localized(locale: Locale) -> String {
        Bundle.forescoop.localizedString(self, locale: locale)
    }

    /// Localizes `self` as a format string, substituting `formatArguments`,
    /// using the app's current language override.
    func localized(formatArguments: [CVarArg]) -> String {
        Bundle.forescoop.localizedString(self, locale: AppLanguageStore.currentLocale, formatArguments: formatArguments)
    }
}

#if DEBUG
#Preview("App language") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(AppLanguage.allCases) { language in
            Text(language.title(locale: .current))
        }
    }
    .padding()
}
#endif
