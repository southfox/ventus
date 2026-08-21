//
//  AppAppearanceMode.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/19/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    public var systemImage: String {
        switch self {
        case .system: "circle.righthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

public extension View {
    func appAppearance(_ mode: AppAppearanceMode) -> some View {
        preferredColorScheme(mode.colorScheme)
    }
}

public protocol AppAppearanceModeStoring: Sendable {
    func load() -> AppAppearanceMode
    func save(_ mode: AppAppearanceMode)
}

public final class AppAppearanceModeStore: AppAppearanceModeStoring, @unchecked Sendable {
    private static let key = "appAppearanceMode"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> AppAppearanceMode {
        defaults.string(forKey: Self.key).flatMap(AppAppearanceMode.init(rawValue:)) ?? .system
    }

    public func save(_ mode: AppAppearanceMode) {
        defaults.set(mode.rawValue, forKey: Self.key)
    }
}
