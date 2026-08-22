//
//  ForecastWidgetEntryBuilder.swift
//  Ventus package
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
        hourlyLimit: Int = 10,
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
        let windChill = forecast.forecast?.windChill(hh: hour)
        let hourly = hourlyForecast(for: forecast, currentHour: hour, unit: units.temperatureUnit, limit: hourlyLimit, environment: environment)
        let daily = dailyForecast(for: forecast, unit: units.temperatureUnit)
        let today = daily.first
        let dailyRange = forecast.dailyTemperatureRange(hour: hour)

        return ForecastWidgetEntry(
            date: .now,
            locationName: forecast.locationDisplayName(coordinateLocationName: coordinateLocationName),
            temperature: temperatureText(temperature, unit: units.temperatureUnit),
            temperatureCelsius: temperature,
            rawTemperature: rawTemperature.map { temperatureText($0, unit: units.temperatureUnit) } ?? "—",
            rawTemperatureCelsius: rawTemperature ?? temperature,
            realTemperature: realTemperature.map { temperatureText($0, unit: units.temperatureUnit) } ?? "—",
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
            windChill: windChill.map { temperatureText($0, unit: units.temperatureUnit) },
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
            windChill: snapshot.windChill,
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

    public static func detailedHourlyForecast(for forecast: SpotForecast, environment: AppEnvironment) -> [ForecastOverviewHour] {
        let units = environment.ventusForecastUnitStore.load(fallback: DeviceForecastPreferenceProvider().forecastUnitPreferences)
        let currentHour = forecast.currentForecastHour
        let currentOffset = Int(currentHour ?? "") ?? 0
        let hours = forecast.steppedForecastHours(anchorHour: currentHour, step: environment.gridHourStepStore.load())
            .compactMap { hour -> (hour: String, offset: Int)? in Int(hour).map { (hour, $0) } }
            .filter { $0.offset >= currentOffset }
            .sorted { $0.offset < $1.offset }
            .map(\.hour)
        let dates = hours.map { forecast.forecastDate(hour: $0) ?? .now }
        let calendar = Calendar.current

        // The next sunrise/sunset that hasn't happened yet — today's if
        // it's still ahead, otherwise a later day's — never one already past.
        let now = Date()
        let sunrise = nextFutureDaylightDate(after: now) { forecast.sunriseDate(on: $0) }
        let sunset = nextFutureDaylightDate(after: now) { forecast.sunsetDate(on: $0) }
        let sunriseIndex = nearestIndex(to: sunrise, in: dates)
        let sunsetIndex = nearestIndex(to: sunset, in: dates)

        return hours.indices.map { index in
            let hour = hours[index]
            let date = dates[index]
            let weather = forecast.forecast
            let temperature = weather?.temperature(hh: hour) ?? weather?.temperatureReal(hh: hour) ?? 0
            let realTemperature = weather?.temperatureReal(hh: hour) ?? temperature
            let wind = weather?.windSpeed(hh: hour) ?? 0
            let gust = weather?.windGustsKnots(hh: hour) ?? 0
            let windChill = weather?.windChill(hh: hour)
            let freezingLevel = weather?.freezingLevelHeightInMeters(hh: hour) ?? 0
            let precipitation = weather?.precipitation1(hh: hour) ?? weather?.precipitation(hh: hour) ?? 0
            let isSnow = precipitation > 0 && realTemperature <= 0

            var daylightTime: String?
            var daylightSymbolName: String?
            if index == sunriseIndex, let sunrise {
                daylightTime = sunrise.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                daylightSymbolName = "sunrise.fill"
            } else if index == sunsetIndex, let sunset {
                daylightTime = sunset.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                daylightSymbolName = "sunset.fill"
            }

            return ForecastOverviewHour(
                dayLabel: calendar.isDateInToday(date) ? "" : date.formatted(.dateTime.weekday(.abbreviated).day()),
                timeLabel: hour == currentHour ? "now".localized : hourLabel(for: date),
                symbolName: forecast.weatherSymbolName(hour: hour),
                temperature: temperatureText(temperature, unit: units.temperatureUnit),
                wind: windText(wind, unit: units.windSpeedUnit),
                gust: windText(gust, unit: units.windSpeedUnit),
                windDirectionDegrees: weather?.windDirection(hh: hour) ?? 0,
                windChill: windChill.map { temperatureText($0, unit: units.temperatureUnit) },
                freezingLevel: freezingLevelText(freezingLevel, unit: units.freezingLevelUnit),
                rain: (precipitation > 0 && !isSnow) ? precipitationText(precipitation, unit: units.precipitationUnit) : nil,
                snow: (precipitation > 0 && isSnow) ? precipitationText(precipitation, unit: units.precipitationUnit) : nil,
                daylightTime: daylightTime,
                daylightSymbolName: daylightSymbolName
            )
        }
    }

    /// "13h" — the Overview hourly strip's own time format: always a plain
    /// 24-hour number, never AM/PM. (Only used here; the real widget's
    /// simple hourly cells keep their existing AM/PM format.)
    private static func hourLabel(for date: Date) -> String {
        "\(Calendar.current.component(.hour, from: date))h"
    }

    private static func nearestIndex(to target: Date?, in dates: [Date]) -> Int? {
        guard let target else { return nil }
        return dates.indices.min { abs(dates[$0].timeIntervalSince(target)) < abs(dates[$1].timeIntervalSince(target)) }
    }

    /// The next occurrence of a once-per-day event (sunrise or sunset)
    /// that is still ahead of `now` — checking today first, then scanning
    /// forward a few days if today's has already passed.
    private static func nextFutureDaylightDate(after now: Date, on dateForDay: (Date) -> Date?) -> Date? {
        var day = now
        let calendar = Calendar.current
        for _ in 0..<8 {
            if let candidate = dateForDay(day), candidate >= now {
                return candidate
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return nil
    }

    private static func hourlyForecast(for forecast: SpotForecast, currentHour: String?, unit: TemperatureUnit, limit: Int = 10, environment: AppEnvironment) -> [ForecastWidgetHour] {
        let currentOffset = Int(currentHour ?? "") ?? 0
        let items = forecast.steppedForecastHours(anchorHour: currentHour, step: environment.gridHourStepStore.load())
            .compactMap { hour -> (hour: String, offset: Int)? in Int(hour).map { (hour, $0) } }
            .filter { $0.offset >= currentOffset }
            .sorted { $0.offset < $1.offset }
            .prefix(limit)
            .map { item -> (date: Date, celsius: Double, hour: ForecastWidgetHour) in
                let date = forecast.forecastDate(hour: item.hour) ?? .now
                let label = item.hour == currentHour ? "now".localized : date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                let celsius = forecast.forecast?.temperatureReal(hh: item.hour) ?? forecast.forecast?.temperature(hh: item.hour) ?? 0
                return (
                    date: date,
                    celsius: celsius,
                    hour: ForecastWidgetHour(
                        label: label,
                        symbolName: forecast.weatherSymbolName(hour: item.hour),
                        temperature: temperatureText(celsius, unit: unit)
                    )
                )
            }
        return forecast.insertingDaylightEvents(
            into: items,
            date: { $0.date },
            make: { previous, next, eventDate, symbolName in
                let celsius = (previous.celsius + next.celsius) / 2
                let label = eventDate.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                return (date: eventDate, celsius: celsius, hour: ForecastWidgetHour(label: label, symbolName: symbolName, temperature: temperatureText(celsius, unit: unit)))
            }
        ).map(\.hour)
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
        return "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit.widgetLabel)"
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

    private static func freezingLevelText(_ meters: Double, unit: FreezingLevelUnit) -> String {
        let value = FreezingLevel(meters: meters).value(in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit.label)"
    }
}
#endif
