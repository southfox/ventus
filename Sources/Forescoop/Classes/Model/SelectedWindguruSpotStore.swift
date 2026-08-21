//
//  SelectedWindguruSpotStore.swift
//  ForescoopPackage
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
}

public final class SelectedWindguruSpotStore: SelectedWindguruSpotStoring {
    private static let key = "selectedWindguruSpotID"
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
}
