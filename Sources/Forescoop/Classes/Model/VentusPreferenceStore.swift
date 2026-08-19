//
//  VentusPreferenceStore.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//  

import SwiftData

enum VentusPreferenceStore {
    static func value(forKey key: String) -> String? {
        let context = ModelContext(SavedMapLocationStore.container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key })?
            .value
    }

    static func save(_ value: String, forKey key: String) {
        let context = ModelContext(SavedMapLocationStore.container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key }) {
            record.value = value
        } else {
            context.insert(VentusPreferenceRecord(key: key, value: value))
        }
        try? context.save()
    }
}
