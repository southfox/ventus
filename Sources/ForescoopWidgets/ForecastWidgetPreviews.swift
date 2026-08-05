#if DEBUG && canImport(WidgetKit) && !os(tvOS)
import SwiftUI

extension ForecastWidgetEntry {
    static let stormPreview = ForecastWidgetEntry(
        date: .now,
        locationName: "Cerro Catedral",
        temperature: "6°C",
        wind: "22 kt",
        gust: "31 kt",
        windDirection: "WNW",
        rain: "1.8 mm",
        humidity: "82%",
        cloudCover: "94%",
        pressure: "1002 hPa",
        symbolName: "cloud.rain.fill",
        condition: "Rain showers",
        high: "8°",
        low: "3°",
        hourly: ForecastWidgetHour.placeholder,
        daily: ForecastWidgetDay.placeholder
    )
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
