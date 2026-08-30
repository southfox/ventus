//
//  PreferredReadingSize.swift
//  Ventus
//

import Foundation
import SwiftData
import SwiftUI

/// A concise, app-level reading-size choice. Semantic SwiftUI fonts continue
/// to scale naturally; this only selects the preferred Dynamic Type category.
public enum PreferredReadingSize: Int, CaseIterable, Codable, Identifiable, Sendable {
    case small
    case standard
    case large
    case big
    /// Removes Ventus's override and follows the device's Text Size setting.
    case system

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .small: "Small"
        case .standard: "Standard"
        case .large: "Large"
        case .big: "Big"
        case .system: "System"
        }
    }

    public var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .small: .small
        case .standard: .medium
        case .large: .large
        case .big: .xLarge
        case .system: nil
        }
    }

    public var canDecrease: Bool { self != .small && self != .system }
    public var canIncrease: Bool { self != .big && self != .system }

    public func adjusted(by amount: Int) -> Self {
        let sizes: [Self] = [.small, .standard, .large, .big]
        guard let currentIndex = sizes.firstIndex(of: self) else { return .standard }
        return sizes[min(max(currentIndex + amount, 0), sizes.count - 1)]
    }
}

public struct PreferredReadingSizeModifier: ViewModifier {
    public let size: PreferredReadingSize

    @ViewBuilder public func body(content: Content) -> some View {
        if let dynamicTypeSize = size.dynamicTypeSize {
            content.dynamicTypeSize(dynamicTypeSize)
        } else {
            content
        }
    }
}

public extension View {
    func preferredReadingSize(_ size: PreferredReadingSize) -> some View {
        modifier(PreferredReadingSizeModifier(size: size))
    }
}

public protocol PreferredReadingSizeStoring: Sendable {
    func load() -> PreferredReadingSize
    func save(_ size: PreferredReadingSize)
}

public final class PreferredReadingSizeStore: PreferredReadingSizeStoring, @unchecked Sendable {
    private static let key = "preferredReadingSize"
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() -> PreferredReadingSize {
        let context = ModelContext(container)
        let value = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.key })?
            .value
        guard let rawValue = value.flatMap(Int.init) else { return .system }
        return PreferredReadingSize(rawValue: rawValue) ?? .system
    }

    public func save(_ size: PreferredReadingSize) {
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.key }) {
            record.value = String(size.rawValue)
        } else {
            context.insert(VentusPreferenceRecord(key: Self.key, value: String(size.rawValue)))
        }
        try? context.save()
    }
}
