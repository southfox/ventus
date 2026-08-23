//
//  ForecastModelPicker.swift
//  Ventus
//
//  Created by Javier on 23/07/2026.
//  Copyright © 2026 Ventus. All rights reserved.

#if !os(watchOS)
import SwiftUI

public struct ForecastModelPicker: View {
    let spotID: String
    let selectedModelIDs: Set<String>
    let usableModelIDs: Set<String>
    let isProUser: Bool
    let onModelSelected: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ForecastModelPickerViewModel

    public init(
        forecastService: ForecastWindguruProtocol,
        spotID: String,
        selectedModelIDs: Set<String>,
        usableModelIDs: Set<String> = [],
        isProUser: Bool = false,
        onModelSelected: @escaping ([String]) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: ForecastModelPickerViewModel(forecastService: forecastService, selectedModelIDs: selectedModelIDs))
        self.spotID = spotID
        self.selectedModelIDs = selectedModelIDs
        self.usableModelIDs = usableModelIDs
        self.isProUser = isProUser
        self.onModelSelected = onModelSelected
    }

    private var selectionSummary: String {
        let selectedCount = viewModel.selectedIDs.count
        let availableCount = viewModel.models.count
        return selectedCount == availableCount
            ? "All selected"
            : "\(selectedCount)/\(availableCount) selected"
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading forecast models…")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Models unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if viewModel.models.isEmpty {
                    ContentUnavailableView("No forecast models", systemImage: "cpu")
                } else {
#if os(tvOS)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            Text(selectionSummary)
                                .font(.title3.weight(.semibold))

                            ForecastModelSelectionList(
                                models: viewModel.models,
                                selectedModelIDs: viewModel.selectedIDs,
                                onToggle: viewModel.toggle
                            )

                            HStack(spacing: 28) {
                                Button("Cancel", action: dismiss.callAsFunction)
                                    .buttonStyle(.plain)
                                Spacer()
                                Button("Apply") { onModelSelected(viewModel.selectedIDs.sorted()) }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.selectedIDs.isEmpty)
                            }
                            .font(.headline)
                        }
                        .frame(maxWidth: 760, alignment: .leading)
                        .padding(.horizontal, 72)
                        .padding(.vertical, 44)
                    }
#else
                    List {
                        Section(selectionSummary) {
                            ForecastModelSelectionList(
                                models: viewModel.models,
                                selectedModelIDs: viewModel.selectedIDs,
                                onToggle: viewModel.toggle
                            )
                        }
                    }
#endif
                }
            }
            .navigationTitle("Forecast model")
#if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onModelSelected(viewModel.selectedIDs.sorted()) }
                        .disabled(viewModel.selectedIDs.isEmpty)
                }
            }
#endif
            .task {
                await viewModel.loadModels(spotID: spotID, selectedModelIDs: selectedModelIDs, usableModelIDs: usableModelIDs, isProUser: isProUser)
            }
        }
    }

}

#if DEBUG
#Preview("Forecast model picker") {
    ForecastModelPicker(
        forecastService: ForecastWindguruMockup(),
        spotID: SavedMapLocationStore.primarySpotID,
        selectedModelIDs: [],
        usableModelIDs: [],
        isProUser: true,
        onModelSelected: { _ in }
    )
}
#endif
#endif
