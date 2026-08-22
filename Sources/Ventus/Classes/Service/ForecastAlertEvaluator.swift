//
//  ForecastAlertEvaluator.swift
//  Ventus
//
//  Matches a user-defined ForecastAlert against a loaded forecast.
//

import Foundation

enum ForecastAlertEvaluator {
    static func matchingHour(for alert: ForecastAlert, in spotForecast: SpotForecast) -> (hour: String, date: Date)? {
        guard alert.isActive, !alert.conditions.isEmpty, let forecast = spotForecast.forecast else { return nil }

        let now = Date()
        let calendar = Calendar.current
        guard let horizon = calendar.date(byAdding: .day, value: max(alert.considerForecastUpToDay, 0), to: now) else { return nil }

        for hour in spotForecast.availableForecastHours {
            guard let date = spotForecast.forecastDate(hour: hour), date >= now, date <= horizon else { continue }
            if !alert.weekdays.isEmpty {
                let weekday = calendar.component(.weekday, from: date)
                guard alert.weekdays.contains(weekday) else { continue }
            }
            guard alert.conditions.allSatisfy({ $0.isSatisfied(by: forecast, hour: hour) }) else { continue }
            return (hour, date)
        }
        return nil
    }
}
