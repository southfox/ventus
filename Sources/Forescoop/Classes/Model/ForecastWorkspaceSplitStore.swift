//
//  ForecastWorkspaceSplitStore.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//  

import Foundation

enum ForecastWorkspaceSplitStore {
    private static let wideKey = "forecastWorkspaceWideSplit"
    private static let tallKey = "forecastWorkspaceTallSplit"

    static func load(isWide: Bool) -> CGFloat {
        let key = isWide ? wideKey : tallKey
        let fallback: CGFloat = isWide ? 0.56 : 0.52
        guard let value = VentusPreferenceStore.value(forKey: key),
              let fraction = Double(value) else { return fallback }
        return min(max(CGFloat(fraction), 0.25), 0.75)
    }

    static func save(_ fraction: CGFloat, isWide: Bool) {
        VentusPreferenceStore.save(String(Double(fraction)), forKey: isWide ? wideKey : tallKey)
    }
}
