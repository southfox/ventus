//
//  WatchForecastSettingsView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/02/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if os(watchOS)
import SwiftUI

/// Watch-sized settings for the units visible in its dashboard and grid.
struct WatchForecastSettingsView: View {
    nonisolated(unsafe) let forecastService: ForecastWindguruProtocol
    @Binding var temperatureUnitRaw: String
    @Binding var windSpeedUnitRaw: String
    @Binding var waveHeightUnitRaw: String
    @Binding var pressureUnitRaw: String
    @Binding var precipitationUnitRaw: String
    @Binding var freezingLevelUnitRaw: String
    @Binding var appLanguage: AppLanguage
    @Binding var preferredReadingSize: PreferredReadingSize
    @Environment(\.locale) private var locale
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title(locale: locale)).tag(language)
                    }
                }
            } footer: {
                Text("Takes effect the next time you open Ventus.".localized(locale: locale))
            }

            Picker("Temperature", selection: $temperatureUnitRaw) {
                ForEach(TemperatureUnit.allCases) { unit in Text(unit.label).tag(unit.rawValue) }
            }
            Picker("Wind", selection: $windSpeedUnitRaw) {
                ForEach(WindSpeedUnit.allCases) { unit in Text(unit.label).tag(unit.rawValue) }
            }
            Picker("Pressure", selection: $pressureUnitRaw) {
                ForEach(PressureUnit.allCases) { unit in Text(unit.label).tag(unit.rawValue) }
            }
            Picker("Rain", selection: $precipitationUnitRaw) {
                ForEach(PrecipitationUnit.allCases) { unit in Text(unit.label).tag(unit.rawValue) }
            }
            Picker("Wave height", selection: $waveHeightUnitRaw) {
                ForEach(WaveHeightUnit.allCases) { unit in Text(unit.label).tag(unit.rawValue) }
            }
            Picker("Freezing level", selection: $freezingLevelUnitRaw) {
                ForEach(FreezingLevelUnit.allCases) { unit in Text(unit.label).tag(unit.rawValue) }
            }

            Section("System") {
                NavigationLink {
                    WatchPreferredReadingSizeView(size: $preferredReadingSize)
                } label: {
                    Label("Reading size", systemImage: "textformat.size")
                }
            }

            Section {
                NavigationLink {
                    WatchForecastAlertsListView(forecastService: forecastService, environment: environment)
                } label: {
                    Label("Forecast Alerts", systemImage: "bell.badge")
                }
                NavigationLink {
                    WatchAboutView()
                } label: {
                    Label("About Ventus", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .forecastAccessibilityContainer(
            "Watch settings",
            hint: "Choose the units used in the forecast dashboard.",
            identifier: "watch.settings"
        )
    }
}

private struct WatchPreferredReadingSizeView: View {
    @Binding var size: PreferredReadingSize

    var body: some View {
        VStack(spacing: 14) {
            Toggle("Use device text size".localized, isOn: Binding(
                get: { size == .system },
                set: { useDeviceSize in size = useDeviceSize ? .system : .standard }
            ))

            Text("Example forecast text")
                .font(.body)
                .preferredReadingSize(size)
                .multilineTextAlignment(.center)

            HStack {
                Button { size = size.adjusted(by: -1) } label: { Image(systemName: "minus") }
                    .disabled(!size.canDecrease)
                Text(size.title)
                    .frame(minWidth: 72)
                Button { size = size.adjusted(by: 1) } label: { Image(systemName: "plus") }
                    .disabled(!size.canIncrease)
            }
            .font(.headline)

        }
        .navigationTitle("Reading size")
    }
}
#endif
