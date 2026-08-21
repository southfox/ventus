#if canImport(WidgetKit) && !os(tvOS)
import Ventus
import SwiftUI
import WidgetKit

public struct VentusForecastWidget: Widget {
    public let kind = "org.forescoop.forecast"
    private let environment = AppEnvironment()

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ForecastWidgetProvider()) { entry in
            ForecastWidgetView(entry: entry, theme: environment.ventusThemeStore.load())
        }
        .configurationDisplayName("Forecast")
        .description("Current weather at your selected forecast location.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
#if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline]
#elseif os(iOS)
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            // This family is offered only by iPadOS; declaring it here makes
            // it appear in the larger iPad widget gallery without affecting
            // iPhone's available sizes.
            .systemExtraLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
#elseif os(visionOS)
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait]
#else
        [.systemSmall, .systemMedium, .systemLarge]
#endif
    }
}

#if DEBUG
#Preview("Widget configuration") {
    ForecastWidgetView(entry: .placeholder, theme: .system)
        .frame(width: 320, height: 150)
        .padding()
        .background(.blue.gradient)
}
#endif
#endif
