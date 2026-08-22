//
//  ForecastWorkspaceSplitStore.swift
//  VentusPackage
//
//  Created by Javier on 19/08/2026.
//

import Foundation

protocol ForecastWorkspaceSplitStoring: Sendable {
    func load(isWide: Bool) -> CGFloat
    func save(_ fraction: CGFloat, isWide: Bool)
}

final class ForecastWorkspaceSplitStore: ForecastWorkspaceSplitStoring {
    private static let wideKey = "forecastWorkspaceWideSplit"
    private static let tallKey = "forecastWorkspaceTallSplit"

    private let preferenceStore: VentusPreferenceStoring

    init(preferenceStore: VentusPreferenceStoring) {
        self.preferenceStore = preferenceStore
    }

    func load(isWide: Bool) -> CGFloat {
        let key = isWide ? Self.wideKey : Self.tallKey
        let fallback: CGFloat = isWide ? 0.56 : 0.52
        guard let value = preferenceStore.value(forKey: key),
              let fraction = Double(value) else { return fallback }
        return min(max(CGFloat(fraction), 0.25), 0.75)
    }

    func save(_ fraction: CGFloat, isWide: Bool) {
        preferenceStore.save(String(Double(fraction)), forKey: isWide ? Self.wideKey : Self.tallKey)
    }
}
