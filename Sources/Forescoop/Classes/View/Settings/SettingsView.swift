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
    @Environment(\.locale) private var locale
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
                    Text("Layout".localized)
                } footer: {
                    Text("Choose the default presentation for forecasts on this device.".localized)
                }

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
            // Bundle.main-backed lookups (Text and String(localized:)) don't
            // reliably re-resolve just because `\.locale` changed on an
            // already-rendered view, so the root view is given a fresh
            // identity via `.id(appLanguage)` to force every localized
            // string to be read again from scratch.
            AppLanguageStore.save(appLanguage)
        }
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
