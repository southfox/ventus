//
//  SettingsView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 07/31/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.appEnvironment) private var environment
    @Binding private var weatherBackgroundStyle: WeatherBackgroundStyle
    @Binding private var forecastViewMode: ForecastViewMode
    @Binding private var theme: VentusTheme
    @Binding private var appLanguage: AppLanguage
    @Binding private var appAppearanceMode: AppAppearanceMode
    @State private var notificationsEnabled: Bool
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
        appAppearanceMode: Binding<AppAppearanceMode>,
        gridHourStep: Binding<Int>,
        forecastService: ForecastWindguruProtocol,
        account: WindguruAccount,
        environment: AppEnvironment
    ) {
        _weatherBackgroundStyle = weatherBackgroundStyle
        _forecastViewMode = forecastViewMode
        _theme = theme
        _appLanguage = appLanguage
        _appAppearanceMode = appAppearanceMode
        _gridHourStep = gridHourStep
        self.forecastService = forecastService
        self.account = account
        _notificationsEnabled = State(initialValue: environment.forecastSevereWeatherNotificationsStore.load())
    }
#else
    public init(
        weatherBackgroundStyle: Binding<WeatherBackgroundStyle>,
        forecastViewMode: Binding<ForecastViewMode>,
        theme: Binding<VentusTheme>,
        appLanguage: Binding<AppLanguage>,
        appAppearanceMode: Binding<AppAppearanceMode>,
        environment: AppEnvironment
    ) {
        _weatherBackgroundStyle = weatherBackgroundStyle
        _forecastViewMode = forecastViewMode
        _theme = theme
        _appLanguage = appLanguage
        _appAppearanceMode = appAppearanceMode
        _notificationsEnabled = State(initialValue: environment.forecastSevereWeatherNotificationsStore.load())
    }
