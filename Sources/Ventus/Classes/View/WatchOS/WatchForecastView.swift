//
//  WatchForecastView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/02/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if os(watchOS)
import SwiftUI

public struct WatchForecastView: View {
    nonisolated(unsafe) private let forecastService: ForecastWindguruProtocol
    private let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("watchSelectedWindguruSpotID") private var selectedSpotID = SavedMapLocationStore.primarySpotID
    @AppStorage("watchTemperatureUnit") private var temperatureUnitRaw = DeviceForecastPreferences.temperatureUnit.rawValue
    @AppStorage("watchWindSpeedUnit") private var windSpeedUnitRaw = DeviceForecastPreferences.windSpeedUnit.rawValue
    @AppStorage("watchWaveHeightUnit") private var waveHeightUnitRaw = DeviceForecastPreferences.waveHeightUnit.rawValue
    @AppStorage("watchPressureUnit") private var pressureUnitRaw = DeviceForecastPreferences.pressureUnit.rawValue
    @AppStorage("watchPrecipitationUnit") private var precipitationUnitRaw = DeviceForecastPreferences.precipitationUnit.rawValue
    @AppStorage("watchFreezingLevelUnit") private var freezingLevelUnitRaw = DeviceForecastPreferences.freezingLevelUnit.rawValue
    @State private var locations: [WatchLocation]
    @State private var forecast: SpotForecast?
    @State private var errorMessage: String?
    @State private var selectedHour: String?
    @State private var selectedModelID: String?
    @State private var crownHourIndex = 0.0
    @State private var navigationPath = NavigationPath()
    @State private var theme: VentusTheme
    @State private var appLanguage: AppLanguage

