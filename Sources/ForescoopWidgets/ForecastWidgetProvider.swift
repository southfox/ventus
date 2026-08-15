//
//  ForecastWidgetProvider.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 8/15/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if canImport(WidgetKit) && !os(tvOS)
import Forescoop
import SwiftUI
import WidgetKit

public struct ForecastWidgetProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> ForecastWidgetEntry { .placeholder }

    public func getSnapshot(in context: Context, completion: @escaping (ForecastWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<ForecastWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(3_600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> ForecastWidgetEntry {
        if let snapshot = SharedForecastSnapshotStore.load() {
            return entry(from: snapshot)
        }
        guard let forecast = ForecastWindguruMockup().dashboardPreviewForecast else { return .placeholder }
        let hour = forecast.currentForecastHour
        let units = VentusForecastUnitStore.load()
        let temperature = forecast.forecast?.temperatureReal(hh: hour) ?? forecast.forecast?.temperature(hh: hour) ?? 0
        let wind = forecast.forecast?.windSpeed(hh: hour) ?? 0
        let gust = forecast.forecast?.windGustsKnots(hh: hour) ?? 0
        let rain = forecast.forecast?.precipitation1(hh: hour) ?? forecast.forecast?.precipitation(hh: hour) ?? 0
        let humidity = forecast.forecast?.relativeHumidity(hh: hour) ?? 0
        let cloudCover = forecast.forecast?.cloudCoverTotal(hh: hour) ?? 0
        let pressure = forecast.forecast?.seaLevelPressure(hh: hour) ?? 0
        let hourly = hourlyForecast(for: forecast, currentHour: hour, unit: units.temperatureUnit)
        let daily = dailyForecast(for: forecast, unit: units.temperatureUnit)
        let today = daily.first

        return ForecastWidgetEntry(
            date: .now,
            locationName: forecast.locationDisplayName(),
            temperature: "\(Temperature(celsius: temperature).value(in: units.temperatureUnit).formatted(.number.precision(.fractionLength(0))))\(units.temperatureUnit.label)",
            wind: windText(wind, unit: units.windSpeedUnit),
            gust: windText(gust, unit: units.windSpeedUnit),
            windDirection: forecast.forecast?.windDirectionName(hh: hour) ?? "—",
            rain: precipitationText(rain, unit: units.precipitationUnit),
            humidity: "\(humidity)%",
            cloudCover: "\(cloudCover)%",
            pressure: pressureText(pressure, unit: units.pressureUnit),
            symbolName: forecast.weatherSymbolName(hour: hour),
            condition: conditionText(for: forecast, hour: hour),
            high: today?.high ?? temperatureText(temperature, unit: units.temperatureUnit),
            low: today?.low ?? temperatureText(temperature, unit: units.temperatureUnit),
            hourly: hourly,
            daily: daily
        )
    }

    private func entry(from snapshot: SharedForecastSnapshot) -> ForecastWidgetEntry {
        ForecastWidgetEntry(
            date: snapshot.date,
            locationName: snapshot.locationName,
            temperature: snapshot.temperature,
            wind: snapshot.wind,
            gust: snapshot.gust,
            windDirection: snapshot.windDirection,
            rain: snapshot.rain,
            humidity: snapshot.humidity,
            cloudCover: snapshot.cloudCover,
            pressure: snapshot.pressure,
            symbolName: snapshot.symbolName,
            condition: snapshot.condition,
            high: snapshot.high,
            low: snapshot.low,
            hourly: snapshot.hourly.map { ForecastWidgetHour(label: $0.label, symbolName: $0.symbolName, temperature: $0.temperature) },
            daily: snapshot.daily.map {
                ForecastWidgetDay(label: $0.label, symbolName: $0.symbolName, low: $0.low, high: $0.high, lowValue: $0.lowValue, highValue: $0.highValue)
            }
        )
    }

    private func hourlyForecast(for forecast: SpotForecast, currentHour: String?, unit: TemperatureUnit) -> [ForecastWidgetHour] {
        let currentOffset = Int(currentHour ?? "") ?? 0
        return forecast.availableForecastHours
            .compactMap { hour -> (hour: String, offset: Int)? in Int(hour).map { (hour, $0) } }
            .filter { $0.offset >= currentOffset }
            .sorted { $0.offset < $1.offset }
            // The extra-large iPad widget shows a longer outlook; compact
            // families select the first six entries in their own layout.
            .prefix(10)
            .map { item in
                let date = forecast.forecastDate(hour: item.hour) ?? .now
                let label = item.hour == currentHour ? "Now" : date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                let temperature = forecast.forecast?.temperatureReal(hh: item.hour) ?? forecast.forecast?.temperature(hh: item.hour) ?? 0
                return ForecastWidgetHour(
                    label: label,
                    symbolName: forecast.weatherSymbolName(hour: item.hour),
                    temperature: temperatureText(temperature, unit: unit)
                )
            }
    }

    private func dailyForecast(for forecast: SpotForecast, unit: TemperatureUnit) -> [ForecastWidgetDay] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: forecast.availableForecastHours) { hour in
            calendar.startOfDay(for: forecast.forecastDate(hour: hour) ?? .now)
        }
        // The iPad extra-large widget presents a complete ten-day outlook.
        let dates = grouped.keys.sorted().prefix(10)
        return dates.compactMap { date in
            guard let hours = grouped[date] else { return nil }
            let temperatures = hours.compactMap { hour in
                (forecast.forecast?.temperatureReal(hh: hour) ?? forecast.forecast?.temperature(hh: hour)).map { Temperature(celsius: $0).value(in: unit) }
            }
            guard let low = temperatures.min(), let high = temperatures.max() else { return nil }
            let representativeHour = hours.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }[hours.count / 2]
            let label = calendar.isDateInToday(date) ? "Today".localized : date.formatted(.dateTime.weekday(.abbreviated))
            return ForecastWidgetDay(
                label: label,
                symbolName: forecast.weatherSymbolName(hour: representativeHour),
                low: temperatureText(low, unit: unit, converted: true),
                high: temperatureText(high, unit: unit, converted: true),
                lowValue: low,
                highValue: high
            )
        }
    }

    private func conditionText(for forecast: SpotForecast, hour: String?) -> String {
        let symbols = forecast.weatherSymbolNames(hour: hour)
        if symbols.contains(where: { $0.contains("snow") }) { return "Snow" }
        if symbols.contains(where: { $0.contains("rain") || $0.contains("drizzle") }) { return "Rain" }
        if symbols.contains(where: { $0.contains("fog") }) { return "Foggy" }
        if symbols.contains(where: { $0.contains("cloud") }) { return "Cloudy" }
        if symbols.contains("wind") { return "Windy" }
        return "Clear"
    }

    private func temperatureText(_ celsius: Double, unit: TemperatureUnit, converted: Bool = false) -> String {
        let value = converted ? celsius : Temperature(celsius: celsius).value(in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(0))))°"
    }

    private func windText(_ knots: Double, unit: WindSpeedUnit) -> String {
        guard let value = Knots(knots).value(in: unit) else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit.label)"
    }

    private func precipitationText(_ millimeters: Double, unit: PrecipitationUnit) -> String {
        let value = Precipitation(millimeters: millimeters).value(in: unit)
        let precision = unit == .inches ? 2 : 1
        return "\(value.formatted(.number.precision(.fractionLength(precision)))) \(unit.label)"
    }

    private func pressureText(_ hectopascals: Double, unit: PressureUnit) -> String {
        let value = AtmosphericPressure(hectopascals: hectopascals).value(in: unit)
        let precision = unit == .inchesOfMercury ? 2 : 0
        return "\(value.formatted(.number.precision(.fractionLength(precision)))) \(unit.label)"
    }
}

#if DEBUG
#Preview("Provider result") {
    ForecastWidgetView(entry: .placeholder)
        .frame(width: 320, height: 150)
        .padding()
        .background(.blue.gradient)
}
#endif
#endif
