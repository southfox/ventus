//
//  AppLanguage.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/09/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

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

public protocol AppLanguageStoring: Sendable {
    func load() -> AppLanguage
    func save(_ language: AppLanguage)
}

public final class AppLanguageStore: AppLanguageStoring, @unchecked Sendable {
    private static let key = "appLanguage"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> AppLanguage {
        defaults.string(forKey: Self.key).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    public func save(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Self.key)
    }

    public static var currentLocale: Locale {
        let language = UserDefaults.standard.string(forKey: key).flatMap(AppLanguage.init(rawValue:)) ?? .system
        return language.locale ?? .current
    }
}

public extension Bundle {
    static var ventus: Bundle { .module }

    func localizedString(_ key: String, locale: Locale, formatArguments: [CVarArg] = []) -> String {
        guard let languageCode = locale.language.languageCode?.identifier else {
            return formatArguments.isEmpty ? key : String(format: key, arguments: formatArguments)
        }
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
    var localized: String {
        Bundle.ventus.localizedString(self, locale: AppLanguageStore.currentLocale)
    }

    func localized(locale: Locale) -> String {
        Bundle.ventus.localizedString(self, locale: locale)
    }

    func localized(formatArguments: [CVarArg]) -> String {
        Bundle.ventus.localizedString(self, locale: AppLanguageStore.currentLocale, formatArguments: formatArguments)
    }

    func localized(locale: Locale, formatArguments: [CVarArg]) -> String {
        Bundle.ventus.localizedString(self, locale: locale, formatArguments: formatArguments)
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