#endif

    public var body: some View {
        NavigationStack {
            Group {
#if os(macOS)
                macColumnsBody
#elseif os(tvOS)
                tvSettingsBody
#else
                Form {
                    layoutSection
#if !os(watchOS)
                    forecastHoursSection
#endif
                    animationsSection
                    displaySection
                    appearanceSection
                    languageSection
                    notificationsSection
                }
#endif
            }
            .navigationTitle("Settings".localized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done".localized) { dismiss() }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 720, idealWidth: 760, minHeight: 480, idealHeight: 560)
#endif
        .onChange(of: weatherBackgroundStyle) { _, style in
            environment.weatherBackgroundStyleStore.save(style)
            environment.analytics.log(.weatherBackgroundChanged(style.rawValue))
        }
        .onChange(of: forecastViewMode) { _, mode in
            environment.forecastViewModeStore.save(mode)
            environment.analytics.log(.viewModeChanged(mode.rawValue))
        }
        .onChange(of: theme) { _, theme in
            environment.ventusThemeStore.save(theme)
            environment.analytics.log(.themeChanged(theme.rawValue))
        }
        .onChange(of: appLanguage) { _, appLanguage in
            environment.appLanguageStore.save(appLanguage)
            environment.analytics.log(.languageChanged(appLanguage.rawValue))
        }
        .onChange(of: appAppearanceMode) { _, mode in
            environment.appAppearanceModeStore.save(mode)
            environment.analytics.log(.appearanceModeChanged(mode.rawValue))
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            environment.forecastSevereWeatherNotificationsStore.save(isEnabled)
        }
#if !os(watchOS)
        .onChange(of: gridHourStep) { _, step in
            environment.gridHourStepStore.save(step)
        }
#endif
        .forecastAccessibilityContainer(
            "Settings",
            hint: "Choose appearance, forecast layout, and weather animation preferences.",
            identifier: "settings"
        )
        .trackScreenView("Settings")
    }

    // MARK: - macOS two-column layout

#if os(macOS)
    @ViewBuilder
    private var macColumnsBody: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 22) {
                    macGroup(header: "Layout".localized, footer: "Choose the default presentation for forecasts on this device.".localized) {
                        layoutPicker
                    }
                    macGroup(header: "Forecast hours".localized, footer: "How many hours apart forecast columns and hour pickers are, across the app and other devices.".localized) {
                        forecastHourStepControl
                    }
                    macGroup(header: "Animations".localized, footer: "The selected animation is used as the forecast background on this device.".localized) {
                        weatherBackgroundPicker
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 22) {
                    macGroup(header: "Display".localized, footer: "System follows this device's Light or Dark appearance setting.".localized) {
                        appearanceModePicker
                    }
                    macGroup(header: "Appearance".localized, footer: "Themes change colors and font design without changing text sizes. System Default follows the current device appearance.".localized) {
                        themePicker
                    }
                    macGroup(header: "Language".localized, footer: "System follows the device's language. Choosing a language overrides it for Ventus only.".localized) {
                        languagePicker
                    }
                    macGroup(header: "Notifications".localized, footer: "Get notified about heavy snow, extreme cold, or extreme heat forecast near your selected location, or set up your own push alerts for specific spots, models, and conditions.".localized) {
                        notificationsControls
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
    }

    private func macGroup<Content: View>(
        header: String,
        footer: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header).font(.headline)
            GroupBox {
                content()
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(footer)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
#endif

    // MARK: - Shared section content

#if os(tvOS)
    /// tvOS does not present inline `Picker`s compactly: their focus treatment
    /// becomes a full-width, glassy band. Keep the settings overview as a
    /// concise list and push each set of choices onto its own focused screen.
    private var tvSettingsBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                tvSettingsSection("Layout".localized) {
                    NavigationLink {
                        tvChoiceList(
                            title: "Forecast view".localized,
                            selection: $forecastViewMode,
                            options: ForecastViewMode.availableCases,
                            label: { $0.title.localized },
                            symbol: { $0.systemImage }
                        )
                    } label: {
                        tvSettingsRow(
                            title: "Forecast view".localized,
                            value: forecastViewMode.title.localized,
                            symbol: forecastViewMode.systemImage
                        )
                    }
                }

                tvSettingsSection("Forecast hours".localized) {
                    NavigationLink {
                        tvHourStepPicker
                    } label: {
                        tvSettingsRow(
                            title: "Forecast hour step".localized,
                            value: gridHourStep == 1 ? "Hourly".localized : "Every %lld hours".localized(formatArguments: [gridHourStep]),
                            symbol: "clock"
                        )
                    }
                }

                tvSettingsSection("Appearance".localized) {
                    NavigationLink {
                        tvChoiceList(title: "Weather background".localized, selection: $weatherBackgroundStyle, options: WeatherBackgroundStyle.allCases, label: { $0.title.localized }, symbol: { $0.systemImage })
                    } label: {
                        tvSettingsRow(title: "Weather background".localized, value: weatherBackgroundStyle.title.localized, symbol: weatherBackgroundStyle.systemImage)
                    }
                    NavigationLink {
                        tvChoiceList(title: "Display".localized, selection: $appAppearanceMode, options: AppAppearanceMode.allCases, label: { $0.title.localized }, symbol: { _ in "circle.lefthalf.filled" })
                    } label: {
                        tvSettingsRow(title: "Display".localized, value: appAppearanceMode.title.localized, symbol: "circle.lefthalf.filled")
                    }
                    NavigationLink {
                        tvChoiceList(title: "Theme".localized, selection: $theme, options: VentusTheme.allCases, label: { $0.title.localized }, symbol: { _ in "paintpalette" })
                    } label: {
                        tvSettingsRow(title: "Theme".localized, value: theme.title.localized, symbol: "paintpalette")
                    }
                }

                tvSettingsSection("Language".localized) {
                    NavigationLink {
                        tvChoiceList(title: "Language".localized, selection: $appLanguage, options: AppLanguage.allCases, label: { $0.title(locale: locale) }, symbol: { _ in "globe" })
                    } label: {
                        tvSettingsRow(title: "Language".localized, value: appLanguage.title(locale: locale), symbol: "globe")
                    }
                }

                tvSettingsSection("Notifications".localized) {
                    Button {
                        notificationsEnabled.toggle()
                    } label: {
                        tvSettingsRow(
                            title: "Severe weather alerts".localized,
                            value: notificationsEnabled ? "On".localized : "Off".localized,
                            symbol: notificationsEnabled ? "bell.badge.fill" : "bell.slash"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 84)
            .padding(.vertical, 36)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    private func tvSettingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                content()
            }
        }
    }

    private func tvSettingsRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: symbol)
                .frame(width: 28)
                .font(.title3)
            Text(title)
                .font(.title3)
            Spacer(minLength: 20)
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 22)
        .frame(height: 68)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tvChoiceList<Option: Identifiable & Hashable>(
        title: String,
        selection: Binding<Option>,
        options: [Option],
        label: @escaping (Option) -> String,
        symbol: @escaping (Option) -> String
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option
                        dismiss()
                    } label: {
                        HStack(spacing: 18) {
                            Image(systemName: symbol(option)).frame(width: 28)
                            Text(label(option)).font(.title3)
                            Spacer()
                            if selection.wrappedValue == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 22)
                        .frame(height: 68)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(48)
            .frame(maxWidth: 900)
        }
        .navigationTitle(title)
    }

    private var tvHourStepPicker: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(GridHourStepStore.range), id: \.self) { step in
                    Button {
                        gridHourStep = step
                        dismiss()
                    } label: {
                        HStack {
                            Text(step == 1 ? "Hourly".localized : "Every %lld hours".localized(formatArguments: [step]))
                                .font(.title3)
                            Spacer()
                            if gridHourStep == step {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 22)
                        .frame(height: 68)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(48)
            .frame(maxWidth: 900)
        }
        .navigationTitle("Forecast hour step".localized)
    }
#endif

    private var layoutPicker: some View {
        Picker("Forecast view".localized, selection: $forecastViewMode) {
            ForEach(ForecastViewMode.availableCases) { mode in
                Label(mode.title.localized, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.inline)
    }

    private var layoutSection: some View {
        Section {
            layoutPicker
        } header: {
            Text("Layout".localized)
        } footer: {
            Text("Choose the default presentation for forecasts on this device.".localized)
        }
    }

#if !os(watchOS)
    private var forecastHourStepControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gridHourStep == 1 ? "Hourly".localized : "Every %lld hours".localized(formatArguments: [gridHourStep]))
                .foregroundStyle(.secondary)
#if os(tvOS)
            Picker("Forecast hour step".localized, selection: $gridHourStep) {
                ForEach(Array(GridHourStepStore.range), id: \.self) { step in
                    Text("\(step)").tag(step)
                }
            }
#else
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
#endif
        }
    }

    private var forecastHoursSection: some View {
        Section {
            forecastHourStepControl
        } header: {
            Text("Forecast hours".localized)
        } footer: {
            Text("How many hours apart forecast columns and hour pickers are, across the app and other devices.".localized)
        }
    }
