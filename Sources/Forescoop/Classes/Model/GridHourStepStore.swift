//
//  GridHourStepStore.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//

import SwiftData

public protocol GridHourStepStoring: Sendable {
    func load() -> Int
    func save(_ step: Int)
}

public final class GridHourStepStore: GridHourStepStoring {
    private static let key = "gridHourStep"
    public static let defaultStep = 1
    public static let range = 1...6

    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() -> Int {
        let context = ModelContext(container)
        let value = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.key })?
            .value
        return value.flatMap(Int.init).map { min(max($0, Self.range.lowerBound), Self.range.upperBound) } ?? Self.defaultStep
    }

    public func save(_ step: Int) {
        let clamped = min(max(step, Self.range.lowerBound), Self.range.upperBound)
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.key }) {
            record.value = String(clamped)
        } else {
            context.insert(VentusPreferenceRecord(key: Self.key, value: String(clamped)))
        }
        try? context.save()
    }
}
