//
//  ForecastWidgetEntryBuilder.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/19/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if canImport(WidgetKit)
import Foundation

public enum ForecastWidgetEntryBuilder {
    public static func entry(
        from forecast: SpotForecast,
        coordinateLocationName: String?,
        useDetailedInsight: Bool = false,
        environment: AppEnvironment
    ) -> ForecastWidgetEntry {
        let hour = forecast.currentForecastHour
        let units = environment.ventusForecastUnitStore.load(fallback: DeviceForecastPreferenceProvider().forecastUnitPreferences)
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
        let hourly = hourlyForecast(for: forecast, currentHour: hour, unit: units.temperatureUnit, environment: environment)
        let daily = dailyForecast(for: forecast, unit: units.temperatureUnit)
        let today = daily.first
        let dailyRange = forecast.dailyTemperatureRange(hour: hour)

        return ForecastWidgetEntry(
            date: .now,
            locationName: forecast.locationDisplayName(coordinateLocationName: coordinateLocationName),
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
            insight: useDetailedInsight
                ? ForecastIntelligenceText.detailedSummary(
                    forecast: forecast,
                    hour: hour,
                    temperatureUnit: units.temperatureUnit,
                    windSpeedUnit: units.windSpeedUnit,
                    precipitationUnit: units.precipitationUnit,
                    freezingLevelUnit: units.freezingLevelUnit,
                    pressureUnit: units.pressureUnit
                )
                : ForecastIntelligenceText.summary(
                    forecast: forecast,
                    hour: hour,
                    temperatureUnit: units.temperatureUnit,
                    windSpeedUnit: units.windSpeedUnit,
                    precipitationUnit: units.precipitationUnit,
                    freezingLevelUnit: units.freezingLevelUnit,
                    pressureUnit: units.pressureUnit
                ),
            hourly: hourly,
            daily: daily,
            errorMessage: nil
        )
    }

    public static func entry(from snapshot: SharedForecastSnapshot) -> ForecastWidgetEntry {
        ForecastWidgetEntry(
            date: snapshot.date,
            locationName: snapshot.locationName,
            temperature: snapshot.temperature,
            temperatureCelsius: snapshot.temperatureCelsius,
            rawTemperature: snapshot.rawTemperature,
            rawTemperatureCelsius: snapshot.rawTemperatureCelsius,
            realTemperature: snapshot.realTemperature,
            realTemperatureCelsius: snapshot.realTemperatureCelsius,
            wind: snapshot.wind,
            gust: snapshot.gust,
            windDirection: snapshot.windDirection,
            windDirectionDegrees: snapshot.windDirectionDegrees,
            rain: snapshot.rain,
            humidity: snapshot.humidity,
            cloudCover: snapshot.cloudCover,
            pressure: snapshot.pressure,
            wave: snapshot.wave,
            symbolName: snapshot.symbolName,
            condition: snapshot.condition,
            high: snapshot.high,
            highCelsius: snapshot.highCelsius,
            low: snapshot.low,
            lowCelsius: snapshot.lowCelsius,
            insight: snapshot.insight,
            hourly: snapshot.hourly.map { ForecastWidgetHour(label: $0.label, symbolName: $0.symbolName, temperature: $0.temperature) },
            daily: snapshot.daily.map {
                ForecastWidgetDay(label: $0.label, symbolName: $0.symbolName, low: $0.low, high: $0.high, lowValue: $0.lowValue, highValue: $0.highValue)
            },
            errorMessage: nil
        )
    }

    private static func hourlyForecast(for forecast: SpotForecast, currentHour: String?, unit: TemperatureUnit, environment: AppEnvironment) -> [ForecastWidgetHour] {
        let currentOffset = Int(currentHour ?? "") ?? 0
        return forecast.steppedForecastHours(anchorHour: currentHour, step: environment.gridHourStepStore.load())
            .compactMap { hour -> (hour: String, offset: Int)? in Int(hour).map { (hour, $0) } }
            .filter { $0.offset >= currentOffset }
            .sorted { $0.offset < $1.offset }
            .prefix(10)
            .map { item in
                let date = forecast.forecastDate(hour: item.hour) ?? .now
                let label = item.hour == currentHour ? "now".localized : date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                let temperature = forecast.forecast?.temperatureReal(hh: item.hour) ?? forecast.forecast?.temperature(hh: item.hour) ?? 0
                return ForecastWidgetHour(
                    label: label,
                    symbolName: forecast.weatherSymbolName(hour: item.hour),
                    temperature: temperatureText(temperature, unit: unit)
                )
            }
    }

    private static func dailyForecast(for forecast: SpotForecast, unit: TemperatureUnit) -> [ForecastWidgetDay] {
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
#endif
