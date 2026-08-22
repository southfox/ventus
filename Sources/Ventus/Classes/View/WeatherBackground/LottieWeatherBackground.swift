//
//  LottieWeatherBackground.swift
//  Ventus package
//
//  Created by Javier Fuchs on 07/31/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

enum LottieWeatherTheme {
    case adrianaMandjarova
    case asadAwan
}

#if canImport(Lottie) && !os(macOS)
import Lottie

public struct LottieWeatherBackground: WeatherBackground {
    private let forecast: SpotForecast
    private let hour: String?
    private let asset: LottieWeatherAsset?
    private let showsRainbow: Bool

    public init(forecast: SpotForecast, hour: String? = nil) {
        self.init(forecast: forecast, hour: hour, theme: .adrianaMandjarova)
    }

    init(forecast: SpotForecast, hour: String? = nil, theme: LottieWeatherTheme) {
        self.forecast = forecast
        self.hour = hour
        let condition = WeatherBackgroundCondition(forecast: forecast, hour: hour)
        asset = Self.animationAsset(for: condition, theme: theme)
        showsRainbow = condition.showsRainbow
    }

    public var body: some View {
        if let asset, asset.isAvailable {
            LottieWeatherAnimationView(asset: asset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.10)
                .overlay { WeatherRainbowOverlay(isVisible: showsRainbow) }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        } else {
            AnimatedWeatherBackground(forecast: forecast, hour: hour)
        }
    }

    private static func animationAsset(
        for condition: WeatherBackgroundCondition,
        theme: LottieWeatherTheme
    ) -> LottieWeatherAsset? {
        switch theme {
        case .adrianaMandjarova:
            return adrianaAsset(condition: condition)
        case .asadAwan:
            return asadAsset(condition: condition)
        }
    }

    private static func adrianaAsset(condition: WeatherBackgroundCondition) -> LottieWeatherAsset {
        let isNight = condition.isNight
        let dayOrNight = isNight ? "Weather Night - " : "Weather Day - "
        let brokenClouds: LottieWeatherAsset = isNight
            ? .dotLottie("Weather Night - Broken clouds")
            : .dotLottie("Weather Day - broken clouds")

        if condition.isSnowy { return .dotLottie(dayOrNight + "snow") }
        if condition.isHeavyRain { return .dotLottie(dayOrNight + "thunderstorm") }
        if condition.isRainy { return .dotLottie(dayOrNight + "rain") }
        if condition.isFoggy {
            return .dotLottie(dayOrNight + "mist")
        }
        if max(condition.windSpeedKnots, condition.windGustKnots) >= 18 { return brokenClouds }
        if condition.cloudCoverPercent >= 80 { return brokenClouds }
        if condition.cloudCoverPercent > 0 {
            return isNight
                ? .dotLottie("Weather Night - Few clouds")
                : .dotLottie("Weather Day - few clouds")
        }
        return isNight
            ? .dotLottie("Weather Night - Few clouds")
            : .dotLottie("Weather Day - clear sky")
    }

    private static func asadAsset(condition: WeatherBackgroundCondition) -> LottieWeatherAsset {
        if condition.isSnowy { return .dotLottie("Snow Day") }
        if condition.isHeavyRain { return .dotLottie("Thunder Night") }
        if condition.isRainy { return .dotLottie("Rainy Day") }
        if condition.isFoggy || max(condition.windSpeedKnots, condition.windGustKnots) >= 18 || condition.cloudCoverPercent > 0 {
            return .dotLottie("Cloudy Day")
        }
        return .dotLottie("Clear Day")
    }
}

private enum LottieWeatherAsset {
    case dotLottie(String)

    var isAvailable: Bool {
        Bundle.module.url(forResource: name, withExtension: "lottie") != nil
    }

    private var name: String {
        switch self {
        case let .dotLottie(name): name
        }
    }
}

private struct LottieWeatherAnimationView: View {
    let asset: LottieWeatherAsset

