//
//  SettingsView.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 07/31/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

/// Device settings that are available regardless of Windguru account status.
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var weatherBackgroundStyle: WeatherBackgroundStyle
    @Binding private var forecastViewMode: ForecastViewMode
    @Binding private var theme: VentusTheme
    @Binding private var appLanguage: AppLanguage
    @State private var notificationsEnabled = ForecastSevereWeatherNotificationsStore.load()
#if !os(watchOS)
    private let forecastService: ForecastWindguruProtocol
    private let account: WindguruAccount
#endif

#if !os(watchOS)
    public init(
        weatherBackgroundStyle: Binding<WeatherBackgroundStyle>,
        forecastViewMode: Binding<ForecastViewMode>,
        theme: Binding<VentusTheme>,
        appLanguage: Binding<AppLanguage>,
        forecastService: ForecastWindguruProtocol,
        account: WindguruAccount
    ) {
        _weatherBackgroundStyle = weatherBackgroundStyle
        _forecastViewMode = forecastViewMode
        _theme = theme
        _appLanguage = appLanguage
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
                    Text("Layout")
                } footer: {
                    Text("Choose the default presentation for forecasts on this device.")
                }

                Section {
                    Picker("Weather background", selection: $weatherBackgroundStyle) {
                        ForEach(WeatherBackgroundStyle.allCases) { style in
                            Label(style.title, systemImage: style.systemImage)
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
                            Text(language.title).tag(language)
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
        // appLanguage is persisted synchronously in the binding passed down
        // from the presenting view (see ForecastDashboardView), not here —
        // it must apply before the next render, not after, or the frame
        // right after switching still shows the old language.
        .onChange(of: notificationsEnabled) { _, isEnabled in
            ForecastSevereWeatherNotificationsStore.save(isEnabled)
        }
        .forecastAccessibilityContainer(
            "Settings",
            hint: "Choose appearance, forecast layout, and weather animation preferences.",
            identifier: "settings"
        )
    }
}

#if !os(watchOS)
#Preview {
    SettingsView(
        weatherBackgroundStyle: .constant(.lottieAdriana),
        forecastViewMode: .constant(.dashboard),
        theme: .constant(.system),
        appLanguage: .constant(.system),
        forecastService: ForecastWindguruMockup(),
        account: WindguruAccount()
    )
}
#else
#Preview {
    SettingsView(
        weatherBackgroundStyle: .constant(.lottieAdriana),
        forecastViewMode: .constant(.dashboard),
        theme: .constant(.system),
        appLanguage: .constant(.system)
    )
}
#endif
