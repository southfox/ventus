//
//  GridHourStepStore.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//  

import SwiftData

public enum GridHourStepStore {
    private static let key = "gridHourStep"
    public static let defaultStep = 1
    public static let range = 1...6

    public static func load() -> Int {
        let context = ModelContext(SavedMapLocationStore.container)
        let value = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key })?
            .value
        return value.flatMap(Int.init).map { min(max($0, range.lowerBound), range.upperBound) } ?? defaultStep
    }

    public static func save(_ step: Int) {
        let clamped = min(max(step, range.lowerBound), range.upperBound)
        let context = ModelContext(SavedMapLocationStore.container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key }) {
            record.value = String(clamped)
        } else {
            context.insert(VentusPreferenceRecord(key: key, value: String(clamped)))
        }
        try? context.save()
    }
}
