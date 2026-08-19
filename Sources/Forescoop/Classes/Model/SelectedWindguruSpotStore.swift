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

public enum SelectedWindguruSpotStore {
    private static let key = "selectedWindguruSpotID"
    public static func load() -> String {
        let context = ModelContext(SavedMapLocationStore.container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == key })?.value ?? SavedMapLocationStore.primarySpotID
    }

    public static var hasSavedSelection: Bool {
        let context = ModelContext(SavedMapLocationStore.container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.contains(where: { $0.key == key }) ?? false
    }
    public static func save(_ spotID: String) {
        let context = ModelContext(SavedMapLocationStore.container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == key }) { record.value = spotID } else { context.insert(VentusPreferenceRecord(key: key, value: spotID)) }
        try? context.save()
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    public static func clear() {
        let context = ModelContext(SavedMapLocationStore.container)
        guard let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == key }) else { return }
        context.delete(record)
        try? context.save()
    }
}