#endif

    private var weatherBackgroundPicker: some View {
        Picker("Weather background".localized, selection: $weatherBackgroundStyle) {
            ForEach(WeatherBackgroundStyle.allCases) { style in
                Label(style.title.localized, systemImage: style.systemImage)
                    .tag(style)
            }
        }
        .pickerStyle(.inline)
    }

    private var animationsSection: some View {
        Section {
            weatherBackgroundPicker
        } header: {
            Text("Animations".localized)
        } footer: {
            Text("The selected animation is used as the forecast background on this device.".localized)
        }
    }

    private var appearanceModePicker: some View {
        Picker("Appearance".localized, selection: $appAppearanceMode) {
            ForEach(AppAppearanceMode.allCases) { mode in
                Label(mode.title.localized, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.inline)
    }

    private var displaySection: some View {
        Section {
            appearanceModePicker
        } header: {
            Text("Display".localized)
        } footer: {
            Text("System follows this device's Light or Dark appearance setting.".localized)
        }
    }

    private var themePicker: some View {
        Picker("Theme".localized, selection: $theme) {
            ForEach(VentusTheme.allCases) { theme in
                Label(theme.title.localized, systemImage: "paintpalette")
                    .tag(theme)
            }
        }
        .pickerStyle(.inline)
    }

    private var appearanceSection: some View {
        Section {
            themePicker
        } header: {
            Text("Appearance".localized)
        } footer: {
            Text("Themes change colors and font design without changing text sizes. System Default follows the current device appearance.".localized)
        }
    }

    private var languagePicker: some View {
        Picker("Language".localized, selection: $appLanguage) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.title(locale: locale)).tag(language)
            }
        }
        .pickerStyle(.inline)
    }

    private var languageSection: some View {
        Section {
            languagePicker
        } header: {
            Text("Language".localized)
        } footer: {
            Text("System follows the device's language. Choosing a language overrides it for Ventus only.".localized)
        }
    }

    @ViewBuilder
    private var notificationsControls: some View {
        Toggle("Severe weather alerts".localized, isOn: $notificationsEnabled)
#if !os(watchOS)
        NavigationLink {
            ForecastAlertsListView(forecastService: forecastService, account: account, environment: environment)
        } label: {
            Label("Forecast Alerts".localized, systemImage: "bell.badge")
        }
#endif
    }

    private var notificationsSection: some View {
        Section {
            notificationsControls
        } header: {
            Text("Notifications".localized)
        } footer: {
            Text("Get notified about heavy snow, extreme cold, or extreme heat forecast near your selected location, or set up your own push alerts for specific spots, models, and conditions.".localized)
        }
    }
}

#if os(watchOS)
#Preview("watchos") {
    SettingsView(
        weatherBackgroundStyle: .constant(.lottieAdriana),
        forecastViewMode: .constant(.dashboard),
        theme: .constant(.system),
        appLanguage: .constant(.system),
        appAppearanceMode: .constant(.system),
        environment: .preview
    )
}
#else
#Preview {
    SettingsView(
        weatherBackgroundStyle: .constant(.lottieAdriana),
        forecastViewMode: .constant(.dashboard),
        theme: .constant(.system),
        appLanguage: .constant(.system),
        appAppearanceMode: .constant(.system),
        gridHourStep: .constant(1),
        forecastService: ForecastWindguruMockup(),
        account: WindguruAccount(credentialStore: AppEnvironment.preview.windguruCredentialStore),
        environment: .preview
    )
}
#endif
