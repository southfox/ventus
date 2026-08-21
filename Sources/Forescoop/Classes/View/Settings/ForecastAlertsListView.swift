//
//  ForecastAlertsListView.swift
//  Forescoop package
//
//  Lists the user's custom ForecastAlert definitions, mirroring Windguru's
//  "Forecast alerts" screen but push-notification only.
//

#if !os(watchOS)
import SwiftUI

struct ForecastAlertsListView: View {
    let forecastService: ForecastWindguruProtocol
    let account: WindguruAccount
    private let modelInfoLoader: @MainActor () async throws -> Models?

    @Environment(\.appEnvironment) private var environment

    @State private var alerts: [ForecastAlert]
    @State private var modelNamesByID = [String: String]()
    @State private var editingAlert: ForecastAlert?
    @State private var isPresentingNewAlert = false

    init(forecastService: ForecastWindguruProtocol, account: WindguruAccount, environment: AppEnvironment) {
        self.forecastService = forecastService
        self.account = account
        modelInfoLoader = { try await forecastService.modelInfo(onlyModelId: nil) }
        _alerts = State(initialValue: environment.forecastAlertStore.load())
    }

    var body: some View {
        List {
            if alerts.isEmpty {
                ContentUnavailableView(
                    "No forecast alerts",
                    systemImage: "bell.badge",
                    description: Text("Add an alert to get a push notification whenever a spot's forecast meets your conditions.")
                )
            } else {
                ForEach(alerts) { alert in
                    row(for: alert)
                }
            }
        }
        .navigationTitle("Forecast Alerts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add alert", systemImage: "plus") { isPresentingNewAlert = true }
            }
        }
        .sheet(isPresented: $isPresentingNewAlert, onDismiss: reload) {
            ForecastAlertFormView(forecastService: forecastService, account: account, alert: nil)
        }
        .sheet(item: $editingAlert, onDismiss: reload) { alert in
            ForecastAlertFormView(forecastService: forecastService, account: account, alert: alert)
        }
        .task { await loadModelNames() }
        .forecastAccessibilityContainer(
            "Forecast alerts",
            hint: "Manage push notification alerts for saved spots.",
            identifier: "settings.alerts"
        )
        .trackScreenView("Alerts List")
    }

    private func row(for alert: ForecastAlert) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.displayTitle).font(.headline)
                if !alert.modelIDs.isEmpty {
                    Text(modelsSummary(for: alert)).font(.caption).foregroundStyle(.secondary)
                }
                if !alert.conditions.isEmpty {
                    Text(alert.conditionsSummary).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(spacing: 8) {
                Toggle("Active", isOn: activeBinding(for: alert)).labelsHidden()
                Button("Edit") { editingAlert = alert }
                    .buttonStyle(.bordered)
                Button("Remove", role: .destructive) { remove(alert) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func modelsSummary(for alert: ForecastAlert) -> String {
        alert.modelIDs.map { modelNamesByID[$0] ?? "Model \($0)" }.joined(separator: ", ")
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
        environment.analytics.log(.alertDeleted)
    }

    private func reload() {
        alerts = environment.forecastAlertStore.load()
    }

    private func loadModelNames() async {
        guard let models = try? await modelInfoLoader() else { return }
        modelNamesByID = Dictionary(uniqueKeysWithValues: models.sorted.map {
            (String($0.identifier), $0.oficinalName ?? $0.shortName ?? "Model \($0.identifier)")
        })
    }
}

#if DEBUG
#Preview("Forecast alerts") {
    NavigationStack {
        ForecastAlertsListView(forecastService: ForecastWindguruMockup(), account: WindguruAccount(credentialStore: AppEnvironment.preview.windguruCredentialStore), environment: .preview)
    }
}
#endif
#endif
