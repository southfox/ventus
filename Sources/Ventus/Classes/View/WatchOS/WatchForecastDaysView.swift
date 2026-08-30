//
//  WatchForecastDaysView.swift
//  Ventus
//
//  Created by Javier Fuchs on 8/23/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if os(watchOS)
import SwiftUI

struct WatchForecastDaysView: View {
    let forecast: SpotForecast?
    let temperatureUnit: TemperatureUnit
    let selectHour: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let forecast {
                ForEach(days(for: forecast)) { day in
                    Button {
                        selectHour(day.hour)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Text(day.label)
                                .font(.caption.weight(.medium))
                                .frame(width: 42, alignment: .leading)
                            Image(systemName: day.symbolName)
                                .frame(width: 18)
                            Spacer(minLength: 0)
                            Text(temperature(day.low))
                                .foregroundStyle(.secondary)
                            Text(temperature(day.high))
                                .fontWeight(.semibold)
                        }
                    }
                    .accessibilityLabel("\(day.label). \(day.condition). Low \(temperature(day.low)). High \(temperature(day.high)).")
                    .accessibilityHint("Show this day on the dashboard.")
                }
            }
        }
        .navigationTitle("10-Day Forecast")
        .forecastAccessibilityContainer(
            "10-day forecast",
            hint: "Select a day to view it on the dashboard.",
            identifier: "watch.forecast.days"
        )
    }

    private func days(for forecast: SpotForecast) -> [WatchForecastDay] {
        guard let weather = forecast.forecast else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = forecast.timezone ?? .current
        let today = calendar.startOfDay(for: Date())
        let grouped = Dictionary(grouping: forecast.availableForecastHours) {
            calendar.startOfDay(for: forecast.forecastDate(hour: $0) ?? .distantPast)
        }

        return grouped.keys
            .filter { $0 >= today }
            .sorted()
            .prefix(10)
            .compactMap { date in
                guard let hours = grouped[date] else { return nil }
                let temperatures = hours.compactMap { weather.temperatureReal(hh: $0) ?? weather.temperature(hh: $0) }
                guard !temperatures.isEmpty,
                      let low = temperatures.min(), let high = temperatures.max() else { return nil }
                let hour = representativeHour(in: hours)
                let label = calendar.isDateInToday(date)
                    ? "\("today".localized) \(calendar.component(.day, from: date))"
                    : date.forecastShortWeekdayAndDay()
                return WatchForecastDay(
                    label: label,
                    hour: hour,
                    symbolName: forecast.weatherSymbolName(hour: hour),
                    condition: conditionText(for: forecast, hour: hour),
                    low: low,
                    high: high
                )
            }
    }

    private func representativeHour(in hours: [String]) -> String {
        let sorted = hours.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
        var calendar = Calendar.current
        calendar.timeZone = forecast?.timezone ?? .current
        return sorted.min { lhs, rhs in
            let lhsHour = calendar.component(.hour, from: forecast?.forecastDate(hour: lhs) ?? .now)
            let rhsHour = calendar.component(.hour, from: forecast?.forecastDate(hour: rhs) ?? .now)
            return abs(lhsHour - 12) < abs(rhsHour - 12)
        } ?? sorted[sorted.count / 2]
    }

    private func conditionText(for forecast: SpotForecast, hour: String) -> String {
        let symbols = forecast.weatherSymbolNames(hour: hour)
        if symbols.contains(where: { $0.contains("snow") }) { return "Snow" }
        if symbols.contains(where: { $0.contains("rain") || $0.contains("drizzle") }) { return "Rain" }
        if symbols.contains("cloud.fill") { return "Overcast" }
        if symbols.contains(where: { $0.hasPrefix("cloud.sun") || $0.hasPrefix("cloud.moon") }) { return "Partly cloudy" }
        if symbols.contains("cloud") { return "Cloudy" }
        return "Clear"
    }

    private func temperature(_ value: Double) -> String {
        WatchForecastFormatting.temperature(value, unit: temperatureUnit)
    }
}

private struct WatchForecastDay: Identifiable {
    let label: String
    let hour: String
    let symbolName: String
    let condition: String
    let low: Double
    let high: Double

    var id: String { hour }
}

#if DEBUG
#Preview("Watch 10-day forecast") {
    NavigationStack {
        WatchForecastDaysView(
            forecast: ForecastWindguruMockup().dashboardPreviewForecast,
            temperatureUnit: .celsius,
            selectHour: { _ in }
        )
    }
}
#endif
#endif
