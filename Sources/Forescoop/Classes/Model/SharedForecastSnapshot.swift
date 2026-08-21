//
//  SharedForecastSnapshot.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/15/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct SharedForecastSnapshot: Codable, Sendable {
    public struct Hour: Codable, Sendable {
        public let label: String
        public let symbolName: String
        public let temperature: String

        public init(label: String, symbolName: String, temperature: String) {
            self.label = label
            self.symbolName = symbolName
            self.temperature = temperature
        }
    }

    public struct Day: Codable, Sendable {
        public let label: String
        public let symbolName: String
        public let low: String
        public let high: String
        public let lowValue: Double
        public let highValue: Double

        public init(label: String, symbolName: String, low: String, high: String, lowValue: Double, highValue: Double) {
            self.label = label
            self.symbolName = symbolName
            self.low = low
            self.high = high
            self.lowValue = lowValue
            self.highValue = highValue
        }
    }

    public let date: Date
    public let locationName: String
    public let temperature: String
    public let temperatureCelsius: Double
    public let rawTemperature: String
    public let rawTemperatureCelsius: Double
    public let realTemperature: String
    public let realTemperatureCelsius: Double
    public let wind: String
    public let gust: String
    public let windDirection: String
    public let windDirectionDegrees: Double
    public let rain: String
    public let humidity: String
    public let cloudCover: String
    public let pressure: String
    public let wave: String?
    public let symbolName: String
    public let condition: String
    public let high: String
    public let highCelsius: Double
    public let low: String
    public let lowCelsius: Double
    public let insight: String
    public let hourly: [Hour]
    public let daily: [Day]

    public init(
        date: Date,
        locationName: String,
        temperature: String,
        temperatureCelsius: Double,
        rawTemperature: String,
        rawTemperatureCelsius: Double,
        realTemperature: String,
        realTemperatureCelsius: Double,
        wind: String,
        gust: String,
        windDirection: String,
        windDirectionDegrees: Double,
        rain: String,
        humidity: String,
        cloudCover: String,
        pressure: String,
        wave: String? = nil,
        symbolName: String,
        condition: String,
        high: String,
        highCelsius: Double,
        low: String,
        lowCelsius: Double,
        insight: String,
        hourly: [Hour],
        daily: [Day]
    ) {
        self.date = date
        self.locationName = locationName
        self.temperature = temperature
        self.temperatureCelsius = temperatureCelsius
        self.rawTemperature = rawTemperature
        self.rawTemperatureCelsius = rawTemperatureCelsius
        self.realTemperature = realTemperature
        self.realTemperatureCelsius = realTemperatureCelsius
        self.wind = wind
        self.gust = gust
        self.windDirection = windDirection
        self.windDirectionDegrees = windDirectionDegrees
        self.rain = rain
        self.humidity = humidity
        self.cloudCover = cloudCover
        self.pressure = pressure
        self.wave = wave
        self.symbolName = symbolName
        self.condition = condition
        self.high = high
        self.highCelsius = highCelsius
        self.low = low
        self.lowCelsius = lowCelsius
        self.insight = insight
        self.hourly = hourly
        self.daily = daily
    }
}

