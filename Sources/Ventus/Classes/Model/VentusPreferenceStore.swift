//
//  VentusPreferenceStore.swift
//  VentusPackage
//
//  Created by Javier on 19/08/2026.
//

import SwiftData

protocol VentusPreferenceStoring: Sendable {
    func value(forKey key: String) -> String?
    func save(_ value: String, forKey key: String)
}

final class VentusPreferenceStore: VentusPreferenceStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func value(forKey key: String) -> String? {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key })?
            .value
    }

    func save(_ value: String, forKey key: String) {
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key }) {
            record.value = value
        } else {
            context.insert(VentusPreferenceRecord(key: key, value: value))
        }
        try? context.save()
    }
}
