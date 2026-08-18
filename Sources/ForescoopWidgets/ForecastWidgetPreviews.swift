#if DEBUG && canImport(WidgetKit) && !os(tvOS) && !os(watchOS)
import SwiftUI

extension ForecastWidgetEntry {
    static let stormPreview = ForecastWidgetEntry(
        date: .now,
        locationName: "Cerro Catedral",
        temperature: "19°C",
        temperatureCelsius: 19,
        rawTemperature: "22°C",
        rawTemperatureCelsius: 22,
        realTemperature: "19°C",
        realTemperatureCelsius: 19,
        wind: "22 kt",
        gust: "31 kt",
        windDirection: "WNW",
        windDirectionDegrees: 292.5,
        rain: "1.8 mm",
        humidity: "82%",
        cloudCover: "94%",
        pressure: "1002 hPa",
        symbolName: "cloud.rain.fill",
        condition: "Rain showers",
        high: "8°",
        highCelsius: 8,
        low: "3°",
        lowCelsius: 3,
        insight: "Cerro Catedral · Today, 3 PM: 19°C with 22 kt wind, real, altitude-corrected reading, gusting to 31 kt, 94% cloud cover, 82% humidity, 1.8 mm of rain, pressure 1002 hPa.",
        hourly: ForecastWidgetHour.placeholder,
        daily: ForecastWidgetDay.placeholder,
        errorMessage: nil
    )
}

#Preview("Needs update") {
    ForecastWidgetView(entry: .needsUpdate, theme: .ocean, previewFamily: .systemMedium)
        .frame(width: 338, height: 158)
        .padding()
        .background(.blue.gradient)
}

#Preview("Small widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemSmall)
        .frame(width: 158, height: 158)
        .padding()
        .background(.blue.gradient)
}

#Preview("Medium widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemMedium)
        .frame(width: 338, height: 158)
        .padding()
        .background(.blue.gradient)
}

#Preview("Large widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemLarge)
        .frame(width: 338, height: 354)
        .padding()
        .background(.blue.gradient)
}

#Preview("iPad extra-large widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemExtraLarge)
        .frame(width: 720, height: 338)
        .padding()
        .background(.blue.gradient)
}
#endif