public extension SharedForecastSnapshot {
    static func make(from forecast: SpotForecast, units: ForecastUnitPreferences, gridHourStepStore: GridHourStepStoring) -> SharedForecastSnapshot {
        let hour = forecast.currentForecastHour
        let temperature = forecast.forecast?.temperature(hh: hour) ?? forecast.forecast?.temperatureReal(hh: hour) ?? 0
        let rawTemperature = forecast.forecast?.temperature(hh: hour)
        let realTemperature = forecast.forecast?.temperatureReal(hh: hour)
        let wind = forecast.forecast?.windSpeed(hh: hour) ?? 0
        let gust = forecast.forecast?.windGustsKnots(hh: hour) ?? 0
        let rain = forecast.forecast?.precipitation1(hh: hour) ?? forecast.forecast?.precipitation(hh: hour) ?? 0
        let humidity = forecast.forecast?.relativeHumidity(hh: hour) ?? 0
        let cloudCover = forecast.forecast?.cloudCoverTotal(hh: hour) ?? 0
        let pressure = forecast.forecast?.seaLevelPressure(hh: hour) ?? 0
        let wave = forecast.forecast?.waveHeight(hh: hour)
        let hourly = hourlyForecast(for: forecast, currentHour: hour, unit: units.temperatureUnit, gridHourStepStore: gridHourStepStore)
        let daily = dailyForecast(for: forecast, unit: units.temperatureUnit)
        let today = daily.first
        let dailyRange = forecast.dailyTemperatureRange(hour: hour)

        return SharedForecastSnapshot(
            date: .now,
            locationName: forecast.locationDisplayName(),
            temperature: "\(Temperature(celsius: temperature).value(in: units.temperatureUnit).forecastFormatted(precision: 0))\(units.temperatureUnit.label)",
            temperatureCelsius: temperature,
            rawTemperature: rawTemperature.map { "\(Temperature(celsius: $0).value(in: units.temperatureUnit).forecastFormatted(precision: 0))\(units.temperatureUnit.label)" } ?? "—",
            rawTemperatureCelsius: rawTemperature ?? temperature,
            realTemperature: realTemperature.map { "\(Temperature(celsius: $0).value(in: units.temperatureUnit).forecastFormatted(precision: 0))\(units.temperatureUnit.label)" } ?? "—",
            realTemperatureCelsius: realTemperature ?? temperature,
            wind: windText(wind, unit: units.windSpeedUnit),
            gust: windText(gust, unit: units.windSpeedUnit),
            windDirection: forecast.forecast?.windDirectionName(hh: hour) ?? "—",
            windDirectionDegrees: forecast.forecast?.windDirection(hh: hour) ?? 0,
            rain: precipitationText(rain, unit: units.precipitationUnit),
            humidity: "\(humidity)%",
            cloudCover: "\(cloudCover)%",
            pressure: pressureText(pressure, unit: units.pressureUnit),
            wave: wave.map { waveHeightText($0, unit: units.waveHeightUnit) },
            symbolName: forecast.weatherSymbolName(hour: hour),
            condition: conditionText(for: forecast, hour: hour),
            high: today?.high ?? temperatureText(temperature, unit: units.temperatureUnit),
            highCelsius: dailyRange?.high ?? temperature,
            low: today?.low ?? temperatureText(temperature, unit: units.temperatureUnit),
            lowCelsius: dailyRange?.low ?? temperature,
            insight: ForecastIntelligenceText.summary(
                forecast: forecast,
                hour: hour,
                temperatureUnit: units.temperatureUnit,
                windSpeedUnit: units.windSpeedUnit,
                precipitationUnit: units.precipitationUnit,
                freezingLevelUnit: units.freezingLevelUnit,
                pressureUnit: units.pressureUnit
            ),
            hourly: hourly,
            daily: daily
        )
    }

    private static func hourlyForecast(for forecast: SpotForecast, currentHour: String?, unit: TemperatureUnit, gridHourStepStore: GridHourStepStoring) -> [Hour] {
        let currentOffset = Int(currentHour ?? "") ?? 0
        return forecast.steppedForecastHours(anchorHour: currentHour, step: gridHourStepStore.load())
            .compactMap { hour -> (hour: String, offset: Int)? in Int(hour).map { (hour, $0) } }
            .filter { $0.offset >= currentOffset }
            .sorted { $0.offset < $1.offset }
            .prefix(10)
            .map { item in
                let date = forecast.forecastDate(hour: item.hour) ?? .now
                let label = item.hour == currentHour ? "now".localized : date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                let temperature = forecast.forecast?.temperatureReal(hh: item.hour) ?? forecast.forecast?.temperature(hh: item.hour) ?? 0
                return Hour(
                    label: label,
                    symbolName: forecast.weatherSymbolName(hour: item.hour),
                    temperature: temperatureText(temperature, unit: unit)
                )
            }
    }

