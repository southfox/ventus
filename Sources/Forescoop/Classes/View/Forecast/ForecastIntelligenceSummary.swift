//
//  ForecastIntelligenceSummary.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/01/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS)
import SwiftUI

#if canImport(FoundationModels) && !os(tvOS)
import FoundationModels
#endif

public struct ForecastIntelligenceSummary: View {
    @Environment(\.ventusTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private let snapshot: ForecastIntelligenceSnapshot
    @State private var summary: String
    @State private var isGenerating = false

    public init(
        forecast: SpotForecast,
        hour: String?,
        coordinateLocationName: String? = nil,
        temperatureUnit: TemperatureUnit = DeviceForecastPreferences.temperatureUnit,
        windSpeedUnit: WindSpeedUnit = DeviceForecastPreferences.windSpeedUnit,
        precipitationUnit: PrecipitationUnit = DeviceForecastPreferences.precipitationUnit,
        freezingLevelUnit: FreezingLevelUnit = DeviceForecastPreferences.freezingLevelUnit,
        pressureUnit: PressureUnit = DeviceForecastPreferences.pressureUnit,
        locale: Locale = AppLanguageStore.currentLocale
    ) {
        let snapshot = ForecastIntelligenceSnapshot(
            forecast: forecast,
            hour: hour,
            coordinateLocationName: coordinateLocationName,
            temperatureUnit: temperatureUnit,
            windSpeedUnit: windSpeedUnit,
            precipitationUnit: precipitationUnit,
            freezingLevelUnit: freezingLevelUnit,
            pressureUnit: pressureUnit,
            locale: locale
        )
        self.snapshot = snapshot
        _summary = State(initialValue: snapshot.deterministicSummary)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label("Forecast insight", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(theme.accentColor)
                if isGenerating {
                    ProgressView().controlSize(.small)
                }
            }
            Text(summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background {
            if theme.usesMaterial {
                RoundedRectangle(cornerRadius: 14).fill(.regularMaterial)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.backgroundColor(for: colorScheme).opacity(theme == .system ? 0.2 : 0.82))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.accentColor.opacity(0.25))
        }
        .ventusGlassEffect(theme: theme, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Forecast insight. \(summary)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("forecast.insight")
        .task(id: snapshot) {
            await generateSummary()
        }
    }

    @MainActor
    private func generateSummary() async {
        summary = snapshot.deterministicSummary
#if canImport(FoundationModels) && !os(tvOS)
        guard SystemLanguageModel.default.isAvailable else { return }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let detail = ForecastInsightDetail.deviceDefault
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: "You are a precise weather forecaster. Using only the supplied forecast facts: current conditions, the wind, temperature, and precipitation outlook, and the multi-day breakdown. Write a helpful analysis of what's happening now and how conditions will change over the next hours and days. Clearly call out anything severe: strong wind, heavy rain or snow, or unusually cold or hot temperatures. Stay under \(detail.maxWords) words. Use only the supplied facts. Do not invent safety advice or facts. \(snapshot.languageInstruction)"
            )
            let response = try await session.respond(to: snapshot.prompt)
            let generated = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !generated.isEmpty {
                summary = generated
            }
        } catch {
        }
#endif
    }
}

#Preview("Forecast intelligence") {
    if let forecast = ForecastWindguruMockup().dashboardPreviewForecast {
        ForecastIntelligenceSummary(forecast: forecast, hour: "29")
            .padding()
            .modifier(VentusThemeModifier(theme: .ocean))
    }
}
#endif
