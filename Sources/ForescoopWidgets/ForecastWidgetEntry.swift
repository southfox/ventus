#if canImport(WidgetKit) && !os(tvOS)
import Forescoop
import SwiftUI
import WidgetKit

public struct ForecastWidgetEntry: TimelineEntry, Sendable {
    public let date: Date
    public let locationName: String
    public let temperature: String
    public let temperatureCelsius: Double
    public let rawTemperature: String
    public let rawTemperatureCelsius: Double
    public let wind: String
    public let gust: String
    public let windDirection: String
    public let rain: String
    public let humidity: String
    public let cloudCover: String
    public let pressure: String
    public let symbolName: String
    public let condition: String
    public let high: String
    public let highCelsius: Double
    public let low: String
    public let lowCelsius: Double
    public let insight: String
    public let hourly: [ForecastWidgetHour]
    public let daily: [ForecastWidgetDay]
    public let errorMessage: String?

    public static let placeholder = ForecastWidgetEntry(
        date: .now,
        locationName: "Bariloche",
        temperature: "12°C",
        temperatureCelsius: 12,
        rawTemperature: "11°C",
        rawTemperatureCelsius: 11,
        wind: "10 kt",
        gust: "16 kt",
        windDirection: "W",
        rain: "0 mm",
        humidity: "58%",
        cloudCover: "35%",
        pressure: "1015 hPa",
        symbolName: "cloud.sun.fill",
        condition: "Partly cloudy",
        high: "14°",
        highCelsius: 14,
        low: "6°",
        lowCelsius: 6,
        insight: "Bariloche · Today, 2 PM: 12°C with 10 kt wind, real, altitude-corrected reading, 35% cloud cover, 58% humidity, pressure 1015 hPa.",
        hourly: ForecastWidgetHour.placeholder,
        daily: ForecastWidgetDay.placeholder,
        errorMessage: nil
    )

    public static let needsUpdate = ForecastWidgetEntry(
        date: .now,
        locationName: "—",
        temperature: "—",
        temperatureCelsius: 0,
        rawTemperature: "—",
        rawTemperatureCelsius: 0,
        wind: "—",
        gust: "—",
        windDirection: "—",
        rain: "—",
        humidity: "—",
        cloudCover: "—",
        pressure: "—",
        symbolName: "exclamationmark.circle",
        condition: "—",
        high: "—",
        highCelsius: 0,
        low: "—",
        lowCelsius: 0,
        insight: "",
        hourly: [],
        daily: [],
        errorMessage: "Open Ventus to update the forecast".localized
    )
}

public struct ForecastWidgetHour: Identifiable, Sendable {
    public let label: String
    public let symbolName: String
    public let temperature: String

    public var id: String { label }

    public static let placeholder = [
        ForecastWidgetHour(label: "Now", symbolName: "cloud.sun.fill", temperature: "12°"),
        ForecastWidgetHour(label: "2 PM", symbolName: "cloud.sun.fill", temperature: "13°"),
        ForecastWidgetHour(label: "3 PM", symbolName: "cloud.fill", temperature: "13°"),
        ForecastWidgetHour(label: "4 PM", symbolName: "cloud.rain.fill", temperature: "11°"),
        ForecastWidgetHour(label: "5 PM", symbolName: "cloud.rain.fill", temperature: "10°"),
        ForecastWidgetHour(label: "6 PM", symbolName: "cloud.moon.fill", temperature: "9°")
    ]
}

public struct ForecastWidgetDay: Identifiable, Sendable {
    public let label: String
    public let symbolName: String
    public let low: String
    public let high: String
    public let lowValue: Double
    public let highValue: Double

    public var id: String { "\(label)-\(lowValue)-\(highValue)" }

    public static let placeholder = [
        ForecastWidgetDay(label: "Today", symbolName: "cloud.sun.fill", low: "6°", high: "14°", lowValue: 6, highValue: 14),
        ForecastWidgetDay(label: "Thu", symbolName: "cloud.rain.fill", low: "5°", high: "11°", lowValue: 5, highValue: 11),
        ForecastWidgetDay(label: "Fri", symbolName: "cloud.fill", low: "4°", high: "10°", lowValue: 4, highValue: 10),
        ForecastWidgetDay(label: "Sat", symbolName: "sun.max.fill", low: "6°", high: "16°", lowValue: 6, highValue: 16),
        ForecastWidgetDay(label: "Sun", symbolName: "cloud.sun.fill", low: "7°", high: "15°", lowValue: 7, highValue: 15),
        ForecastWidgetDay(label: "Mon", symbolName: "cloud.rain.fill", low: "6°", high: "12°", lowValue: 6, highValue: 12),
        ForecastWidgetDay(label: "Tue", symbolName: "cloud.fill", low: "5°", high: "11°", lowValue: 5, highValue: 11),
        ForecastWidgetDay(label: "Wed", symbolName: "sun.max.fill", low: "8°", high: "17°", lowValue: 8, highValue: 17),
        ForecastWidgetDay(label: "Thu", symbolName: "cloud.sun.fill", low: "9°", high: "18°", lowValue: 9, highValue: 18),
        ForecastWidgetDay(label: "Fri", symbolName: "cloud.rain.fill", low: "7°", high: "13°", lowValue: 7, highValue: 13),
        ForecastWidgetDay(label: "Sat", symbolName: "cloud.fill", low: "6°", high: "12°", lowValue: 6, highValue: 12)
    ]
}

#if DEBUG
#Preview("Placeholder entry") {
    ForecastWidgetView(entry: .placeholder)
        .frame(width: 320, height: 150)
        .padding()
        .background(.blue.gradient)
}
#endif
#endif
