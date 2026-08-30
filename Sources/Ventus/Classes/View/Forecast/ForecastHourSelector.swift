//
//  ForecastHourSelector.swift
//  Ventus
//

#if !os(watchOS)
import SwiftUI

public struct ForecastHourSelector: View {
    public let forecast: SpotForecast
    @Binding public var selectedHour: String?
    @Environment(\.locale) private var locale
    @Environment(\.appEnvironment) private var environment
    @Environment(\.scenePhase) private var scenePhase

    public init(
        forecast: SpotForecast,
        selectedHour: Binding<String?>
    ) {
        self.forecast = forecast
        _selectedHour = selectedHour
    }

    private var hours: [String] {
        forecast.steppedForecastHours(anchorHour: currentHour, step: environment.gridHourStepStore.load(), includingPast: false)
    }

    private var currentHour: String? {
        forecast.currentForecastHour
    }

    private var selection: String? {
        if let selectedHour, hours.contains(selectedHour) {
            return selectedHour
        }
        if let currentHour, hours.contains(currentHour) {
            return currentHour
        }
        return hours.first
    }

    /// A saved selection can become a past hour while the app is inactive.
    /// A menu picker renders blank when its selection has no matching tag, so
    /// always read a value that exists in the currently visible hours.
    private var pickerSelection: Binding<String?> {
        Binding(
            get: { selection },
            set: { selectedHour = $0 }
        )
    }

    private var selectedIndex: Int? {
        selection.flatMap { hours.firstIndex(of: $0) }
    }

    public var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Button {
                moveSelection(by: -1)
            } label: {
                Label("Previous forecast hour", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
#if os(tvOS)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
#endif
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == nil || selectedIndex == 0)


            Spacer()

#if os(tvOS)
            Text(selection.map(hourLabel(for:)) ?? "")
                .fontWeight(selection == currentHour ? .bold : .regular)
                .fixedSize(horizontal: false, vertical: true)
#else
            Picker("Forecast date and hour", selection: pickerSelection) {
                ForEach(hours, id: \.self) { hour in
                    Text(hourLabel(for: hour))
                        .fontWeight(hour == currentHour ? .bold : .regular)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .tag(Optional(hour))
                }
            }
            .pickerStyle(.menu)
            .fontWeight(selection == currentHour ? .bold : .regular)
            .fixedSize(horizontal: false, vertical: true)
#endif

            Spacer()

            Button {
                moveSelection(by: 1)
            } label: {
                Label("Next forecast hour", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
#if os(tvOS)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
#endif
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == nil || selectedIndex == hours.count - 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Forecast date and hour")
        .accessibilityHint("Use previous and next controls, or open the picker to choose a forecast hour.")
        .accessibilityIdentifier("forecast.hour.selector")
        .onAppear(perform: synchronizeSelection)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                synchronizeSelection()
            }
        }
        .onChange(of: hours) { _, _ in
            synchronizeSelection()
        }
    }

    private func moveSelection(by offset: Int) {
        guard let selectedIndex else { return }
        selectedHour = hours[hours.index(selectedIndex, offsetBy: offset)]
    }

    private func synchronizeSelection() {
        guard selectedHour != selection else { return }
        selectedHour = selection
    }

    private func hourLabel(for hour: String) -> String {
        guard let date = forecast.forecastDate(hour: hour) else {
            return String(format: "%02d:00", (Int(hour) ?? 0) % 24)
        }

        let calendar = Calendar.current
        let day = calendar.isDateInToday(date)
            ? "today".localized(locale: locale)
            : date.forecastShortWeekdayAndDay(locale: locale)
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("j")
        let suffix = formatter.dateFormat.contains("a") ? "" : " hs"
        return "\(day), \(formatter.string(from: date))\(suffix)"
    }
}

#if DEBUG
#Preview {
    ForecastHourSelectorPreview()
        .padding()
}

private struct ForecastHourSelectorPreview: View {
    @State private var selectedHour: String?

    @ViewBuilder var body: some View {
        if let forecast = ForecastWindguruMockup().dashboardPreviewForecast {
            ForecastHourSelector(forecast: forecast, selectedHour: $selectedHour)
        } else {
            ContentUnavailableView("Preview forecast unavailable", systemImage: "exclamationmark.triangle")
        }
    }
}
#endif
#endif
