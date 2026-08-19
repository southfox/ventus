//
//  ForecastIntelligenceText.swift
//  Forescoop package
//

import Foundation

public enum ForecastIntelligenceText {
    public static func summary(
        forecast: SpotForecast,
        hour: String?,
        coordinateLocationName: String? = nil,
        temperatureUnit: TemperatureUnit = DeviceForecastPreferences.temperatureUnit,
        windSpeedUnit: WindSpeedUnit = DeviceForecastPreferences.windSpeedUnit,
        precipitationUnit: PrecipitationUnit = DeviceForecastPreferences.precipitationUnit,
        freezingLevelUnit: FreezingLevelUnit = DeviceForecastPreferences.freezingLevelUnit,
        pressureUnit: PressureUnit = DeviceForecastPreferences.pressureUnit,
        locale: Locale = AppLanguageStore.currentLocale
    ) -> String {
        ForecastIntelligenceSnapshot(
            forecast: forecast,
            hour: hour,
            coordinateLocationName: coordinateLocationName,
            temperatureUnit: temperatureUnit,
            windSpeedUnit: windSpeedUnit,
            precipitationUnit: precipitationUnit,
            freezingLevelUnit: freezingLevelUnit,
            pressureUnit: pressureUnit,
            locale: locale
        ).deterministicSummary
    }
}

struct ForecastIntelligenceSnapshot: Hashable, Sendable {
    let locationName: String
    let hourLabel: String
    let temperature: String
    let isRealTemperature: Bool
    let wind: String
    let gust: String?
    let hasSignificantGust: Bool
    let rain: String
    let hasRain: Bool
    let humidity: Int?
    let cloudCover: Int?
    let freezingLevel: String?
    let pressure: String?
    let locale: Locale

    init(
        forecast: SpotForecast,
        hour: String?,
        coordinateLocationName: String?,
        temperatureUnit: TemperatureUnit,
        windSpeedUnit: WindSpeedUnit,
        precipitationUnit: PrecipitationUnit,
        freezingLevelUnit: FreezingLevelUnit,
        pressureUnit: PressureUnit,
        locale: Locale
    ) {
        let hour = hour ?? forecast.currentForecastHour ?? "0"
        let source = forecast.forecast
        self.locale = locale
        locationName = forecast.locationDisplayName(coordinateLocationName: coordinateLocationName)
        hourLabel = Self.hourLabel(for: hour, forecast: forecast, locale: locale)
        let realTemperatureCelsius = source?.temperatureReal(hh: hour)
        let temperatureCelsius = realTemperatureCelsius ?? source?.temperature(hh: hour) ?? 0
        isRealTemperature = realTemperatureCelsius != nil
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
        freezingLevel = source?.freezingLevelHeightInMeters(hh: hour).map {
            Self.freezingLevel($0, unit: freezingLevelUnit, locale: locale)
        }
        pressure = source?.seaLevelPressure(hh: hour).map {
            Self.pressure($0, unit: pressureUnit, locale: locale)
        }
    }

    var languageInstruction: String {
        let code = locale.language.languageCode?.identifier ?? "en"
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
        return "Respond in \(name)."
    }

    var prompt: String {
        "Location: \(locationName). Forecast time: \(hourLabel). Temperature: \(temperature) (\(isRealTemperature ? "real, altitude-corrected reading" : "raw model reading, no altitude correction available")). Wind: \(wind). Gusts: \(gust ?? "unavailable"). Rain: \(rain). Humidity: \(humidity.map(String.init) ?? "unavailable")%. Cloud cover: \(cloudCover.map(String.init) ?? "unavailable")%. Freezing level: \(freezingLevel ?? "unavailable"). Pressure: \(pressure ?? "unavailable")."
    }

    var deterministicSummary: String {
        var phrases = ["%@ with %@ wind".localized(locale: locale, formatArguments: [temperature, wind])]
        phrases.append(isRealTemperature
            ? "real, altitude-corrected reading".localized(locale: locale)
            : "model reading, no altitude correction available".localized(locale: locale))
        if let gust, hasSignificantGust { phrases.append("gusting to %@".localized(locale: locale, formatArguments: [gust])) }
        if let cloudCover { phrases.append("%@ cloud cover".localized(locale: locale, formatArguments: ["\(cloudCover)%"])) }
        if let humidity { phrases.append("%@ humidity".localized(locale: locale, formatArguments: ["\(humidity)%"])) }
        if hasRain { phrases.append("%@ of rain".localized(locale: locale, formatArguments: [rain])) }
        if let freezingLevel { phrases.append("freezing level at %@".localized(locale: locale, formatArguments: [freezingLevel])) }
        if let pressure { phrases.append("pressure %@".localized(locale: locale, formatArguments: [pressure])) }
        let body = phrases.joined(separator: ", ") + "."
        return "%@ · %@: %@".localized(locale: locale, formatArguments: [locationName, hourLabel, body])
    }

    private static func hourLabel(for hour: String, forecast: SpotForecast, locale: Locale) -> String {
        guard let date = forecast.forecastDate(hour: hour) else {
            return String(format: "%02d:00", (Int(hour) ?? 0) % 24)
        }
        let calendar = Calendar.current
        let day = calendar.isDateInToday(date)
            ? "today".localized(locale: locale)
            : date.formatted(.dateTime.weekday(.abbreviated).day().locale(locale))
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("j")
        return "\(day), \(formatter.string(from: date))"
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

    private static func freezingLevel(_ meters: Double, unit: FreezingLevelUnit, locale: Locale) -> String {
        let value = FreezingLevel(meters: meters).value(in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(0)).locale(locale))) \(unit.label)"
    }

    private static func pressure(_ hectopascals: Double, unit: PressureUnit, locale: Locale) -> String {
        let value = AtmosphericPressure(hectopascals: hectopascals).value(in: unit)
        let precision = unit == .inchesOfMercury ? 2 : 0
        return "\(value.formatted(.number.precision(.fractionLength(precision)).locale(locale))) \(unit.label)"
    }
}
