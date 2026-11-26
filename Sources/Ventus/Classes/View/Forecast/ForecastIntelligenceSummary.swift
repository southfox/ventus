//
//  ForecastIntelligenceSummary.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/01/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS)
import SwiftUI

#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
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
        waveHeightUnit: WaveHeightUnit = DeviceForecastPreferences.waveHeightUnit,
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
            waveHeightUnit: waveHeightUnit,
            locale: locale
        )
        self.snapshot = snapshot
        _summary = State(initialValue: snapshot.structuredOverview)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label("Overview", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(theme.accentColor)
                if isGenerating {
                    ProgressView().controlSize(.small)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(summary.markdownSections.enumerated()), id: \.offset) { _, section in
                    Text(markdown: section)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
        .accessibilityLabel("Overview. \(summary)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("forecast.insight")
        .task(id: snapshot) {
            await generateSummary()
        }
    }

    @MainActor
    private func generateSummary() async {
        summary = snapshot.structuredOverview
#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        guard SystemLanguageModel.default.isAvailable else { return }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let detail = ForecastInsightDetail.deviceDefault
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: """
                You are a precise weather forecaster writing a brief summary for a forecast app.

                Using only the supplied forecast facts (current conditions, wind, temperature, precipitation, and multi-day breakdown):
                Write an opening paragraph with the header **Overview** characterizing the current conditions and the upcoming multi-day outlook.
                Only if supported by the provided facts, include a **Key Trends & Impact** section. Use bold sub-points formatted strictly as * **Title:** sentence to highlight notable conditions (such as strong winds/wind chill, refreeze/ice risk, persistent precipitation, or temperature extremes).

                Constraints:
                Omit the Key Trends section entirely if conditions are mild or unremarkable.
                Do not invent safety advice, travel warnings, or facts not present in the data.
                Keep the entire response under \(detail.maxWords) words.
                \(snapshot.languageInstruction)
                """
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

extension Text {
    init(markdown string: String) {
        if let attributed = try? AttributedString(markdown: string, options: .init(interpretedSyntax: .full)) {
            self.init(attributed)
        } else {
            self.init(string)
        }
    }
}

extension String {
    var markdownSections: [String] {
        components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
