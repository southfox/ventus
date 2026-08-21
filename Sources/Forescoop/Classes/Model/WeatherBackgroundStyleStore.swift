//
//  WeatherBackgroundStyleStore.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//

import SwiftData

public protocol WeatherBackgroundStyleStoring: Sendable {
    func load() -> WeatherBackgroundStyle
    func save(_ style: WeatherBackgroundStyle)
}

public final class WeatherBackgroundStyleStore: WeatherBackgroundStyleStoring {
    private static let key = "weatherBackgroundStyle"

    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() -> WeatherBackgroundStyle {
        let context = ModelContext(container)
        let value = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.key })?
            .value
        if value == "lottie" { return .lottieAdriana }
        return value.flatMap(WeatherBackgroundStyle.init(rawValue:)) ?? .none
    }

    public func save(_ style: WeatherBackgroundStyle) {
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.key }) {
            record.value = style.rawValue
        } else {
            context.insert(VentusPreferenceRecord(key: Self.key, value: style.rawValue))
        }
        try? context.save()
    }
}
