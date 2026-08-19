//
//  ForecastIntelligenceText.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/01/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit
#endif

public enum ForecastInsightDetail: Sendable {
    case brief
    case compact
    case extended

    var maxWords: Int {
        switch self {
        case .brief: 25
        case .compact: 100
        case .extended: 2_000
        }
    }

    public static var deviceDefault: ForecastInsightDetail {
#if os(watchOS)
        .brief
#elseif os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? .compact : .extended
#else
        .extended
#endif
    }
}

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
    let windOutlook: String?
    let temperatureOutlook: String?
    let precipitationOutlook: String?
    let dailyOutlook: String?

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

        let currentOffset = Int(hour) ?? 0
        let futureHours = forecast.availableForecastHours
            .compactMap { rawHour -> (hour: String, offset: Int)? in Int(rawHour).map { (rawHour, $0) } }
            .filter { $0.offset >= currentOffset }
            .sorted { $0.offset < $1.offset }
        let nextDay = futureHours.filter { $0.offset <= currentOffset + 24 }
        let nextTwoDays = futureHours.filter { $0.offset <= currentOffset + 48 }

        windOutlook = Self.windOutlook(nextDay, forecast: forecast, unit: windSpeedUnit, locale: locale)
        temperatureOutlook = Self.temperatureOutlook(nextTwoDays, forecast: forecast, unit: temperatureUnit, locale: locale)
        precipitationOutlook = Self.precipitationOutlook(nextDay, forecast: forecast, unit: precipitationUnit, locale: locale)
        dailyOutlook = Self.dailyOutlook(futureHours, forecast: forecast, temperatureUnit: temperatureUnit, locale: locale)
    }

    var languageInstruction: String {
        let code = locale.language.languageCode?.identifier ?? "en"
        let name = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
        return "Respond in \(name)."
    }

    var prompt: String {
        var facts = [
            "Location: \(locationName).",
            "Forecast time: \(hourLabel).",
            "Temperature: \(temperature) (\(isRealTemperature ? "real, altitude-corrected reading" : "raw model reading, no altitude correction available")).",
            "Wind: \(wind).",
            "Gusts: \(gust ?? "unavailable").",
            "Rain: \(rain).",
            "Humidity: \(humidity.map(String.init) ?? "unavailable")%.",
            "Cloud cover: \(cloudCover.map(String.init) ?? "unavailable")%.",
            "Freezing level: \(freezingLevel ?? "unavailable").",
            "Pressure: \(pressure ?? "unavailable")."
        ]
        if let windOutlook { facts.append("Wind outlook for the next day: \(windOutlook).") }
        if let temperatureOutlook { facts.append("Temperature outlook for the next two days: \(temperatureOutlook).") }
        if let precipitationOutlook { facts.append("Precipitation outlook for the next day: \(precipitationOutlook).") }
        if let dailyOutlook { facts.append("Multi-day outlook: \(dailyOutlook).") }
        return facts.joined(separator: " ")
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
        if let windOutlook { phrases.append(windOutlook) }
        if let temperatureOutlook { phrases.append(temperatureOutlook) }
        if let precipitationOutlook { phrases.append(precipitationOutlook) }
        let body = phrases.joined(separator: ", ") + "."
        return "%@ · %@: %@".localized(locale: locale, formatArguments: [locationName, hourLabel, body])
    }

    private static func windOutlook(
        _ hours: [(hour: String, offset: Int)],
        forecast: SpotForecast,
        unit: WindSpeedUnit,
        locale: Locale
    ) -> String? {
        guard let source = forecast.forecast else { return nil }
        var peakBeaufort = 0
        var peakKnots = 0.0
        var peakHour: String?
        for item in hours {
            let windKnots = source.windSpeed(hh: item.hour) ?? 0
            let gustKnots = source.windGustsKnots(hh: item.hour) ?? 0
            let beaufort = max(Knots(windKnots).bft ?? 0, Knots(gustKnots).bft ?? 0)
            let strongest = max(windKnots, gustKnots)
            guard beaufort > peakBeaufort || (beaufort == peakBeaufort && strongest > peakKnots) else { continue }
            peakBeaufort = beaufort
            peakKnots = strongest
            peakHour = item.hour
        }
        guard peakBeaufort >= SpotForecast.strongWindBeaufortThreshold, let peakHour else { return nil }
        let label = hourLabel(for: peakHour, forecast: forecast, locale: locale)
        return "strong wind expected, up to \(wind(peakKnots, unit: unit, locale: locale)) (Beaufort \(peakBeaufort)) around \(label)"
    }

    /// Flags an unusually cold or hot reading in `hours`, and when.
    private static func temperatureOutlook(
        _ hours: [(hour: String, offset: Int)],
        forecast: SpotForecast,
        unit: TemperatureUnit,
        locale: Locale
    ) -> String? {
        guard let source = forecast.forecast else { return nil }
        var coldest: (celsius: Double, hour: String)?
        var hottest: (celsius: Double, hour: String)?
        for item in hours {
            guard let celsius = source.temperatureReal(hh: item.hour) ?? source.temperature(hh: item.hour) else { continue }
            if coldest == nil || celsius < coldest!.celsius { coldest = (celsius, item.hour) }
            if hottest == nil || celsius > hottest!.celsius { hottest = (celsius, item.hour) }
        }
        if let coldest, coldest.celsius <= -5 {
            let label = hourLabel(for: coldest.hour, forecast: forecast, locale: locale)
            return "very cold, dropping to \(temperature(coldest.celsius, unit: unit, locale: locale)) around \(label)"
        }
        if let hottest, hottest.celsius >= 32 {
            let label = hourLabel(for: hottest.hour, forecast: forecast, locale: locale)
            return "very hot, reaching \(temperature(hottest.celsius, unit: unit, locale: locale)) around \(label)"
        }
        return nil
    }

    private static func precipitationOutlook(
        _ hours: [(hour: String, offset: Int)],
        forecast: SpotForecast,
        unit: PrecipitationUnit,
        locale: Locale
    ) -> String? {
        guard let source = forecast.forecast else { return nil }
        var total = 0.0
        var isSnow = false
        var onsetHour: String?
        for item in hours {
            let amount = source.precipitation1(hh: item.hour) ?? source.precipitation(hh: item.hour) ?? 0
            guard amount > 0 else { continue }
            total += amount
            if onsetHour == nil { onsetHour = item.hour }
            let celsius = source.temperatureReal(hh: item.hour) ?? source.temperature(hh: item.hour) ?? 0
            if celsius <= 0 { isSnow = true }
        }
        guard total > 0 else { return nil }
        let amountText = precipitation(total, unit: unit, locale: locale)
        let kind = isSnow ? "snow" : "rain"
        guard let onsetHour else { return "\(amountText) of \(kind) expected" }
        let label = hourLabel(for: onsetHour, forecast: forecast, locale: locale)
        return "\(amountText) of \(kind) expected, starting around \(label)"
    }

    private static func dailyOutlook(
        _ hours: [(hour: String, offset: Int)],
        forecast: SpotForecast,
        temperatureUnit: TemperatureUnit,
        locale: Locale
    ) -> String? {
        guard let source = forecast.forecast else { return nil }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: hours) { item in
            calendar.startOfDay(for: forecast.forecastDate(hour: item.hour) ?? Date())
        }
        let days = grouped.keys.sorted().prefix(6)
        guard days.count > 1 else { return nil }

        let lines: [String] = days.compactMap { day in
            guard let dayHours = grouped[day], !dayHours.isEmpty else { return nil }
            let temps = dayHours.compactMap { source.temperatureReal(hh: $0.hour) ?? source.temperature(hh: $0.hour) }
            guard let low = temps.min(), let high = temps.max() else { return nil }
            let representativeHour = dayHours.sorted { $0.offset < $1.offset }[dayHours.count / 2].hour
            let condition = conditionWord(for: forecast, hour: representativeHour)
            let dayLabel = calendar.isDateInToday(day)
                ? "today".localized(locale: locale)
                : day.formatted(.dateTime.weekday(.abbreviated).locale(locale))
            let lowText = temperature(low, unit: temperatureUnit, locale: locale)
            let highText = temperature(high, unit: temperatureUnit, locale: locale)
            return "\(dayLabel) \(lowText)–\(highText) \(condition)"
        }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: ", ")
    }

    private static func conditionWord(for forecast: SpotForecast, hour: String) -> String {
        let symbols = forecast.weatherSymbolNames(hour: hour)
        if symbols.contains(where: { $0.contains("snow") }) { return "snow" }
        if symbols.contains(where: { $0.contains("rain") || $0.contains("drizzle") }) { return "rain" }
        if symbols.contains(where: { $0.contains("fog") }) { return "fog" }
        if symbols.contains("cloud.fill") { return "overcast" }
        if symbols.contains(where: { $0.hasPrefix("cloud.sun") || $0.hasPrefix("cloud.moon") }) { return "partly cloudy" }
        if symbols.contains("cloud") { return "cloudy" }
        return "clear"
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
