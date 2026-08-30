//
//  ForecastMoonInfo.swift
//  Ventus
//

import AstronomyKit
import Foundation

/// Shared, default-on preference for optional lunar data. It intentionally
/// lives outside a view so every platform can avoid AstronomyKit work when
/// the feature is disabled.
enum ForecastMoonPreference {
    private static let key = "forecastMoonPhasesEnabled"

    static var isEnabled: Bool {
        defaults().object(forKey: key) as? Bool ?? true
    }

    static func save(_ isEnabled: Bool) {
        defaults().set(isEnabled, forKey: key)
    }

    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: "group.org.forescoop.shared") ?? .standard
    }
}

/// Lunar information calculated on-device for a forecast location and local day.
public struct ForecastMoonInfo: Sendable {
    public let day: Date
    public let phaseName: String
    public let illumination: Double
    public let symbolName: String
    public let moonrise: Date?
    public let moonset: Date?

    public var illuminationText: String { "\(Int((illumination * 100).rounded()))%" }
}

/// A small, process-local cache avoids repeating the relatively expensive
/// rise/set search while dashboard, grid and graph render the same forecast.
enum ForecastMoonCalendar {
    private final class Box: NSObject {
        let value: ForecastMoonInfo
        init(_ value: ForecastMoonInfo) { self.value = value }
    }

    nonisolated(unsafe) private static let cache = NSCache<NSString, Box>()

    static func info(for forecast: SpotForecast, on date: Date) -> ForecastMoonInfo? {
        guard ForecastMoonPreference.isEnabled,
              (-90...90).contains(forecast.latitude), (-180...180).contains(forecast.longitude),
              forecast.latitude != 0 || forecast.longitude != 0 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = forecast.timezone ?? TimeZone(secondsFromGMT: forecast.gmtHourOffset * 3_600) ?? .current
        let day = calendar.startOfDay(for: date)
        // Phase names are localized, so an English value cached while a widget
        // renders must not be reused by a Spanish dashboard (or vice versa).
        let key = "\(forecast.latitude.rounded(toPlaces: 3)),\(forecast.longitude.rounded(toPlaces: 3)),\(day.timeIntervalSince1970),\(AppLanguageStore.currentLocale.identifier)" as NSString
        if let cached = cache.object(forKey: key) { return cached.value }

        do {
            let observer = Observer(latitude: forecast.latitude, longitude: forecast.longitude, height: Double(forecast.altitude))
            let phaseAngle = try Moon.phaseAngle(at: AstroTime(day))
            let moonrise = try CelestialBody.moon.riseTime(after: AstroTime(day), from: observer, limitDays: 2)?.date
            let moonset = try CelestialBody.moon.setTime(after: AstroTime(day), from: observer, limitDays: 2)?.date
            let info = ForecastMoonInfo(
                day: day,
                phaseName: localizedPhaseName(Moon.phaseName(for: phaseAngle)),
                illumination: Moon.illumination(for: phaseAngle),
                symbolName: phaseSymbol(for: phaseAngle),
                moonrise: event(on: day, candidate: moonrise, calendar: calendar),
                moonset: event(on: day, candidate: moonset, calendar: calendar)
            )
            cache.setObject(Box(info), forKey: key)
            return info
        } catch {
            return nil
        }
    }

    static func events(for forecast: SpotForecast, from start: Date, until end: Date) -> [(date: Date, symbolName: String)] {
        guard ForecastMoonPreference.isEnabled, start < end else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = forecast.timezone ?? TimeZone(secondsFromGMT: forecast.gmtHourOffset * 3_600) ?? .current
        var day = calendar.startOfDay(for: start)
        var events = [(date: Date, symbolName: String)]()
        while day < end {
            if let info = info(for: forecast, on: day) {
                if let moonrise = info.moonrise, start <= moonrise, moonrise < end { events.append((moonrise, "moonrise.fill")) }
                if let moonset = info.moonset, start <= moonset, moonset < end { events.append((moonset, "moonset.fill")) }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return events.sorted { $0.date < $1.date }
    }

    private static func event(on day: Date, candidate: Date?, calendar: Calendar) -> Date? {
        guard let candidate, calendar.isDate(candidate, inSameDayAs: day) else { return nil }
        return candidate
    }

    private static func localizedPhaseName(_ phaseName: String) -> String {
        // AstronomyKit supplies these names dynamically. SwiftUI's string
        // catalog only resolves compile-time keys, so retain the small,
        // canonical phase table here and choose it from Ventus's language
        // preference rather than displaying AstronomyKit's English text.
        let languageCode = AppLanguageStore.currentLocale.language.languageCode?.identifier
        switch languageCode {
        case "es":
            return [
                "New Moon": "Luna nueva",
                "Waxing Crescent": "Luna creciente",
                "First Quarter": "Cuarto creciente",
                "Waxing Gibbous": "Gibosa creciente",
                "Full Moon": "Luna llena",
                "Waning Gibbous": "Gibosa menguante",
                "Third Quarter": "Cuarto menguante",
                "Waning Crescent": "Luna menguante"
            ][phaseName] ?? phaseName
        case "de":
            return [
                "New Moon": "Neumond",
                "Waxing Crescent": "Zunehmende Sichel",
                "First Quarter": "Erstes Viertel",
                "Waxing Gibbous": "Zunehmender Dreiviertelmond",
                "Full Moon": "Vollmond",
                "Waning Gibbous": "Abnehmender Dreiviertelmond",
                "Third Quarter": "Letztes Viertel",
                "Waning Crescent": "Abnehmende Sichel"
            ][phaseName] ?? phaseName
        case "fr":
            return [
                "New Moon": "Nouvelle lune",
                "Waxing Crescent": "Premier croissant",
                "First Quarter": "Premier quartier",
                "Waxing Gibbous": "Lune gibbeuse croissante",
                "Full Moon": "Pleine lune",
                "Waning Gibbous": "Lune gibbeuse décroissante",
                "Third Quarter": "Dernier quartier",
                "Waning Crescent": "Dernier croissant"
            ][phaseName] ?? phaseName
        case "pt":
            return [
                "New Moon": "Lua nova",
                "Waxing Crescent": "Lua crescente",
                "First Quarter": "Quarto crescente",
                "Waxing Gibbous": "Lua gibosa crescente",
                "Full Moon": "Lua cheia",
                "Waning Gibbous": "Lua gibosa minguante",
                "Third Quarter": "Quarto minguante",
                "Waning Crescent": "Lua minguante"
            ][phaseName] ?? phaseName
        default:
            return phaseName
        }
    }

    private static func phaseSymbol(for angle: Double) -> String {
        switch angle.truncatingRemainder(dividingBy: 360) {
        case 0..<22.5, 337.5..<360: "moonphase.new.moon"
        case 22.5..<67.5: "moonphase.waxing.crescent"
        case 67.5..<112.5: "moonphase.first.quarter"
        case 112.5..<157.5: "moonphase.waxing.gibbous"
        case 157.5..<202.5: "moonphase.full.moon"
        case 202.5..<247.5: "moonphase.waning.gibbous"
        case 247.5..<292.5: "moonphase.last.quarter"
        default: "moonphase.waning.crescent"
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
