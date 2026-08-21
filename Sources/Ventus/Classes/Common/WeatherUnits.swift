//
//  WeatherUnits.swift
//  Forescoop
//
//  Created by Javier Fuchs on 07/22/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum WindSpeedUnit: String, CaseIterable, Identifiable, Sendable {
    case knots
    case metersPerSecond
    case kilometersPerHour
    case milesPerHour
    case beaufort

    public var id: Self { self }

    public var label: String {
        switch self {
        case .knots: "knots".localized
        case .metersPerSecond: "m/s"
        case .kilometersPerHour: "km/h"
        case .milesPerHour: "mph"
        case .beaufort: "Bft"
        }
    }

    /// Compact unit label for the widget's constrained space, e.g. "kmh" instead of "km/h".
    public var widgetLabel: String {
        switch self {
        case .knots: "kts"
        case .metersPerSecond: "ms"
        case .kilometersPerHour: "kmh"
        case .milesPerHour: "mph"
        case .beaufort: "Bft"
        }
    }
}

public extension WindSpeedUnit {
    init?(windguruPreference: String?) {
        switch windguruPreference?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "knots", "knot", "kt", "kts": self = .knots
        case "m/s", "ms", "mps": self = .metersPerSecond
        case "km/h", "kmh", "kph": self = .kilometersPerHour
        case "mph": self = .milesPerHour
        case "bft", "beaufort": self = .beaufort
        default: return nil
        }
    }
}

public enum TemperatureUnit: String, CaseIterable, Identifiable, Sendable {
    case celsius
    case fahrenheit

    public var id: Self { self }

    public var label: String {
        switch self {
        case .celsius: "°C"
        case .fahrenheit: "°F"
        }
    }
}

public extension TemperatureUnit {
    init?(windguruPreference: String?) {
        switch windguruPreference?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "c", "°c", "celsius": self = .celsius
        case "f", "°f", "fahrenheit": self = .fahrenheit
        default: return nil
        }
    }
}

public enum WaveHeightUnit: String, CaseIterable, Identifiable, Sendable {
    case meters
    case feet

    public var id: Self { self }

    public var label: String {
        switch self {
        case .meters: "m"
        case .feet: "ft"
        }
    }

    public init?(windguruPreference: String?) {
        switch windguruPreference?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "m", "meter", "meters", "metre", "metres": self = .meters
        case "ft", "foot", "feet": self = .feet
        default: return nil
        }
    }
}

public enum PressureUnit: String, CaseIterable, Identifiable, Sendable {
    case hectopascals
    case millibars
    case inchesOfMercury
    case millimetersOfMercury

    public var id: Self { self }

    public var label: String {
        switch self {
        case .hectopascals: "hPa"
        case .millibars: "mbar"
        case .inchesOfMercury: "inHg"
        case .millimetersOfMercury: "mmHg"
        }
    }
}

public enum PrecipitationUnit: String, CaseIterable, Identifiable, Sendable {
    case millimeters
    case inches

    public var id: Self { self }

    public var label: String {
        switch self {
        case .millimeters: "mm"
        case .inches: "in"
        }
    }
}

public enum FreezingLevelUnit: String, CaseIterable, Identifiable, Sendable {
    case meters
    case feet

    public var id: Self { self }

    public var label: String {
        switch self {
        case .meters: "m"
        case .feet: "ft"
        }
    }
}

public struct ForecastUnitPreferences: Equatable, Sendable {
    public let temperatureUnit: TemperatureUnit
    public let windSpeedUnit: WindSpeedUnit
    public let waveHeightUnit: WaveHeightUnit
    public let pressureUnit: PressureUnit
    public let precipitationUnit: PrecipitationUnit
    public let freezingLevelUnit: FreezingLevelUnit

    public init(temperatureUnit: TemperatureUnit, windSpeedUnit: WindSpeedUnit, waveHeightUnit: WaveHeightUnit, pressureUnit: PressureUnit, precipitationUnit: PrecipitationUnit, freezingLevelUnit: FreezingLevelUnit) {
        self.temperatureUnit = temperatureUnit
        self.windSpeedUnit = windSpeedUnit
        self.waveHeightUnit = waveHeightUnit
        self.pressureUnit = pressureUnit
        self.precipitationUnit = precipitationUnit
        self.freezingLevelUnit = freezingLevelUnit
    }
}

public protocol ForecastPreferencesProviding {
    var forecastUnitPreferences: ForecastUnitPreferences { get }
}

public struct DeviceForecastPreferenceProvider: ForecastPreferencesProviding {
    private let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    public var forecastUnitPreferences: ForecastUnitPreferences {
        let usesMetricSystem = locale.measurementSystem != .us
        return ForecastUnitPreferences(
            temperatureUnit: usesMetricSystem ? .celsius : .fahrenheit,
            windSpeedUnit: usesMetricSystem ? .kilometersPerHour : .milesPerHour,
            waveHeightUnit: usesMetricSystem ? .meters : .feet,
            pressureUnit: usesMetricSystem ? .hectopascals : .inchesOfMercury,
            precipitationUnit: usesMetricSystem ? .millimeters : .inches,
            freezingLevelUnit: usesMetricSystem ? .meters : .feet
        )
    }
}

