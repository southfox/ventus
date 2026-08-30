//
//  ForecastAlertNotificationNarrator.swift
//  Ventus
//

import Foundation

#if canImport(FoundationModels) && !os(tvOS)
import FoundationModels
#endif

/// Produces a human-readable explanation for a forecast alert. On devices
/// with Apple Intelligence it refines the factual draft; every platform keeps
/// the same clear, localized deterministic fallback.
enum ForecastAlertNotificationNarrator {
    struct Facts: Sendable {
        let location: String
        let time: String
        let languageCode: String
        let conditions: [String]

        var title: String {
            languageCode == "es" ? "Alerta meteorológica · \(location)" : "Weather alert · \(location)"
        }

        var fallback: String {
            let details = conditions.joined(separator: languageCode == "es" ? " y " : " and ")
            if languageCode == "es" {
                return "A las \(time), se esperan \(details) en \(location)."
            }
            return "At \(time), expect \(details) in \(location)."
        }

        var prompt: String {
            "Location: \(location). Time: \(time). Forecast facts: \(conditions.joined(separator: "; "))."
        }
    }

    static func facts(
        for alert: ForecastAlert,
        forecast: Forecast,
        hour: String,
        date: Date,
        location: String,
        locale: Locale = AppLanguageStore.currentLocale
    ) -> Facts {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("jm")

        // A default precipitation ≥ 0 rule is useful for configuring an alert,
        // but says nothing useful in the notification itself.
        let details = alert.conditions.compactMap { condition -> String? in
            guard let value = condition.variable.value(in: forecast, hour: hour) else { return nil }
            if condition.variable == .precipitation,
               condition.comparator == .greaterThanOrEqual,
               condition.value < 0.1 {
                return nil
            }
            return conditionDescription(condition.variable, value: value, languageCode: languageCode)
        }

        let fallbackDetails = details.isEmpty
            ? [languageCode == "es" ? "las condiciones configuradas" : "the conditions you follow"]
            : details
        return Facts(
            location: location,
            time: formatter.string(from: date),
            languageCode: languageCode,
            conditions: fallbackDetails
        )
    }

    static func body(for facts: Facts) async -> String {
#if canImport(FoundationModels) && !os(tvOS)
        guard SystemLanguageModel.default.isAvailable else { return facts.fallback }
        do {
            let language = Locale(identifier: "en").localizedString(forLanguageCode: facts.languageCode) ?? "English"
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: """
                You write one concise local weather notification.
                Use only the supplied forecast facts. Write one sentence, at most 24 words, in \(language).
                Explain what is expected, where, and when in natural language.
                Do not mention alert rules, thresholds, comparisons, model uncertainty, or give generic safety advice.
                """
            )
            let response = try await session.respond(to: facts.prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? facts.fallback : text
        } catch {
            return facts.fallback
        }
#else
        return facts.fallback
#endif
    }

    private static func conditionDescription(
        _ variable: ForecastAlertVariable,
        value: Double,
        languageCode: String
    ) -> String {
        let number = value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
        let valueText = "\(number)\(variable.unit)"
        if languageCode == "es" {
            switch variable {
            case .temperature: return "temperaturas cercanas a \(valueText)"
            case .windSpeed: return "viento de \(valueText)"
            case .windGusts: return "ráfagas de \(valueText)"
            case .precipitation: return "precipitación de \(valueText)"
            case .waveHeight: return "olas de \(valueText)"
            case .seaLevelPressure: return "presión de \(valueText)"
            case .freezingLevel: return "nivel de congelación a \(valueText)"
            }
        }
        switch variable {
        case .temperature: return "temperatures near \(valueText)"
        case .windSpeed: return "winds around \(valueText)"
        case .windGusts: return "gusts around \(valueText)"
        case .precipitation: return "precipitation around \(valueText)"
        case .waveHeight: return "waves around \(valueText)"
        case .seaLevelPressure: return "pressure near \(valueText)"
        case .freezingLevel: return "a freezing level near \(valueText)"
        }
    }
}
