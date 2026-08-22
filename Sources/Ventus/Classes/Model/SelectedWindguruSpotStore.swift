//
//  SelectedWindguruSpotStore.swift
//  VentusPackage
//
//  Created by Javier on 19/08/2026.
//

import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

public protocol SelectedWindguruSpotStoring: Sendable {
    func load() -> String
    var hasSavedSelection: Bool { get }
    func save(_ spotID: String)
    func clear()
    var usesCurrentLocation: Bool { get }
    func saveUsesCurrentLocation(_ value: Bool)
}

public final class SelectedWindguruSpotStore: SelectedWindguruSpotStoring {
    private static let key = "selectedWindguruSpotID"
    private static let usesCurrentLocationKey = "selectedWindguruUsesCurrentLocation"
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() -> String {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == Self.key })?.value ?? SavedMapLocationStore.primarySpotID
    }

    public var hasSavedSelection: Bool {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.contains(where: { $0.key == Self.key }) ?? false
    }

    public func save(_ spotID: String) {
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == Self.key }) { record.value = spotID } else { context.insert(VentusPreferenceRecord(key: Self.key, value: spotID)) }
        try? context.save()
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    public func clear() {
        let context = ModelContext(container)
        guard let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == Self.key }) else { return }
        context.delete(record)
        try? context.save()
    }

    public var usesCurrentLocation: Bool {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.usesCurrentLocationKey })?.value == "true"
    }

    public func saveUsesCurrentLocation(_ value: Bool) {
        let context = ModelContext(container)
        let stringValue = value ? "true" : "false"
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.usesCurrentLocationKey }) {
            record.value = stringValue
        } else {
            context.insert(VentusPreferenceRecord(key: Self.usesCurrentLocationKey, value: stringValue))
        }
        try? context.save()
    }
}
