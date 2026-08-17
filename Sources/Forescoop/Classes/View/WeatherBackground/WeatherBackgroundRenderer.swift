//
//  WeatherBackgroundRenderer.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 07/31/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

public protocol WeatherBackground: View {
    init(forecast: SpotForecast, hour: String?)
}

struct WeatherBackgroundCondition: Equatable {
    let symbolNames: [String]
    let precipitationMillimeters: Double
    let windSpeedKnots: Double
    let windGustKnots: Double
    let windDirectionDegrees: Double
    let cloudCoverPercent: Int
    let humidityPercent: Int
    let temperatureCelsius: Double
    let forecastDate: Date

    init(forecast: SpotForecast, hour: String?) {
        let selectedHour = hour ?? forecast.currentForecastHour
        let weather = forecast.forecast
        symbolNames = forecast.weatherSymbolNames(hour: selectedHour)
        precipitationMillimeters = weather?.precipitation(hh: selectedHour) ?? weather?.precipitation1(hh: selectedHour) ?? 0
        windSpeedKnots = weather?.windSpeed(hh: selectedHour) ?? 0
        windGustKnots = weather?.windGustsKnots(hh: selectedHour) ?? 0
        windDirectionDegrees = weather?.windDirection(hh: selectedHour) ?? 270
        cloudCoverPercent = weather?.cloudCoverTotal(hh: selectedHour) ?? 0
        humidityPercent = weather?.relativeHumidity(hh: selectedHour) ?? 0
        temperatureCelsius = weather?.temperatureReal(hh: selectedHour) ?? weather?.temperature(hh: selectedHour) ?? 0
        forecastDate = forecast.forecastDate(hour: selectedHour) ?? Date()
    }

    var isSunny: Bool { symbolNames.contains { $0.contains("sun") } }
    var isNight: Bool { symbolNames.contains { $0.contains("moon") } }
    var isCloudy: Bool { symbolNames.contains { $0.contains("cloud") } }
    var isWindy: Bool { symbolNames.contains { $0 == "wind" || $0.contains("tornado") } }
    var isRainy: Bool { symbolNames.contains { $0.contains("rain") || $0.contains("drizzle") } }
    var isSnowy: Bool { symbolNames.contains { $0.contains("snow") } }
    var isFoggy: Bool { symbolNames.contains { $0.contains("fog") } || (humidityPercent >= 95 && cloudCoverPercent >= 80) }
    var hasPrecipitation: Bool { precipitationMillimeters > 0 }
    var isHeavyRain: Bool { isRainy && precipitationMillimeters >= 8 }
    var showsRainbow: Bool { isSunny && precipitationMillimeters > 0 && !isSnowy }
    var isFreezing: Bool { temperatureCelsius <= 0 }
    var isHot: Bool { temperatureCelsius >= 30 }
    var windTravelDirectionDegrees: Double { windDirectionDegrees + 180 }
}

public enum WeatherBackgroundStyle: String, CaseIterable, Identifiable, Sendable {
    case none
    case animated
    case metal
    case spriteKit
    case lottieAdriana
    case lottieAsad

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: "None".localized
        case .animated: "Native"
        case .metal: "Metal"
        case .spriteKit: "SpriteKit"
        case .lottieAdriana: "Lottie – Adriana"
        case .lottieAsad: "Lottie – Asad"
        }
    }

    public var systemImage: String {
        switch self {
        case .none: "circle.slash"
        case .animated: "sparkles"
        case .metal: "cpu"
        case .spriteKit: "leaf.arrow.circlepath"
        case .lottieAdriana, .lottieAsad: "play.rectangle"
        }
    }
}

public struct WeatherBackgroundRenderer: View {
    private let style: WeatherBackgroundStyle
    private let forecast: SpotForecast
    private let hour: String?
    private let isNight: Bool
    private let showsStars: Bool

    public init(
        style: WeatherBackgroundStyle,
        forecast: SpotForecast,
        hour: String? = nil
    ) {
        self.style = style
        self.forecast = forecast
        self.hour = hour
        let selectedHour = hour ?? forecast.currentForecastHour
        let condition = WeatherBackgroundCondition(forecast: forecast, hour: selectedHour)
        isNight = !forecast.isDaylight(at: condition.forecastDate)
        showsStars = !(condition.isCloudy || condition.isFoggy) && !condition.hasPrecipitation
    }

    public var body: some View {
        Group {
            switch style {
            case .none:
                Color.clear
            case .animated:
                AnimatedWeatherBackground(forecast: forecast, hour: hour)
            case .metal:
                MetalWeatherBackground(forecast: forecast, hour: hour)
            case .spriteKit:
                SpriteKitWeatherBackground(forecast: forecast, hour: hour)
            case .lottieAdriana:
                LottieWeatherBackground(forecast: forecast, hour: hour, theme: .adrianaMandjarova)
            case .lottieAsad:
                LottieWeatherBackground(forecast: forecast, hour: hour, theme: .asadAwan)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay {
            if style != .animated {
                WeatherNightSkyOverlay(isVisible: isNight, showsStars: showsStars)
            }
        }
    }
}
