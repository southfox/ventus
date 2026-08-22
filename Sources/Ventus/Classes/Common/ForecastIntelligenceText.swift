//
//  ForecastIntelligenceText.swift
//  Ventus package
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
        case .brief: 250
        case .compact: 1_000
        case .extended: 20_000
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
        waveHeightUnit: WaveHeightUnit = DeviceForecastPreferences.waveHeightUnit,
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
            waveHeightUnit: waveHeightUnit,
            locale: locale
        ).deterministicSummary
    }

    public static func detailedSummary(
        forecast: SpotForecast,
        hour: String?,
        coordinateLocationName: String? = nil,
        temperatureUnit: TemperatureUnit = DeviceForecastPreferences.temperatureUnit,
        windSpeedUnit: WindSpeedUnit = DeviceForecastPreferences.windSpeedUnit,
        precipitationUnit: PrecipitationUnit = DeviceForecastPreferences.precipitationUnit,
        freezingLevelUnit: FreezingLevelUnit = DeviceForecastPreferences.freezingLevelUnit,
        pressureUnit: PressureUnit = DeviceForecastPreferences.pressureUnit,
        waveHeightUnit: WaveHeightUnit = DeviceForecastPreferences.waveHeightUnit,
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
            waveHeightUnit: waveHeightUnit,
            locale: locale
        ).structuredOverview
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
    let waveHeight: String?
    let locale: Locale
    let windOutlook: String?
    let temperatureOutlook: String?
    let precipitationOutlook: String?
    let waveOutlook: String?
    let dailyOutlook: String?
    let structuredOverview: String

    init(
        forecast: SpotForecast,
        hour: String?,
        coordinateLocationName: String?,
        temperatureUnit: TemperatureUnit,
        windSpeedUnit: WindSpeedUnit,
        precipitationUnit: PrecipitationUnit,
        freezingLevelUnit: FreezingLevelUnit,
        pressureUnit: PressureUnit,
        waveHeightUnit: WaveHeightUnit,
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
        waveHeight = source?.waveHeight(hh: hour).map {
            Self.waveHeight($0, unit: waveHeightUnit, locale: locale)
        }

        let currentOffset = Int(hour) ?? 0
        let futureHours = forecast.availableForecastHours
            .compactMap { rawHour -> (hour: String, offset: Int)? in Int(rawHour).map { (rawHour, $0) } }
            .filter { $0.offset >= currentOffset }
            .sorted { $0.offset < $1.offset }
        let nextDay = futureHours.filter { $0.offset <= currentOffset + 24 }
        let nextTwoDays = futureHours.filter { $0.offset <= currentOffset + 48 }

        let windOutlook = Self.windOutlook(nextDay, forecast: forecast, unit: windSpeedUnit, locale: locale)
        let temperatureOutlook = Self.temperatureOutlook(nextTwoDays, forecast: forecast, unit: temperatureUnit, locale: locale)
        let precipitationOutlook = Self.precipitationOutlook(nextDay, forecast: forecast, unit: precipitationUnit, locale: locale)
        let waveOutlook = Self.waveOutlook(nextTwoDays, forecast: forecast, unit: waveHeightUnit, locale: locale)
        let days = Self.dayDetails(futureHours, forecast: forecast, locale: locale)
        self.windOutlook = windOutlook
        self.temperatureOutlook = temperatureOutlook
        self.precipitationOutlook = precipitationOutlook
        self.waveOutlook = waveOutlook
        dailyOutlook = Self.dailyOutlook(days, temperatureUnit: temperatureUnit, locale: locale)
        structuredOverview = Self.structuredOverview(
            hourLabel: hourLabel,
            currentTemperature: temperature,
            wind: wind,
            gust: gust,
            hasSignificantGust: hasSignificantGust,
            rain: rain,
            hasRain: hasRain,
            humidity: humidity,
            cloudCover: cloudCover,
            freezingLevel: freezingLevel,
            pressure: pressure,
            waveHeight: waveHeight,
            windOutlook: windOutlook,
            precipitationOutlook: precipitationOutlook,
            waveOutlook: waveOutlook,
            days: days,
            temperatureUnit: temperatureUnit,
            locale: locale
        )
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
        if let waveHeight { facts.append("Wave height: \(waveHeight).") }
        if let windOutlook { facts.append("Wind outlook for the next day: \(windOutlook).") }
        if let temperatureOutlook { facts.append("Temperature outlook for the next two days: \(temperatureOutlook).") }
        if let precipitationOutlook { facts.append("Precipitation outlook for the next day: \(precipitationOutlook).") }
        if let waveOutlook { facts.append("Wave outlook for the next two days: \(waveOutlook).") }
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
        if let waveHeight { phrases.append("%@ waves".localized(locale: locale, formatArguments: [waveHeight])) }
        if let windOutlook { phrases.append(windOutlook) }
        if let temperatureOutlook { phrases.append(temperatureOutlook) }
        if let precipitationOutlook { phrases.append(precipitationOutlook) }
        if let waveOutlook { phrases.append(waveOutlook) }
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
        return "strong wind expected, up to %@ (Beaufort %@) around %@".localized(
            locale: locale,
            formatArguments: [wind(peakKnots, unit: unit, locale: locale), "\(peakBeaufort)", label]
        )
    }

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
            return "very cold, dropping to %@ around %@".localized(
                locale: locale,
                formatArguments: [temperature(coldest.celsius, unit: unit, locale: locale), label]
            )
        }
        if let hottest, hottest.celsius >= 32 {
            let label = hourLabel(for: hottest.hour, forecast: forecast, locale: locale)
            return "very hot, reaching %@ around %@".localized(
                locale: locale,
                formatArguments: [temperature(hottest.celsius, unit: unit, locale: locale), label]
            )
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
        var hasLocallyHeavyRisk = false
        for item in hours {
            let amount = source.precipitation1(hh: item.hour) ?? source.precipitation(hh: item.hour) ?? 0
            if let ceiling = source.precipitationCeiling(hh: item.hour), ceiling - amount >= 1 {
                hasLocallyHeavyRisk = true
            }
            guard amount > 0 else { continue }
            total += amount
            if onsetHour == nil { onsetHour = item.hour }
            let celsius = source.temperatureReal(hh: item.hour) ?? source.temperature(hh: item.hour) ?? 0
            if celsius <= 0 { isSnow = true }
        }
        guard total > 0 else { return nil }
        let amountText = precipitation(total, unit: unit, locale: locale)
        let kind = (isSnow ? "snow" : "rain").localized(locale: locale)
        let base: String
        if let onsetHour {
            let label = hourLabel(for: onsetHour, forecast: forecast, locale: locale)
            base = "%@ of %@ expected, starting around %@".localized(locale: locale, formatArguments: [amountText, kind, label])
        } else {
            base = "%@ of %@ expected".localized(locale: locale, formatArguments: [amountText, kind])
        }
        guard hasLocallyHeavyRisk else { return base }
        return "\(base) \("Showers may be locally heavy.".localized(locale: locale))"
    }

    private static func waveOutlook(
        _ hours: [(hour: String, offset: Int)],
        forecast: SpotForecast,
        unit: WaveHeightUnit,
        locale: Locale
    ) -> String? {
        guard let source = forecast.forecast else { return nil }
        var peakMeters = 0.0
        var peakHour: String?
        for item in hours {
            guard let meters = source.waveHeight(hh: item.hour), meters > peakMeters else { continue }
            peakMeters = meters
            peakHour = item.hour
        }
        guard peakMeters >= 2.5, let peakHour else { return nil }
        let label = hourLabel(for: peakHour, forecast: forecast, locale: locale)
        return "large swell expected, up to %@ around %@".localized(
            locale: locale,
            formatArguments: [waveHeight(peakMeters, unit: unit, locale: locale), label]
        )
    }

    private struct DayDetail {
        let label: String
        let lowCelsius: Double
        let highCelsius: Double
        let precipitationMillimeters: Double
        let isSnow: Bool
        let peakBeaufort: Int
        let condition: String
    }

    private static func dayDetails(
        _ hours: [(hour: String, offset: Int)],
        forecast: SpotForecast,
        locale: Locale
    ) -> [DayDetail] {
        guard let source = forecast.forecast else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: hours) { item in
            calendar.startOfDay(for: forecast.forecastDate(hour: item.hour) ?? Date())
        }
        let days = grouped.keys.sorted().prefix(10)

        return days.compactMap { day -> DayDetail? in
            guard let dayHours = grouped[day], !dayHours.isEmpty else { return nil }
            let temps = dayHours.compactMap { source.temperatureReal(hh: $0.hour) ?? source.temperature(hh: $0.hour) }
            guard let low = temps.min(), let high = temps.max() else { return nil }

            var precipitationTotal = 0.0
            var isSnowDay = false
            var peakBeaufort = 0
            for item in dayHours {
                let amount = source.precipitation1(hh: item.hour) ?? source.precipitation(hh: item.hour) ?? 0
                precipitationTotal += amount
                if amount > 0, let celsius = source.temperatureReal(hh: item.hour) ?? source.temperature(hh: item.hour), celsius <= 0 {
                    isSnowDay = true
                }
                let windKnots = source.windSpeed(hh: item.hour) ?? 0
                let gustKnots = source.windGustsKnots(hh: item.hour) ?? 0
                peakBeaufort = max(peakBeaufort, Knots(windKnots).bft ?? 0, Knots(gustKnots).bft ?? 0)
            }

            let representativeHour = dayHours.sorted { $0.offset < $1.offset }[dayHours.count / 2].hour
            let condition = conditionWord(for: forecast, hour: representativeHour, locale: locale)
            let label = calendar.isDateInToday(day)
                ? "today".localized(locale: locale)
                : day.formatted(.dateTime.weekday(.abbreviated).locale(locale))

            return DayDetail(
                label: label,
                lowCelsius: low,
                highCelsius: high,
                precipitationMillimeters: precipitationTotal,
                isSnow: isSnowDay,
                peakBeaufort: peakBeaufort,
                condition: condition
            )
        }
    }

    private static func dailyOutlook(_ days: [DayDetail], temperatureUnit: TemperatureUnit, locale: Locale) -> String? {
        guard days.count > 1 else { return nil }
        let lines = days.map { day in
            "%@ %@–%@ %@".localized(
                locale: locale,
                formatArguments: [
                    day.label,
                    temperature(day.lowCelsius, unit: temperatureUnit, locale: locale),
                    temperature(day.highCelsius, unit: temperatureUnit, locale: locale),
                    day.condition
                ]
            )
        }
        return lines.joined(separator: ", ")
    }

    private static func structuredOverview(
        hourLabel: String,
        currentTemperature: String,
        wind: String,
        gust: String?,
        hasSignificantGust: Bool,
        rain: String,
        hasRain: Bool,
        humidity: Int?,
        cloudCover: Int?,
        freezingLevel: String?,
        pressure: String?,
        waveHeight: String?,
        windOutlook: String?,
        precipitationOutlook: String?,
        waveOutlook: String?,
        days: [DayDetail],
        temperatureUnit: TemperatureUnit,
        locale: Locale
    ) -> String {
        var openingPhrases = ["%@ with %@ wind".localized(locale: locale, formatArguments: [currentTemperature, wind])]
        if hasSignificantGust, let gust { openingPhrases.append("gusting to %@".localized(locale: locale, formatArguments: [gust])) }
        if hasRain { openingPhrases.append("%@ of rain".localized(locale: locale, formatArguments: [rain])) }
        if let cloudCover { openingPhrases.append("%@ cloud cover".localized(locale: locale, formatArguments: ["\(cloudCover)%"])) }
        if let humidity { openingPhrases.append("%@ humidity".localized(locale: locale, formatArguments: ["\(humidity)%"])) }
        if let freezingLevel { openingPhrases.append("freezing level at %@".localized(locale: locale, formatArguments: [freezingLevel])) }
        if let pressure { openingPhrases.append("pressure %@".localized(locale: locale, formatArguments: [pressure])) }
        if let waveHeight { openingPhrases.append("%@ waves".localized(locale: locale, formatArguments: [waveHeight])) }
        let openingBody = openingPhrases.joined(separator: ", ")
        let opening = "For %@, expect %@.".localized(locale: locale, formatArguments: [hourLabel, openingBody])

        guard !days.isEmpty else { return opening }

        let precipitationDays = days.filter { $0.precipitationMillimeters > 0 }
        let hasUnsettledPattern = precipitationDays.count >= max(3, days.count / 2)
        let coldestDay = days.min { $0.lowCelsius < $1.lowCelsius }
        let hottestDay = days.max { $0.highCelsius < $1.highCelsius }
        let iceRiskDay = days.indices.dropLast().first { index in
            days[index].precipitationMillimeters > 0 && days[index + 1].lowCelsius <= 0
        }.map { days[$0 + 1] }

        var points: [(title: String, body: String)] = []

        if let windOutlook {
            let capitalized = windOutlook.prefix(1).uppercased() + windOutlook.dropFirst()
            let chillNote = "Winds at that strength can make it feel noticeably colder than the air temperature alone suggests.".localized(locale: locale)
            points.append(("Wind & Chill".localized(locale: locale), "\(capitalized). \(chillNote)"))
        }

        if let waveOutlook {
            let capitalized = waveOutlook.prefix(1).uppercased() + waveOutlook.dropFirst()
            points.append(("Sea & Swell".localized(locale: locale), "\(capitalized)."))
        }

        if let iceRiskDay {
            let body = "Wet surfaces from rain, combined with a low of %@ around %@, can refreeze into ice on exposed paths and roads overnight.".localized(
                locale: locale,
                formatArguments: [temperature(iceRiskDay.lowCelsius, unit: temperatureUnit, locale: locale), iceRiskDay.label]
            )
            points.append(("Ice Hazard".localized(locale: locale), body))
        }

        if hasUnsettledPattern {
            let kind = (precipitationDays.contains { $0.isSnow } ? "rain or snow" : "rain").localized(locale: locale)
            let body = "%@ of the next %@ days bring %@, so expect a wet, changeable stretch rather than a single passing system.".localized(
                locale: locale,
                formatArguments: ["\(precipitationDays.count)", "\(days.count)", kind]
            )
            points.append(("Unsettled Outlook".localized(locale: locale), body))
        } else if let precipitationOutlook {
            let capitalized = precipitationOutlook.prefix(1).uppercased() + precipitationOutlook.dropFirst()
            points.append(("Precipitation".localized(locale: locale), "\(capitalized)."))
        }

        if let coldestDay, coldestDay.lowCelsius <= -5 {
            let body = "Overnight lows drop to around %@ on %@ — dress for a sharp chill after dark.".localized(
                locale: locale,
                formatArguments: [temperature(coldestDay.lowCelsius, unit: temperatureUnit, locale: locale), coldestDay.label]
            )
            points.append(("Cold Snap".localized(locale: locale), body))
        }

        if let hottestDay, hottestDay.highCelsius >= 32 {
            let body = "Highs climb to around %@ on %@, well above the rest of the outlook.".localized(
                locale: locale,
                formatArguments: [temperature(hottestDay.highCelsius, unit: temperatureUnit, locale: locale), hottestDay.label]
            )
            points.append(("Heat".localized(locale: locale), body))
        }

        guard !points.isEmpty else {
            if let outlook = dailyOutlook(days, temperatureUnit: temperatureUnit, locale: locale) {
                let quiet = "No notable hazards ahead — a generally quiet stretch: %@.".localized(locale: locale, formatArguments: [outlook])
                return "\(opening)\n\n\(quiet)"
            }
            return opening
        }

        let section = points
            .map { "**\($0.title):** \($0.body)" }
            .joined(separator: "\n\n")
        let sectionTitle = "Key Trends & Impact".localized(locale: locale)
        let result = "\(opening)\n\n**\(sectionTitle)**\n\n\(section)"

        return result
    }

    private static func conditionWord(for forecast: SpotForecast, hour: String, locale: Locale) -> String {
        let symbols = forecast.weatherSymbolNames(hour: hour)
        let word: String
        if symbols.contains(where: { $0.contains("snow") }) { word = "snow" }
        else if symbols.contains(where: { $0.contains("rain") || $0.contains("drizzle") }) { word = "rain" }
        else if symbols.contains(where: { $0.contains("fog") }) { word = "fog" }
        else if symbols.contains("cloud.fill") { word = "overcast" }
        else if symbols.contains(where: { $0.hasPrefix("cloud.sun") || $0.hasPrefix("cloud.moon") }) { word = "partly cloudy" }
        else if symbols.contains("cloud") { word = "cloudy" }
        else { word = "clear" }
        return word.localized(locale: locale)
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
        formatter.setLocalizedDateFormatFromTemplate("jm")
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

    private static func waveHeight(_ meters: Double, unit: WaveHeightUnit, locale: Locale) -> String {
        let value = WaveHeight(meters: meters).value(in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(1)).locale(locale))) \(unit.label)"
    }
}
