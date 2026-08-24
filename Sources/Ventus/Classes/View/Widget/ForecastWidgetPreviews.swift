//
//  ForecastWidgetPreviews.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/19/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if DEBUG && canImport(WidgetKit) && !os(watchOS)
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
        wind: "22 kmh",
        gust: "31 kmh",
        windDirection: "WNW",
        windDirectionDegrees: 292.5,
        rain: "2 mm",
        humidity: "82%",
        cloudCover: "94%",
        pressure: "1002 hPa",
        wave: "2 m",
        symbolName: "cloud.rain.fill",
        condition: "Rain showers",
        high: "8°",
        highCelsius: 8,
        low: "3°",
        lowCelsius: 3,
        insight: "Cerro Catedral · Today, 3 PM: 19°C with 22 kt wind, real, altitude-corrected reading, gusting to 31 kt, 94% cloud cover, 82% humidity, 2 mm of rain, pressure 1002 hPa.",
        hourly: ForecastWidgetHour.placeholder,
        daily: ForecastWidgetDay.placeholder,
        errorMessage: nil
    )

    static let longValuesPreview = ForecastWidgetEntry(
        date: .now,
        locationName: "San Martín de los Andes – Chapelco",
        temperature: "−13°C",
        temperatureCelsius: -25,
        rawTemperature: "−15°C",
        rawTemperatureCelsius: -15.4,
        realTemperature: "−13°C",
        realTemperatureCelsius: -12.8,
        wind: "105 km/h",
        gust: "129 km/h",
        windDirection: "West-northwest",
        windDirectionDegrees: 292.5,
        rain: "129 mm",
        humidity: "100%",
        cloudCover: "100%",
        pressure: "1,035 hPa",
        wave: "13 m",
        windChill: "−28°C",
        symbolName: "cloud.snow.fill",
        condition: "Heavy snow showers and strong wind",
        high: "−2°",
        highCelsius: -2.4,
        low: "−19°",
        lowCelsius: -18.7,
        insight: "San Martín de los Andes – Chapelco · Heavy snow showers with severe wind gusts and very low wind chill.",
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

#Preview("Small widget · compact iPhone") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemSmall)
        .frame(width: 155, height: 155)
        .padding()
        .background(.blue.gradient)
}

#Preview("Medium widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemMedium)
        .frame(width: 338, height: 158)
        .padding()
        .background(.blue.gradient)
}

#Preview("Medium widget · long values") {
    ForecastWidgetView(entry: .longValuesPreview, theme: .ocean, previewFamily: .systemMedium)
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

#Preview("iPad extra-large widget", traits: .fixedLayout(width: 728, height: 336)) {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemExtraLarge)
}

#endif