    public init(forecastService: ForecastWindguruProtocol = ForecastWindguruService(), environment: AppEnvironment) {
        self.forecastService = forecastService
        self.environment = environment
        _locations = State(initialValue: environment.watchLocationStore.load())
        _theme = State(initialValue: environment.ventusThemeStore.load())
        _appLanguage = State(initialValue: environment.appLanguageStore.load())
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let forecast {
                    dashboard(for: forecast)
                } else if let errorMessage {
                    ContentUnavailableView("Forecast unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ProgressView()
                }
            }
            .navigationDestination(for: WatchDestination.self) { destination in
                switch destination {
                case .locations:
                    WatchLocationPicker(
                        locations: locations,
                        selectedSpotID: selectedSpotID,
                        forecastService: forecastService,
                        select: select,
                        add: add
                    )
                case .hours:
                    WatchForecastHoursView(forecast: forecast, selectedHour: $selectedHour, temperatureUnit: temperatureUnit, windSpeedUnit: windSpeedUnit, precipitationUnit: precipitationUnit) {
                        navigationPath = NavigationPath()
                    }
                case .days:
                    WatchForecastDaysView(forecast: forecast, temperatureUnit: temperatureUnit) { hour in
                        selectedHour = hour
                        navigationPath = NavigationPath()
                    }
                case .settings:
                    WatchForecastSettingsView(forecastService: forecastService, temperatureUnitRaw: $temperatureUnitRaw, windSpeedUnitRaw: $windSpeedUnitRaw, waveHeightUnitRaw: $waveHeightUnitRaw, pressureUnitRaw: $pressureUnitRaw, precipitationUnitRaw: $precipitationUnitRaw, freezingLevelUnitRaw: $freezingLevelUnitRaw, appLanguage: $appLanguage)
                case .models:
                    if let forecast {
                        WatchForecastModelPicker(forecast: forecast, selectedModelID: selectedModelID, select: selectModel)
                    }
                }
            }
        }
        .modifier(VentusThemeModifier(theme: theme))
        .appLanguage(appLanguage)
        .task { await loadForecast() }
        .onChange(of: selectedSpotID) { _, _ in Task { await loadForecast() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                theme = environment.ventusThemeStore.load()
            }
        }
        .onChange(of: appLanguage) { _, appLanguage in
            environment.appLanguageStore.save(appLanguage)
        }
        .id(appLanguage)
    }

    private func dashboard(for forecast: SpotForecast) -> some View {
        let hour = selectedHour ?? forecast.currentForecastHour
        let weather = forecast.forecast
        return ScrollView {
            VStack(spacing: 10) {
                if let severeWeatherAlert = environment.severeWeatherNotifier.evaluate(forecast) {
                    Label(severeWeatherAlert.title, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                let _ = environment.severeWeatherNotifier.evaluateCustomAlerts(forecast)
                HStack(spacing: 8) {
                NavigationLink(value: WatchDestination.locations) { Image(systemName: "mappin.circle.fill") }.accessibilityLabel("Choose location")
                NavigationLink(value: WatchDestination.settings) { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                Button { Task { await loadForecast() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh forecast")
                    .handGestureShortcut(.primaryAction)
                }
                .font(.caption)

                Text(forecast.asCurrentLocation ?? selectedLocation?.name ?? "Forecast")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    NavigationLink(value: WatchDestination.hours) {
                        Label(hourTitle(forecast, hour: hour), systemImage: "clock")
                    }
                    NavigationLink(value: WatchDestination.days) {
                        Label("Days", systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let sunrise = forecast.sunrise, let sunset = forecast.sunset {
                    HStack(spacing: 14) {
                        Label(sunrise, systemImage: "sunrise.fill")
                        Label(sunset, systemImage: "sunset.fill")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sunrise at \(sunrise). Sunset at \(sunset).")
                    .accessibilityIdentifier("watch.forecast.daylight")
                }

                HStack(spacing: 5) {
                    ForEach(forecast.weatherSymbolNames(hour: hour), id: \.self) { Image(systemName: $0) }
                }
                .font(.title2)
                Text(temperature(weather?.temperatureReal(hh: hour) ?? weather?.temperature(hh: hour)))
                    .font(.system(.title2, design: .rounded).weight(.semibold))

                Text(conditionText(for: forecast, hour: hour))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if let range = forecast.dailyTemperatureRange(hour: hour) {
                    HStack(spacing: 12) {
                        Label(temperature(range.low), systemImage: "thermometer.low")
                        Label(temperature(range.high), systemImage: "thermometer.high")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Daily low \(temperature(range.low)). High \(temperature(range.high)).")
                }

                hourlyOutlook(for: forecast, selectedHour: hour)

                HStack(spacing: 12) {
                    metric("Wind", value: wind(weather?.windSpeed(hh: hour)), symbol: "wind")
                    metric("Gusts", value: wind(weather?.windGustsKnots(hh: hour)), symbol: "wind.circle")
                    directionMetric("Direction", degrees: weather?.windDirection(hh: hour))
                }
                
                HStack(spacing: 12) {
                    metric("Cloud", value: percentage(weather?.cloudCoverTotal(hh: hour)), symbol: "cloud")
                    metric("Rain", value: precipitation(weather?.precipitation(hh: hour) ?? weather?.precipitation1(hh: hour)), symbol: "drop")
                    metric("Humidity", value: percentage(weather?.relativeHumidity(hh: hour)), symbol: "humidity")
                }

                HStack(spacing: 12) {
                    metric("Pressure", value: pressure(weather?.seaLevelPressure(hh: hour)), symbol: "gauge.medium")
                    metric("Isotherm", value: freezingLevel(weather?.freezingLevelHeightInMeters(hh: hour)), symbol: "thermometer.medium", celsius: weather?.temperatureReal(hh: hour) ?? weather?.temperature(hh: hour))
                    metric("Waves", value: waveHeight(weather?.waveHeight(hh: hour)), symbol: "water.waves")
                }

                NavigationLink(value: WatchDestination.models) {
                    Label(weather?.modelName ?? "Forecast model", systemImage: "cpu")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .multilineTextAlignment(.center)
        .digitalCrownRotation(
            $crownHourIndex,
            from: 0,
            through: Double(max(forecast.availableForecastHours.count - 1, 0)),
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear { syncCrownHourIndex(for: forecast) }
        .onChange(of: crownHourIndex) { _, index in
            selectHour(at: Int(index.rounded()), in: forecast)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    moveSelectedHour(by: value.translation.width < 0 ? 1 : -1, in: forecast)
                }
        )
        .forecastAccessibilityContainer(
            ForecastAccessibility.summary(for: forecast, hour: hour),
            hint: "Use the controls to change location, settings, refresh, choose an hour, or select a forecast model.",
            identifier: "watch.forecast.dashboard"
        )
    }

    @MainActor private func loadForecast() async {
        do {
            errorMessage = nil
            forecast = try await forecastService.bestForecast(bySpotId: selectedSpotID, model: nil)
            selectedHour = forecast?.currentForecastHour
            selectedModelID = forecast?.model
            if let forecast {
                _ = environment.severeWeatherNotifier.evaluate(forecast)
                environment.severeWeatherNotifier.evaluateCustomAlerts(forecast)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var selectedLocation: WatchLocation? { locations.first { $0.spotID == selectedSpotID } }
    private func select(_ location: WatchLocation) { selectedSpotID = location.spotID }
    private func add(_ location: WatchLocation) {
        if !locations.contains(where: { $0.spotID == location.spotID }) {
            locations.append(location)
            environment.watchLocationStore.save(locations)
        }
        selectedSpotID = location.spotID
    }

    private var temperatureUnit: TemperatureUnit { TemperatureUnit(rawValue: temperatureUnitRaw) ?? DeviceForecastPreferences.temperatureUnit }
    private var windSpeedUnit: WindSpeedUnit { WindSpeedUnit(rawValue: windSpeedUnitRaw) ?? DeviceForecastPreferences.windSpeedUnit }
    private var waveHeightUnit: WaveHeightUnit { WaveHeightUnit(rawValue: waveHeightUnitRaw) ?? DeviceForecastPreferences.waveHeightUnit }
    private var pressureUnit: PressureUnit { PressureUnit(rawValue: pressureUnitRaw) ?? DeviceForecastPreferences.pressureUnit }
    private var precipitationUnit: PrecipitationUnit { PrecipitationUnit(rawValue: precipitationUnitRaw) ?? DeviceForecastPreferences.precipitationUnit }
    private var freezingLevelUnit: FreezingLevelUnit { FreezingLevelUnit(rawValue: freezingLevelUnitRaw) ?? DeviceForecastPreferences.freezingLevelUnit }
    private func temperature(_ value: Double?) -> String { WatchForecastFormatting.temperature(value, unit: temperatureUnit) }
    private func wind(_ value: Double?) -> String { WatchForecastFormatting.wind(value, unit: windSpeedUnit) }
    private func precipitation(_ value: Double?) -> String {
        value.map { "\(Precipitation(millimeters: $0).value(in: precipitationUnit).formatted(.number.precision(.fractionLength(0)))) \(precipitationUnit.label)" } ?? "—"
    }
    private func percentage(_ value: Int?) -> String { value.map { "\($0)%" } ?? "—" }
    private func pressure(_ value: Double?) -> String {
        value.map { "\(AtmosphericPressure(hectopascals: $0).value(in: pressureUnit).formatted(.number.precision(.fractionLength(pressureUnit == .inchesOfMercury ? 2 : 0)))) \(pressureUnit.label)" } ?? "—"
    }
    private func freezingLevel(_ value: Double?) -> String {
        value.map { "\(FreezingLevel(meters: $0).value(in: freezingLevelUnit).formatted(.number.precision(.fractionLength(0)))) \(freezingLevelUnit.label)" } ?? "—"
    }
    private func waveHeight(_ value: Double?) -> String {
        value.map { "\(WaveHeight(meters: $0).value(in: waveHeightUnit).formatted(.number.precision(.fractionLength(1)))) \(waveHeightUnit.label)" } ?? "—"
    }
    private func selectModel(_ modelID: String) {
        forecast?.currentModel = modelID
        selectedModelID = modelID
        selectedHour = forecast?.currentForecastHour
    }
    private func metric(_ title: String, value: String, symbol: String, celsius: Double? = nil) -> some View {
        VStack(spacing: 2) {
            if let celsius {
                let palette = TemperatureColorScale.palette(forCelsius: celsius)
                Image(systemName: symbol)
                    .font(.caption2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(palette.primary, palette.secondary)
            } else {
                Image(systemName: symbol).font(.caption2)
            }
            Text(value).font(.caption2.monospacedDigit())
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func directionMetric(_ title: String, degrees: Double?) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.down")
                .font(.caption2)
                .rotationEffect(.degrees(degrees ?? 0))
            Text(degrees.map { "\(Int($0.rounded()))°" } ?? "—").font(.caption2.monospacedDigit())
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func hourTitle(_ forecast: SpotForecast, hour: String?) -> String {
        guard let hour, let date = forecast.forecastDate(hour: hour) else { return "Select hour" }
        return WatchForecastFormatting.hour(date)
    }

    private func conditionText(for forecast: SpotForecast, hour: String?) -> String {
        let symbols = forecast.weatherSymbolNames(hour: hour)
        if symbols.contains(where: { $0.contains("snow") }) { return "Snow" }
        if symbols.contains(where: { $0.contains("rain") || $0.contains("drizzle") }) { return "Rain" }
        if symbols.contains(where: { $0.contains("fog") }) { return "Foggy" }
        if symbols.contains("cloud.fill") { return "Overcast" }
        if symbols.contains(where: { $0.hasPrefix("cloud.sun") || $0.hasPrefix("cloud.moon") }) { return "Partly cloudy" }
        if symbols.contains("cloud") { return "Cloudy" }
        if symbols.contains(where: { $0.hasPrefix("wind") || $0.hasPrefix("tornado") }) { return "Windy" }
        return "Clear"
    }

    private func hourlyOutlook(for forecast: SpotForecast, selectedHour: String?) -> some View {
        let selectedOffset = Int(selectedHour ?? "") ?? 0
        let hours = forecast.availableForecastHours
            .filter { (Int($0) ?? 0) >= selectedOffset }
            .prefix(4)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(hours), id: \.self) { hour in
                    VStack(spacing: 3) {
                        Text(hourTitle(forecast, hour: hour))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: forecast.weatherSymbolName(hour: hour))
                            .font(.caption)
                        Text(temperature(forecast.forecast?.temperatureReal(hh: hour) ?? forecast.forecast?.temperature(hh: hour)))
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(width: 46)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(hourTitle(forecast, hour: hour)). \(conditionText(for: forecast, hour: hour)). \(temperature(forecast.forecast?.temperatureReal(hh: hour) ?? forecast.forecast?.temperature(hh: hour))).")
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 58)
        .accessibilityIdentifier("watch.forecast.hourlyOutlook")
    }

    private func moveSelectedHour(by offset: Int, in forecast: SpotForecast) {
        let hours = forecast.availableForecastHours
        guard !hours.isEmpty else { return }
        let currentIndex = hours.firstIndex(of: selectedHour ?? forecast.currentForecastHour ?? hours[0]) ?? 0
        let destination = min(max(currentIndex + offset, 0), hours.count - 1)
        selectedHour = hours[destination]
        crownHourIndex = Double(destination)
    }

    private func selectHour(at index: Int, in forecast: SpotForecast) {
        guard forecast.availableForecastHours.indices.contains(index) else { return }
        selectedHour = forecast.availableForecastHours[index]
    }

    private func syncCrownHourIndex(for forecast: SpotForecast) {
        let currentHour = selectedHour ?? forecast.currentForecastHour
        crownHourIndex = Double(forecast.availableForecastHours.firstIndex(of: currentHour ?? "") ?? 0)
    }
}

enum WatchDestination: Hashable { case locations, hours, days, settings, models }

enum WatchForecastFormatting {
    /// Uses the system's 12/24-hour preference while keeping the watch label concise.
    static func hour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        let hourTemplate = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .autoupdatingCurrent) ?? "H"
        formatter.dateFormat = hourTemplate.contains("H") || hourTemplate.contains("k") ? "EEE, HH'h'" : "EEE, h a"
        return formatter.string(from: date).replacingOccurrences(of: " AM", with: "am").replacingOccurrences(of: " PM", with: "pm")
    }

    static func temperature(_ value: Double?, unit: TemperatureUnit) -> String {
        guard let value else { return "—" }
        let converted = unit == .fahrenheit ? value * 9 / 5 + 32 : value
        return "\(converted.formatted(.number.precision(.fractionLength(0))))\(unit.label)"
    }
    static func wind(_ value: Double?, unit: WindSpeedUnit) -> String {
        guard let value else { return "—" }
        let converted: Double
        switch unit {
        case .knots: converted = value
        case .metersPerSecond: converted = value * 0.514_444
        case .kilometersPerHour: converted = value * 1.852
        case .milesPerHour: converted = value * 1.150_78
        case .beaufort: converted = min(12, (value / 3.01).rounded())
        }
        return "\(converted.formatted(.number.precision(.fractionLength(0)))) \(unit.label)"
    }
}

#if DEBUG
#Preview("Watch forecast dashboard") {
    WatchForecastView(forecastService: ForecastWindguruMockup(), environment: .preview)
}
#endif

#endif
