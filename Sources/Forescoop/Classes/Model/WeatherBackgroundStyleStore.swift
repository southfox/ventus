//
//  WeatherBackgroundStyleStore.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//  

import SwiftData

public enum WeatherBackgroundStyleStore {
    private static let key = "weatherBackgroundStyle"

    public static func load() -> WeatherBackgroundStyle {
        let context = ModelContext(SavedMapLocationStore.container)
        let value = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key })?
            .value
        if value == "lottie" { return .lottieAdriana }
        return value.flatMap(WeatherBackgroundStyle.init(rawValue:)) ?? .none
    }

    public static func save(_ style: WeatherBackgroundStyle) {
        let context = ModelContext(SavedMapLocationStore.container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key }) {
            record.value = style.rawValue
        } else {
            context.insert(VentusPreferenceRecord(key: key, value: style.rawValue))
        }
        try? context.save()
    }
}