    private static func dailyForecast(for forecast: SpotForecast, unit: TemperatureUnit) -> [Day] {
        let calendar = Calendar.current
        let currentOffset = Int(forecast.currentForecastHour ?? "") ?? 0
        let grouped = Dictionary(grouping: forecast.availableForecastHours) { hour in
            calendar.startOfDay(for: forecast.forecastDate(hour: hour) ?? .now)
        }
        let today = calendar.startOfDay(for: .now)
        let dates = grouped.keys.filter { $0 >= today }.sorted().prefix(10)
        return dates.compactMap { date in
            guard let allHours = grouped[date] else { return nil }
            let hours = calendar.isDateInToday(date)
                ? allHours.filter { (Int($0) ?? 0) >= currentOffset }
                : allHours
            guard !hours.isEmpty else { return nil }
            let temperatures = hours.compactMap { hour in
                (forecast.forecast?.temperatureReal(hh: hour) ?? forecast.forecast?.temperature(hh: hour)).map { Temperature(celsius: $0).value(in: unit) }
            }
            guard let low = temperatures.min(), let high = temperatures.max() else { return nil }
            let representativeHour = representativeHour(among: hours, forecast: forecast)
            let label = calendar.isDateInToday(date) ? "today".localized : date.formatted(.dateTime.weekday(.abbreviated))
            return Day(
                label: label,
                symbolName: forecast.weatherSymbolName(hour: representativeHour),
                low: temperatureText(low, unit: unit, converted: true),
                high: temperatureText(high, unit: unit, converted: true),
                lowValue: low,
                highValue: high
            )
        }
    }

    private static func representativeHour(among hours: [String], forecast: SpotForecast) -> String {
        let sortedHours = hours.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
        func precipitation(_ hour: String) -> Double {
            forecast.forecast?.precipitation1(hh: hour) ?? forecast.forecast?.precipitation(hh: hour) ?? 0
        }
        if let wettestHour = sortedHours.max(by: { precipitation($0) < precipitation($1) }),
           precipitation(wettestHour) > 0 {
            return wettestHour
        }
        return sortedHours[sortedHours.count / 2]
    }

    private static func conditionText(for forecast: SpotForecast, hour: String?) -> String {
        let symbols = forecast.weatherSymbolNames(hour: hour)
        if symbols.contains(where: { $0.contains("snow") }) { return "Snow" }
        if symbols.contains(where: { $0.contains("rain") || $0.contains("drizzle") }) { return "Rain" }
        if symbols.contains(where: { $0.contains("fog") }) { return "Foggy" }
        if symbols.contains("cloud.fill") { return "Overcast" }
        if symbols.contains(where: { $0.hasPrefix("cloud.sun") || $0.hasPrefix("cloud.moon") }) { return "Partly Cloudy" }
        if symbols.contains("cloud") { return "Cloudy" }
        if symbols.contains(where: { $0.hasPrefix("wind") || $0.hasPrefix("tornado") || $0.hasPrefix("tropicalstorm") || $0.hasPrefix("hurricane") }) { return "Windy" }
        return "Clear"
    }

    private static func temperatureText(_ celsius: Double, unit: TemperatureUnit, converted: Bool = false) -> String {
        let value = converted ? celsius : Temperature(celsius: celsius).value(in: unit)
        return "\(value.forecastFormatted(precision: 0))°"
    }

    private static func windText(_ knots: Double, unit: WindSpeedUnit) -> String {
        guard let value = Knots(knots).value(in: unit) else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit.label)"
    }

    private static func precipitationText(_ millimeters: Double, unit: PrecipitationUnit) -> String {
        let value = Precipitation(millimeters: millimeters).value(in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit.label)"
    }

    private static func pressureText(_ hectopascals: Double, unit: PressureUnit) -> String {
        let value = AtmosphericPressure(hectopascals: hectopascals).value(in: unit)
        let precision = unit == .inchesOfMercury ? 2 : 0
        return "\(value.formatted(.number.precision(.fractionLength(precision)))) \(unit.label)"
    }

    private static func waveHeightText(_ meters: Double, unit: WaveHeightUnit) -> String {
        let value = WaveHeight(meters: meters).value(in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(unit.label)"
    }
}

public protocol SharedForecastSnapshotStoring: Sendable {
    func save(_ snapshot: SharedForecastSnapshot)
    func load() -> SharedForecastSnapshot?
}

public final class SharedForecastSnapshotStore: SharedForecastSnapshotStoring {
    private static let appGroupIdentifier = "group.org.forescoop.shared"
    private static let fileName = "CurrentForecastSnapshot.json"

    public init() {}

    private var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)?
            .appending(path: Self.fileName)
    }

    public func save(_ snapshot: SharedForecastSnapshot) {
        guard let fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    public func load() -> SharedForecastSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(SharedForecastSnapshot.self, from: data)
    }
}
