#if !os(watchOS)
import SwiftUI

#if canImport(FoundationModels) && !os(tvOS)
import FoundationModels
#endif

public struct ForecastIntelligenceSummary: View {
    @Environment(\.ventusTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private let snapshot: ForecastIntelligenceSnapshot
    @State private var summary: String
    @State private var isGenerating = false

    public init(
        forecast: SpotForecast,
        hour: String?,
        temperatureUnit: TemperatureUnit = DeviceForecastPreferences.temperatureUnit,
        windSpeedUnit: WindSpeedUnit = DeviceForecastPreferences.windSpeedUnit,
        precipitationUnit: PrecipitationUnit = DeviceForecastPreferences.precipitationUnit,
        locale: Locale = AppLanguageStore.currentLocale
    ) {
        let snapshot = ForecastIntelligenceSnapshot(
            forecast: forecast,
            hour: hour,
            temperatureUnit: temperatureUnit,
            windSpeedUnit: windSpeedUnit,
            precipitationUnit: precipitationUnit,
            locale: locale
        )
        self.snapshot = snapshot
        _summary = State(initialValue: snapshot.deterministicSummary)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label("Forecast insight", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(theme.accentColor)
                if isGenerating {
                    ProgressView().controlSize(.small)
                }
            }
            Text(summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background {
            if theme.usesMaterial {
                RoundedRectangle(cornerRadius: 14).fill(.regularMaterial)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.backgroundColor(for: colorScheme).opacity(theme == .system ? 0.2 : 0.82))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.accentColor.opacity(0.25))
        }
        .ventusGlassEffect(theme: theme, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Forecast insight. \(summary)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("forecast.insight")
        .task(id: snapshot) {
            await generateSummary()
        }
    }

    @MainActor
    private func generateSummary() async {
        summary = snapshot.deterministicSummary
#if canImport(FoundationModels) && !os(tvOS)
        guard SystemLanguageModel.default.isAvailable else { return }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: "You are a precise weather forecaster. Write one helpful sentence, under 28 words. Use only the supplied forecast facts. Do not invent safety advice or facts. \(snapshot.languageInstruction)"
            )
            let response = try await session.respond(to: snapshot.prompt)
            let generated = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !generated.isEmpty {
                summary = generated
            }
        } catch {
        }
#endif
    }
}

private struct ForecastIntelligenceSnapshot: Hashable, Sendable {
    let hour: String
    let temperature: String
    let wind: String
    let gust: String?
    let hasSignificantGust: Bool
    let rain: String
    let hasRain: Bool
    let humidity: Int?
    let cloudCover: Int?
    let locale: Locale

    init(
        forecast: SpotForecast,
        hour: String?,
        temperatureUnit: TemperatureUnit,
        windSpeedUnit: WindSpeedUnit,
        precipitationUnit: PrecipitationUnit,
        locale: Locale
    ) {
        let hour = hour ?? forecast.currentForecastHour ?? "0"
        let source = forecast.forecast
        self.hour = hour
        self.locale = locale
        let temperatureCelsius = source?.temperatureReal(hh: hour) ?? source?.temperature(hh: hour) ?? 0
        temperature = Self.temperature(temperatureCelsius, unit: temperatureUnit, locale: locale)
        let windKnots = source?.windSpeed(hh: hour) ?? 0
        let gustKnots = source?.windGustsKnots(hh: hour)
        wind = Self.wind(windKnots, unit: windSpeedUnit, locale: locale)
        gust = gustKnots.map { Self.wind($0, unit: windSpeedUnit, locale: locale) }
        hasSignificantGust = gustKnots.map { $0 >= windKnots + 8 } ?? false
        let millimeters = source?.precipitation1(hh: hour) ?? source?.precipitation(hh: hour) ?? 0
        rain = Self.precipitation(millimeters, unit: precipitationUnit, locale: locale)
        hasRain = millimeters > 0
        humidity = source?.relativeHumidity(hh: hour)
        cloudCover = source?.cloudCoverTotal(hh: hour)
    }

    var languageInstruction: String {
        let code = locale.language.languageCode?.identifier ?? "en"
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
        return "Respond in \(name)."
    }

    var prompt: String {
        "Forecast hour: \(hour). Temperature: \(temperature). Wind: \(wind). Gusts: \(gust ?? "unavailable"). Rain: \(rain). Humidity: \(humidity.map(String.init) ?? "unavailable")%. Cloud cover: \(cloudCover.map(String.init) ?? "unavailable")%."
    }

    var deterministicSummary: String {
        var phrases = ["%@ with %@ wind".localized(locale: locale, formatArguments: [temperature, wind])]
        if let gust, hasSignificantGust { phrases.append("gusting to %@".localized(locale: locale, formatArguments: [gust])) }
        if hasRain { phrases.append("%@ of rain".localized(locale: locale, formatArguments: [rain])) }
        if let cloudCover, cloudCover >= 75 { phrases.append("mostly cloudy".localized(locale: locale)) }
        return phrases.joined(separator: ", ") + "."
    }

    private static func temperature(_ celsius: Double, unit: TemperatureUnit, locale: Locale) -> String {
        let value = Temperature(celsius: celsius).value(in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(0)).locale(locale)))\(unit.label)"
    }

    private static func wind(_ knots: Double, unit: WindSpeedUnit, locale: Locale) -> String {
        let value = Knots(knots).value(in: unit) ?? knots
        return "\(value.formatted(.number.precision(.fractionLength(0)).locale(locale))) \(unit.label)"
    }

    private static func precipitation(_ millimeters: Double, unit: PrecipitationUnit, locale: Locale) -> String {
        let value = Precipitation(millimeters: millimeters).value(in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(0)).locale(locale))) \(unit.label)"
    }
}

#Preview("Forecast intelligence") {
    if let forecast = ForecastWindguruMockup().dashboardPreviewForecast {
        ForecastIntelligenceSummary(forecast: forecast, hour: "29")
            .padding()
            .modifier(VentusThemeModifier(theme: .ocean))
    }
}
#endif
