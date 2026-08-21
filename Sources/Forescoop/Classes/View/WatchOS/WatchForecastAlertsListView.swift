//
//  WatchForecastAlertsListView.swift
//  Forescoop package
//
//  A compact, watch-native list of the user's ForecastAlert definitions.
//  Alerts created here are evaluated both in-app and by
//  ForecastAlertWatchBackgroundRefresh, exactly like alerts created on the
//  other platforms — this device just gets its own minimal creation flow
//  since the iOS spot/model pickers aren't available on watchOS.
//

#if os(watchOS)
import SwiftUI

struct WatchForecastAlertsListView: View {
    nonisolated(unsafe) let forecastService: ForecastWindguruProtocol
    private let environment: AppEnvironment

    @State private var alerts: [ForecastAlert]
    @State private var editingAlert: ForecastAlert?
    @State private var isPresentingNewAlert = false

    init(forecastService: ForecastWindguruProtocol, environment: AppEnvironment) {
        self.forecastService = forecastService
        self.environment = environment
        _alerts = State(initialValue: environment.forecastAlertStore.load())
    }

    var body: some View {
        List {
            if alerts.isEmpty {
                Text("No forecast alerts yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(alerts) { alert in
                    row(for: alert)
                }
            }
            Button("Add alert", systemImage: "plus") { isPresentingNewAlert = true }
        }
        .navigationTitle("Alerts")
        .sheet(isPresented: $isPresentingNewAlert, onDismiss: reload) {
            WatchForecastAlertFormView(forecastService: forecastService, alert: nil)
        }
        .sheet(item: $editingAlert, onDismiss: reload) { alert in
            WatchForecastAlertFormView(forecastService: forecastService, alert: alert)
        }
        .forecastAccessibilityContainer(
            "Watch forecast alerts",
            hint: "Manage push notification alerts for saved spots.",
            identifier: "watch.settings.alerts"
        )
    }

    private func row(for alert: ForecastAlert) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                editingAlert = alert
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.displayTitle).font(.headline)
                    if !alert.conditions.isEmpty {
                        Text(alert.conditionsSummary).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Toggle("Active", isOn: activeBinding(for: alert)).labelsHidden()
                Spacer()
                Button("Remove", role: .destructive) { remove(alert) }
            }
        }
    }

    private func activeBinding(for alert: ForecastAlert) -> Binding<Bool> {
        Binding(
            get: { alert.isActive },
            set: { newValue in
                environment.forecastAlertStore.setActive(newValue, for: alert.id)
                reload()
            }
        )
    }

    private func remove(_ alert: ForecastAlert) {
        environment.forecastAlertStore.remove(alert)
        reload()
    }

    private func reload() {
        alerts = environment.forecastAlertStore.load()
    }
}

#if DEBUG
#Preview("Watch forecast alerts") {
    NavigationStack {
        WatchForecastAlertsListView(forecastService: ForecastWindguruMockup(), environment: .preview)
    }
}
#endif
#endif
