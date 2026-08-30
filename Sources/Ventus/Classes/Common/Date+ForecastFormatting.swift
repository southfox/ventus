//
//  Date+ForecastFormatting.swift
//  Ventus
//

import Foundation

public extension Date {
    /// A localized, compact weekday label suitable for forecast timelines.
    /// Keeping it lowercase makes every platform's dense forecast UI consistent.
    func forecastShortWeekday(locale: Locale = AppLanguageStore.currentLocale) -> String {
        formatted(.dateTime.weekday(.abbreviated).locale(locale))
            .lowercased(with: locale)
    }

    func forecastShortWeekdayAndDay(locale: Locale = AppLanguageStore.currentLocale) -> String {
        formatted(.dateTime.weekday(.abbreviated).day().locale(locale))
            .lowercased(with: locale)
    }
}

public extension WForecast {
    /// Windguru weekday indexes are Sunday-first. Convert them to the user's
    /// localized short weekday names rather than returning English source text.
    func shortWeekday(hour: Int, locale: Locale = AppLanguageStore.currentLocale) -> String? {
        guard hr_weekday.indices.contains(hour) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        guard let symbols = formatter.shortWeekdaySymbols else { return nil }
        let weekday = hr_weekday[hour]
        guard symbols.indices.contains(weekday) else { return nil }
        return symbols[weekday].lowercased(with: locale)
    }
}
