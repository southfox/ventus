//
//  AppLanguage.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/09/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

/// Overrides the app's display language independently of the device's
/// system language. "System" follows whatever language the device is set
/// to; the other cases pin the UI to a specific language's string table.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case spanish
    case german
    case french
    case portugueseBrazil

    public var id: String { rawValue }

    /// English and Spanish are deliberately shown in their own language
    /// (matching Apple's own language pickers), so only "System" is
    /// translated — using `locale` rather than the environment, since this
    /// is read from call sites (like the picker row itself) that need it
    /// explicitly.
    public func title(locale: Locale) -> String {
        switch self {
        case .system: "🌐 " + Bundle.main.localizedString("System", locale: locale)
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

/// Applies the selected language override to a complete app scene.
///
/// `Text` and `String(localized:locale:)` both resolve their string table
/// from this environment value once `Bundle.main` itself carries every
/// language's strings (see `Sources/Forescoop/Resources/Localizable.xcstrings`,
/// wired into each app target directly) — no bundle-swapping trick needed.
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
    /// Looks `key` up in `locale`'s specific `.strings` table, independent
    /// of the device's system language or `String(localized:locale:)`
    /// (whose `locale:` parameter only affects argument formatting, not
    /// which language's translation gets picked — confirmed by tracing
    /// actual lookups, not assumed).
    ///
    /// Reads the compiled `.strings` file directly as a dictionary rather
    /// than going through `Bundle.localizedString`: pointing a `Bundle` at
    /// an `.lproj` folder and calling `localizedString` on it does *not*
    /// work — that API expects `self` to be an app-root bundle containing
    /// `xx.lproj` subdirectories, not a bundle that *is* one, so it looks
    /// for the nonexistent `es.lproj/es.lproj/Localizable.strings` and
    /// silently falls back to returning `key` unchanged.
    func localizedString(_ key: String, locale: Locale, formatArguments: [CVarArg] = []) -> String {
        guard let languageCode = locale.language.languageCode?.identifier else {
            return formatArguments.isEmpty ? key : String(format: key, arguments: formatArguments)
        }
        // Most languages only ship a bare-language-code table ("es.lproj"),
        // but region-specific variants like Brazilian Portuguese need the
        // full "pt-BR.lproj" — the bare "pt" table doesn't exist, so that
        // candidate is tried first and the language code is the fallback.
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
