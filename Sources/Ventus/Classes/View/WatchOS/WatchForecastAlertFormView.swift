//
//  WatchForecastAlertFormView.swift
//  Forescoop package
//
//  Add/edit screen for a single ForecastAlert, sized for the watch. Unlike
//  the iOS form, this keeps exactly one condition (no add/remove rows) to
//  stay usable on a small screen.
//

#if os(watchOS)
import SwiftUI

struct WatchForecastAlertFormView: View {
    nonisolated(unsafe) let forecastService: ForecastWindguruProtocol
    let existingAlert: ForecastAlert?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment
    @State private var draft: ForecastAlert
    @State private var isPresentingSpotPicker = false
    @State private var availableModels = [(identifier: String, name: String)]()
    @State private var isLoadingModels = false

    private static let weekdayOrder: [(symbol: String, value: Int)] = [
        ("Mo", 2), ("Tu", 3), ("We", 4), ("Th", 5), ("Fr", 6), ("Sa", 7), ("Su", 1)
    ]

    init(forecastService: ForecastWindguruProtocol, alert: ForecastAlert?) {
        self.forecastService = forecastService
        existingAlert = alert
        var initial = alert ?? ForecastAlert(spotID: "", spotDisplayName: "")
        if initial.conditions.isEmpty { initial.conditions = [ForecastAlertCondition()] }
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Spot") {
                    Button(draft.spotDisplayName.isEmpty ? "Select spot…" : draft.spotDisplayName) {
                        isPresentingSpotPicker = true
                    }
                }

                if !draft.spotID.isEmpty {
                    Section("Models") {
                        if isLoadingModels {
                            ProgressView()
                        } else if availableModels.isEmpty {
                            Text("No models found.").font(.caption2).foregroundStyle(.secondary)
                        } else {
                            ForEach(availableModels, id: \.identifier) { model in
                                modelToggle(model)
                            }
                        }
                    }
                }

                Section("Name") {
                    TextField("Optional", text: $draft.name)
                }

                if let condition = draft.conditions.first {
                    Section("Condition") {
                        conditionEditor(condition)
                    }
                }

                Section("Up to day") {
                    Picker("Days ahead", selection: $draft.considerForecastUpToDay) {
                        ForEach(1...10, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                }

                Section("Weekdays") {
                    ForEach(Self.weekdayOrder, id: \.value) { weekday in
                        Toggle(weekday.symbol, isOn: weekdayBinding(weekday.value))
                    }
                }

                Section {
                    Toggle("Push Notification", isOn: $draft.pushNotificationEnabled)
                    Toggle("Active", isOn: $draft.isActive)
                }
            }
            .navigationTitle(existingAlert == nil ? "Add alert" : "Edit alert")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        environment.forecastAlertStore.save(draft)
                        dismiss()
                    }
                    .disabled(draft.spotID.isEmpty)
                }
            }
            .sheet(isPresented: $isPresentingSpotPicker) {
                WatchLocationPicker(
                    locations: environment.watchLocationStore.load(),
                    selectedSpotID: draft.spotID,
                    forecastService: forecastService,
                    select: { location in
                        selectSpot(location)
                        isPresentingSpotPicker = false
                    },
                    add: { location in
                        var locations = environment.watchLocationStore.load()
                        if !locations.contains(where: { $0.spotID == location.spotID }) {
                            locations.append(location)
                            environment.watchLocationStore.save(locations)
                        }
                        selectSpot(location)
                        isPresentingSpotPicker = false
                    }
                )
            }
            .task(id: draft.spotID) { await loadModels() }
        }
    }

    private func modelToggle(_ model: (identifier: String, name: String)) -> some View {
        let isSelected = draft.modelIDs.contains(model.identifier)
        return Button {
            if isSelected {
                draft.modelIDs.removeAll { $0 == model.identifier }
            } else {
                draft.modelIDs.append(model.identifier)
            }
        } label: {
            HStack {
                Text(model.name)
                Spacer()
                if isSelected { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
        }
    }

    private func conditionEditor(_ condition: ForecastAlertCondition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Variable", selection: conditionBinding(\.variable)) {
                ForEach(ForecastAlertVariable.allCases) { variable in
                    Text(variable.title).tag(variable)
                }
            }
            Picker("Comparator", selection: conditionBinding(\.comparator)) {
                ForEach(ForecastAlertComparator.allCases) { comparator in
                    Text(comparator.symbol).tag(comparator)
                }
            }
            HStack {
                TextField("Value", value: conditionBinding(\.value), format: .number)
                Text(condition.variable.unit).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func conditionBinding<T>(_ keyPath: WritableKeyPath<ForecastAlertCondition, T>) -> Binding<T> {
        Binding(
            get: { draft.conditions.first?[keyPath: keyPath] ?? ForecastAlertCondition()[keyPath: keyPath] },
            set: { newValue in
                guard !draft.conditions.isEmpty else { return }
                draft.conditions[0][keyPath: keyPath] = newValue
            }
        )
    }

    private func weekdayBinding(_ value: Int) -> Binding<Bool> {
        Binding(
            get: { draft.weekdays.contains(value) },
            set: { isOn in
                if isOn { draft.weekdays.insert(value) } else { draft.weekdays.remove(value) }
            }
        )
    }

    private func selectSpot(_ location: WatchLocation) {
        draft.spotID = location.spotID
        draft.spotDisplayName = location.name
        draft.modelIDs = []
    }

    @MainActor
    private func loadModels() async {
        guard !draft.spotID.isEmpty else {
            availableModels = []
            return
        }
        isLoadingModels = true
        defer { isLoadingModels = false }
        let forecast = try? await forecastService.forecast(bySpotId: draft.spotID, model: nil)
        availableModels = (forecast?.forecasts ?? []).compactMap { model in
            guard let identifier = model.model else { return nil }
            return (identifier, model.forecast?.modelName ?? "Model \(identifier)")
        }
    }
}

#if DEBUG
#Preview("Add watch alert") {
    WatchForecastAlertFormView(forecastService: ForecastWindguruMockup(), alert: nil)
}
#endif
#endif
