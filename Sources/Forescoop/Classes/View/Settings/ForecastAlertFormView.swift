//
//  ForecastAlertFormView.swift
//  Forescoop package
//
//  Add/edit screen for a ForecastAlert, mirroring Windguru's "Add alert"
//  screen: spot, models, name, conditions, day range, weekdays, and a
//  push-notification-only alert method (no email).
//

#if !os(watchOS)
import SwiftUI

struct ForecastAlertFormView: View {
    let forecastService: ForecastWindguruProtocol
    let account: WindguruAccount
    let existingAlert: ForecastAlert?
    private let spotInfoLoader: @MainActor (String) async throws -> SpotInfo?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ForecastAlert
    @State private var isPresentingSpotPicker = false
    @State private var isPresentingModelPicker = false

    private static let weekdayOrder: [(symbol: String, value: Int)] = [
        ("Mo", 2), ("Tu", 3), ("We", 4), ("Th", 5), ("Fr", 6), ("Sa", 7), ("Su", 1)
    ]

    init(forecastService: ForecastWindguruProtocol, account: WindguruAccount, alert: ForecastAlert?) {
        self.forecastService = forecastService
        self.account = account
        existingAlert = alert
        _draft = State(initialValue: alert ?? ForecastAlert(spotID: "", spotDisplayName: ""))
        spotInfoLoader = { try await forecastService.spotInfo(bySpotId: $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected spot") {
                    Button {
                        isPresentingSpotPicker = true
                    } label: {
                        HStack {
                            Text(draft.spotDisplayName.isEmpty ? "Select spot…" : draft.spotDisplayName)
                                .foregroundStyle(draft.spotDisplayName.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        isPresentingModelPicker = true
                    } label: {
                        HStack {
                            Text(draft.modelIDs.isEmpty ? "Select models…" : "\(draft.modelIDs.count) selected")
                                .foregroundStyle(draft.modelIDs.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                    .disabled(draft.spotID.isEmpty)
                } header: {
                    Text("Forecast models")
                } footer: {
                    Text(draft.spotID.isEmpty ? "Choose a spot first." : "Leave empty to consider every model available for this spot.")
                }

                Section("Name for this alert (optional)") {
                    TextField("e.g. Bariloche powder day", text: $draft.name)
                }

                Section {
                    ForEach($draft.conditions) { $condition in
                        conditionRow($condition)
                    }
                    HStack {
                        Button("More conditions", systemImage: "plus.circle") {
                            draft.conditions.append(ForecastAlertCondition())
                        }
                        Spacer()
                        Button("Less conditions", systemImage: "minus.circle") {
                            guard draft.conditions.count > 1 else { return }
                            draft.conditions.removeLast()
                        }
                        .disabled(draft.conditions.count <= 1)
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("Conditions")
                } footer: {
                    Text("All conditions must be true in the same forecast hour for the alert to fire.")
                }

                Section {
#if os(tvOS)
                    Picker("Up to day", selection: $draft.considerForecastUpToDay) {
                        ForEach(1...10, id: \.self) { day in
                            (day == 1 ? Text("1 day ahead") : Text("\(day) days ahead")).tag(day)
                        }
                    }
#else
                    Stepper(value: $draft.considerForecastUpToDay, in: 1...10) {
                        draft.considerForecastUpToDay == 1 ? Text("Up to 1 day ahead") : Text("Up to \(draft.considerForecastUpToDay) days ahead")
                    }
#endif
                } header: {
                    Text("Consider forecasts up to day")
                } footer: {
                    Text("Longer forecasts are ignored.")
                }

                Section {
                    HStack {
                        ForEach(Self.weekdayOrder, id: \.value) { weekday in
                            weekdayToggle(weekday)
                        }
                    }
                } header: {
                    Text("Weekdays to consider")
                } footer: {
                    Text(draft.weekdays.isEmpty ? "Every day." : "Only forecast hours on the selected days.")
                }

                Section {
                    Toggle("Push Notification", isOn: $draft.pushNotificationEnabled)
                } header: {
                    Text("Alert method")
                } footer: {
                    Text("This alert will send a push notification when its conditions are met.")
                }

                Section {
                    Toggle("Active?", isOn: $draft.isActive)
                } footer: {
                    Text("If you want to deactivate this alert temporarily you can do it with this switch.")
                }
            }
            .navigationTitle(existingAlert == nil ? "Add alert" : "Edit alert")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ForecastAlertStore.save(draft)
                        dismiss()
                    }
                    .disabled(draft.spotID.isEmpty || draft.conditions.isEmpty)
                }
            }
            .sheet(isPresented: $isPresentingSpotPicker) {
                WindguruSpotPicker(
                    forecastService: forecastService,
                    account: account,
                    onSpotSelected: { spot in
                        selectSpot(id: spot.identifier, name: spot.displayName)
                        isPresentingSpotPicker = false
                    },
                    onSpotIDSelected: { spotID in
                        Task { await resolveAndSelectSpot(spotID: spotID) }
                        isPresentingSpotPicker = false
                    },
                    onFavoriteSelected: { spot in
                        selectSpot(id: spot.identifier, name: spot.displayName)
                        isPresentingSpotPicker = false
                    },
                    onCoordinateSelected: { _, _ in
                        isPresentingSpotPicker = false
                    }
                )
            }
            .sheet(isPresented: $isPresentingModelPicker) {
                ForecastModelPicker(
                    forecastService: forecastService,
                    spotID: draft.spotID,
                    selectedModelIDs: Set(draft.modelIDs),
                    isProUser: account.isProUser
                ) { modelIDs in
                    draft.modelIDs = modelIDs
                    isPresentingModelPicker = false
                }
            }
        }
    }

    private func conditionRow(_ condition: Binding<ForecastAlertCondition>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Variable", selection: condition.variable) {
                ForEach(ForecastAlertVariable.allCases) { variable in
                    Text(variable.title).tag(variable)
                }
            }
            HStack {
                Picker("Comparator", selection: condition.comparator) {
                    ForEach(ForecastAlertComparator.allCases) { comparator in
                        Text(comparator.symbol).tag(comparator)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 100)
                TextField("Value", value: condition.value, format: .number)
#if !os(macOS) && !os(tvOS)
                    .keyboardType(.decimalPad)
#endif
#if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
#endif
                Text(condition.wrappedValue.variable.unit).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func weekdayToggle(_ weekday: (symbol: String, value: Int)) -> some View {
        let isSelected = draft.weekdays.contains(weekday.value)
        return Button(weekday.symbol) {
            if isSelected {
                draft.weekdays.remove(weekday.value)
            } else {
                draft.weekdays.insert(weekday.value)
            }
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
        .frame(maxWidth: .infinity)
    }

    private func selectSpot(id: String?, name: String) {
        guard let id else { return }
        draft.spotID = id
        draft.spotDisplayName = name
        draft.modelIDs = []
    }

    private func resolveAndSelectSpot(spotID: String) async {
        let name = (try? await spotInfoLoader(spotID))?.displayName ?? spotID
        selectSpot(id: spotID, name: name)
    }
}

#if DEBUG
#Preview("Add alert") {
    ForecastAlertFormView(forecastService: ForecastWindguruMockup(), account: WindguruAccount(), alert: nil)
}
#endif
#endif
