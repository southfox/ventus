//
//  SettingsView.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 07/31/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Binding private var weatherBackgroundStyle: WeatherBackgroundStyle
    @Binding private var forecastViewMode: ForecastViewMode
    @Binding private var theme: VentusTheme
    @Binding private var appLanguage: AppLanguage
    @State private var notificationsEnabled = ForecastSevereWeatherNotificationsStore.load()
#if !os(watchOS)
    @Binding private var gridHourStep: Int
    private let forecastService: ForecastWindguruProtocol
    private let account: WindguruAccount
#endif

#if !os(watchOS)
    public init(
        weatherBackgroundStyle: Binding<WeatherBackgroundStyle>,
        forecastViewMode: Binding<ForecastViewMode>,
        theme: Binding<VentusTheme>,
        appLanguage: Binding<AppLanguage>,
        gridHourStep: Binding<Int>,
        forecastService: ForecastWindguruProtocol,
        account: WindguruAccount
    ) {
        _weatherBackgroundStyle = weatherBackgroundStyle
        _forecastViewMode = forecastViewMode
        _theme = theme
        _appLanguage = appLanguage
        _gridHourStep = gridHourStep
        self.forecastService = forecastService
        self.account = account
    }
#else
    public init(
        weatherBackgroundStyle: Binding<WeatherBackgroundStyle>,
        forecastViewMode: Binding<ForecastViewMode>,
        theme: Binding<VentusTheme>,
        appLanguage: Binding<AppLanguage>
    ) {
        _weatherBackgroundStyle = weatherBackgroundStyle
        _forecastViewMode = forecastViewMode
        _theme = theme
        _appLanguage = appLanguage
    }
#endif

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Forecast view", selection: $forecastViewMode) {
                        ForEach(ForecastViewMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Layout".localized)
                } footer: {
                    Text("Choose the default presentation for forecasts on this device.".localized)
                }

#if !os(watchOS)
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(gridHourStep == 1 ? "Hourly".localized : "Every %lld hours".localized(formatArguments: [gridHourStep]))
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(get: { Double(gridHourStep) }, set: { gridHourStep = Int($0.rounded()) }),
                            in: Double(GridHourStepStore.range.lowerBound)...Double(GridHourStepStore.range.upperBound),
                            step: 1
                        ) {
                            Text("Forecast hour step".localized)
                        } minimumValueLabel: {
                            Text("1")
                        } maximumValueLabel: {
                            Text("6")
                        }
                    }
                } header: {
                    Text("Forecast hours".localized)
                } footer: {
                    Text("How many hours apart forecast columns and hour pickers are, across the app and other devices.".localized)
                }
#endif

                Section {
                    Picker("Weather background", selection: $weatherBackgroundStyle) {
                        ForEach(WeatherBackgroundStyle.allCases) { style in
                            Label(style.title.localized, systemImage: style.systemImage)
                                .tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Animations")
                } footer: {
                    Text("The selected animation is used as the forecast background on this device.")
                }

                Section {
                    Picker("Theme", selection: $theme) {
                        ForEach(VentusTheme.allCases) { theme in
                            Label(theme.title, systemImage: "paintpalette")
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Themes change colors and font design without changing text sizes. System Default follows the current device appearance.")
                }

                Section {
                    Picker("Language", selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title(locale: locale)).tag(language)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Language")
                } footer: {
                    Text("System follows the device's language. Choosing a language overrides it for Ventus only.")
                }

                Section {
                    Toggle("Severe weather alerts", isOn: $notificationsEnabled)
#if !os(watchOS)
                    NavigationLink {
                        ForecastAlertsListView(forecastService: forecastService, account: account)
                    } label: {
                        Label("Forecast Alerts", systemImage: "bell.badge")
                    }
#endif
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get notified about heavy snow, extreme cold, or extreme heat forecast near your selected location, or set up your own push alerts for specific spots, models, and conditions.")
                }

            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: weatherBackgroundStyle) { _, style in
            WeatherBackgroundStyleStore.save(style)
        }
        .onChange(of: forecastViewMode) { _, mode in
            ForecastViewModeStore.save(mode)
        }
        .onChange(of: theme) { _, theme in
            VentusThemeStore.save(theme)
        }
        .onChange(of: appLanguage) { _, appLanguage in
            AppLanguageStore.save(appLanguage)
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            ForecastSevereWeatherNotificationsStore.save(isEnabled)
        }
#if !os(watchOS)
        .onChange(of: gridHourStep) { _, step in
            GridHourStepStore.save(step)
        }
#endif
        .forecastAccessibilityContainer(
            "Settings",
            hint: "Choose appearance, forecast layout, and weather animation preferences.",
            identifier: "settings"
        )
    }
}

#if os(watchOS)
#Preview("watchos") {
    SettingsView(
        weatherBackgroundStyle: .constant(.lottieAdriana),
        forecastViewMode: .constant(.dashboard),
        theme: .constant(.system),
        appLanguage: .constant(.system)
    )
}
#else
#Preview {
    SettingsView(
        weatherBackgroundStyle: .constant(.lottieAdriana),
        forecastViewMode: .constant(.dashboard),
        theme: .constant(.system),
        appLanguage: .constant(.system),
        gridHourStep: .constant(1),
        forecastService: ForecastWindguruMockup(),
        account: WindguruAccount()
    )
}
#endif