    @ViewBuilder var body: some View {
        switch asset {
        case let .dotLottie(name):
            switch DotLottieFile.SynchronouslyBlockingCurrentThread.named(name, bundle: .module) {
            case let .success(file):
                LottieView(dotLottieFile: file)
                    .resizable()
                    .configure(\.contentMode, to: .scaleAspectFill)
                    .playing(loopMode: .loop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failure:
                Color.clear
            }
        }
    }
}

private struct LottieAssetPreview: View {
    let name: String

    var body: some View {
        LottieWeatherAnimationView(asset: .dotLottie(name))
            .frame(height: 400)
            .background(.black.opacity(0.08))
    }
}

#Preview("Day · clear sky") { LottieAssetPreview(name: "Weather Day - clear sky") }
#Preview("Day · few clouds") { LottieAssetPreview(name: "Weather Day - few clouds") }
#Preview("Day · scattered clouds") { LottieAssetPreview(name: "Weather Day - scattered clouds") }
#Preview("Day · broken clouds") { LottieAssetPreview(name: "Weather Day - broken clouds") }
#Preview("Day · mist") { LottieAssetPreview(name: "Weather Day - mist") }
#Preview("Day · rain") { LottieAssetPreview(name: "Weather Day - rain") }
#Preview("Day · shower rains") { LottieAssetPreview(name: "Weather Day - Shower rains") }
#Preview("Day · snow") { LottieAssetPreview(name: "Weather Day - snow") }
#Preview("Day · thunderstorm") { LottieAssetPreview(name: "Weather Day - thunderstorm") }

#Preview("Night · few clouds") { LottieAssetPreview(name: "Weather Night - Few clouds") }
#Preview("Night · scattered clouds") { LottieAssetPreview(name: "Weather Night - Scattered clouds") }
#Preview("Night · broken clouds") { LottieAssetPreview(name: "Weather Night - Broken clouds") }
#Preview("Night · mist") { LottieAssetPreview(name: "Weather Night - mist") }
#Preview("Night · rain") { LottieAssetPreview(name: "Weather Night - rain") }
#Preview("Night · shower rains") { LottieAssetPreview(name: "Weather Night - Shower rains") }
#Preview("Night · snow") { LottieAssetPreview(name: "Weather Night - snow") }
#Preview("Night · thunderstorm") { LottieAssetPreview(name: "Weather Night - Thunderstorm") }

#Preview("Asad · clear day") { LottieAssetPreview(name: "Clear Day") }
#Preview("Asad · cloudy day") { LottieAssetPreview(name: "Cloudy Day") }
#Preview("Asad · rainy day") { LottieAssetPreview(name: "Rainy Day") }
#Preview("Asad · snow day") { LottieAssetPreview(name: "Snow Day") }
#Preview("Asad · thunder night") { LottieAssetPreview(name: "Thunder Night") }

#Preview("Lottie · sun shower rainbow") {
    LottieWeatherBackground(
        forecast: AnimatedWeatherPreviewData.forecast(precipitation: 2, temperature: 18, cloudCover: 25, windSpeed: 8, gusts: 13),
        hour: "29"
    )
    .frame(height: 400)
}

#Preview("Lottie Asad · sun shower rainbow") {
    LottieWeatherBackground(
        forecast: AnimatedWeatherPreviewData.forecast(precipitation: 2, temperature: 18, cloudCover: 25, windSpeed: 8, gusts: 13),
        hour: "29",
        theme: .asadAwan
    )
    .frame(height: 400)
}
#else
public struct LottieWeatherBackground: WeatherBackground {
    private let forecast: SpotForecast
    private let hour: String?

    public init(forecast: SpotForecast, hour: String? = nil) {
        self.forecast = forecast
        self.hour = hour
    }

    init(forecast: SpotForecast, hour: String? = nil, theme: LottieWeatherTheme) {
        self.init(forecast: forecast, hour: hour)
    }

    public var body: some View {
        AnimatedWeatherBackground(forecast: forecast, hour: hour)
    }
}
#endif