/// Backwards-compatible access to device forecast defaults.
public enum DeviceForecastPreferences {
    private static var values: ForecastUnitPreferences { DeviceForecastPreferenceProvider().forecastUnitPreferences }

    public static var temperatureUnit: TemperatureUnit {
        values.temperatureUnit
    }

    public static var windSpeedUnit: WindSpeedUnit {
        values.windSpeedUnit
    }

    public static var waveHeightUnit: WaveHeightUnit {
        values.waveHeightUnit
    }

    public static var pressureUnit: PressureUnit {
        values.pressureUnit
    }

    public static var precipitationUnit: PrecipitationUnit {
        values.precipitationUnit
    }

    public static var freezingLevelUnit: FreezingLevelUnit {
        values.freezingLevelUnit
    }
}

public protocol VentusForecastUnitStoring: Sendable {
    func load(fallback: ForecastUnitPreferences) -> ForecastUnitPreferences
    func save(_ preferences: ForecastUnitPreferences)
}

public final class VentusForecastUnitStore: VentusForecastUnitStoring, @unchecked Sendable {
    private static let temperatureKey = "forecastUnit.temperature"
    private static let windSpeedKey = "forecastUnit.windSpeed"
    private static let waveHeightKey = "forecastUnit.waveHeight"
    private static let pressureKey = "forecastUnit.pressure"
    private static let precipitationKey = "forecastUnit.precipitation"
    private static let freezingLevelKey = "forecastUnit.freezingLevel"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load(fallback: ForecastUnitPreferences = DeviceForecastPreferenceProvider().forecastUnitPreferences) -> ForecastUnitPreferences {
        ForecastUnitPreferences(
            temperatureUnit: defaults.string(forKey: Self.temperatureKey).flatMap(TemperatureUnit.init(rawValue:)) ?? fallback.temperatureUnit,
            windSpeedUnit: defaults.string(forKey: Self.windSpeedKey).flatMap(WindSpeedUnit.init(rawValue:)) ?? fallback.windSpeedUnit,
            waveHeightUnit: defaults.string(forKey: Self.waveHeightKey).flatMap(WaveHeightUnit.init(rawValue:)) ?? fallback.waveHeightUnit,
            pressureUnit: defaults.string(forKey: Self.pressureKey).flatMap(PressureUnit.init(rawValue:)) ?? fallback.pressureUnit,
            precipitationUnit: defaults.string(forKey: Self.precipitationKey).flatMap(PrecipitationUnit.init(rawValue:)) ?? fallback.precipitationUnit,
            freezingLevelUnit: defaults.string(forKey: Self.freezingLevelKey).flatMap(FreezingLevelUnit.init(rawValue:)) ?? fallback.freezingLevelUnit
        )
    }

    public func save(_ preferences: ForecastUnitPreferences) {
        defaults.set(preferences.temperatureUnit.rawValue, forKey: Self.temperatureKey)
        defaults.set(preferences.windSpeedUnit.rawValue, forKey: Self.windSpeedKey)
        defaults.set(preferences.waveHeightUnit.rawValue, forKey: Self.waveHeightKey)
        defaults.set(preferences.pressureUnit.rawValue, forKey: Self.pressureKey)
        defaults.set(preferences.precipitationUnit.rawValue, forKey: Self.precipitationKey)
        defaults.set(preferences.freezingLevelUnit.rawValue, forKey: Self.freezingLevelKey)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}

public struct Temperature: Sendable {
    public let celsius: Double

    public init(celsius: Double) {
        self.celsius = celsius
    }

    public func value(in unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius: celsius
        case .fahrenheit: celsius * 9 / 5 + 32
        }
    }
}

public struct AtmosphericPressure: Sendable {
    public let hectopascals: Double

    public init(hectopascals: Double) {
        self.hectopascals = hectopascals
    }

    public func value(in unit: PressureUnit) -> Double {
        switch unit {
        case .hectopascals, .millibars: hectopascals
        case .inchesOfMercury: hectopascals * 0.029_529_983_071_4
        case .millimetersOfMercury: hectopascals * 0.750_061_683
        }
    }
}

public struct Precipitation: Sendable {
    public let millimeters: Double

    public init(millimeters: Double) {
        self.millimeters = millimeters
    }

    public func value(in unit: PrecipitationUnit) -> Double {
        switch unit {
        case .millimeters: millimeters
        case .inches: millimeters / 25.4
        }
    }
}

public struct FreezingLevel: Sendable {
    public let meters: Double

    public init(meters: Double) {
        self.meters = meters
    }

    public func value(in unit: FreezingLevelUnit) -> Double {
        switch unit {
        case .meters: meters
        case .feet: meters * 3.280_839_895
        }
    }
}

public struct WaveHeight: Sendable {
    public let meters: Double

    public init(meters: Double) {
        self.meters = meters
    }

    public func value(in unit: WaveHeightUnit) -> Double {
        switch unit {
        case .meters: meters
        case .feet: meters * 3.280_839_895
        }
    }
}
