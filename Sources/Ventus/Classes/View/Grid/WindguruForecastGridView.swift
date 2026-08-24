//
//  WindguruForecastGridView.swift
//  Ventus package
//
//  Created by Javier on 07/27/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct WindguruForecastGridView: View {
    public let forecast: SpotForecast
    public let coordinateLocationName: String?
    @ObservedObject private var viewModel: ForecastDashboardViewModel
    public let availableModelIDs: [String]
    public let selectedModelIDs: [String]
    @Binding public var windDirectionDisplayMode: WindDirectionDisplayMode
    @Binding public var gridHourStep: Int
    private let onSelectLocation: () -> Void
    private let onShowMap: () -> Void
    private let onToggleModel: (String) -> Void
    private let onSelectHour: (String) -> Void
    private let onModelComparisonChanged: (Bool) -> Void

    @State private var expandedComparisonRows = Set<String>()
    @State private var modelComparisonMode: ModelComparisonMode = .off
    @State private var showsCloudLayers = false
    @State private var showsRowTitles = true
    @Environment(\.displayScale) private var displayScale
    @Environment(\.ventusTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var horizontalGridOffset: CGFloat = 0
#if os(tvOS)
    @FocusState private var focusedGridHour: String?
#endif
    private var columnWidth: CGFloat {
#if os(tvOS)
        112
#else
        56
#endif
    }

    public init(
        forecast: SpotForecast,
        coordinateLocationName: String? = nil,
        viewModel: ForecastDashboardViewModel,
        availableModelIDs: [String] = [],
        selectedModelIDs: [String] = [],
        windDirectionDisplayMode: Binding<WindDirectionDisplayMode>,
        gridHourStep: Binding<Int>,
        onSelectLocation: @escaping () -> Void,
        onToggleModel: @escaping (String) -> Void,
        onSelectHour: @escaping (String) -> Void,
        onShowMap: @escaping () -> Void = {},
        onModelComparisonChanged: @escaping (Bool) -> Void = { _ in },
        showsModelComparisonInitially: Bool = false
    ) {
        self.forecast = forecast
        self.coordinateLocationName = coordinateLocationName
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.availableModelIDs = availableModelIDs
        self.selectedModelIDs = selectedModelIDs
        _windDirectionDisplayMode = windDirectionDisplayMode
        _gridHourStep = gridHourStep
        self.onSelectLocation = onSelectLocation
        self.onShowMap = onShowMap
        self.onToggleModel = onToggleModel
        self.onSelectHour = onSelectHour
        self.onModelComparisonChanged = onModelComparisonChanged
        _modelComparisonMode = State(initialValue: showsModelComparisonInitially ? .all : .off)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForecastLocationHeader(
                locationName: forecast.locationDisplayName(coordinateLocationName: coordinateLocationName),
                onSelectLocation: onSelectLocation,
                onShowMap: onShowMap
            )

            frozenGrid(scrollsVertically: true)
            ForecastGridModelSelector(
                modelSummaryTitle: forecast.forecast?.modelName ?? "Forecast model",
                modelIDs: availableModelIDs,
                selectedModelIDs: selectedModelIDs,
                modelNamesByID: viewModel.modelNamesByID,
                onToggle: onToggleModel
            )
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Ventus")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .onChange(of: viewModel.displayedModelForecasts.count) { _, count in
            guard count < 2 else { return }
            modelComparisonMode = .off
            expandedComparisonRows = []
            onModelComparisonChanged(false)
        }
        .onAppear { onModelComparisonChanged(isModelComparisonEnabled) }
#if os(tvOS)
        .onChange(of: focusedGridHour) { _, hour in
            guard let hour else { return }
            selectHour(hour)
        }
#endif
        .forecastAccessibilityContainer(
            "Forecast grid for \(forecast.locationDisplayName(coordinateLocationName: coordinateLocationName))",
            hint: "Select an hour to inspect it. The forecast columns can scroll horizontally.",
            identifier: "forecast.grid"
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.displayedModelForecasts.count > 1 {
#if os(tvOS)
                    Button {
                        advanceModelComparisonMode()
                    } label: {
                        Image(systemName: modelComparisonMode.symbolName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(modelComparisonMode.title)
                    .opacity(isModelComparisonEnabled ? 1 : 0.6)
#else
                    Button(
                        modelComparisonMode.title,
                        systemImage: modelComparisonMode.symbolName
                    ) {
                        advanceModelComparisonMode()
                    }
                    .tint(isModelComparisonEnabled ? gridAccentColor : .secondary)
#endif
                }
            }
        }
    }

    private var hours: [String] {
        forecast.steppedForecastHours(anchorHour: forecast.currentForecastHour, step: gridHourStep)
    }

    private var displayedHours: [String] {
        forecast.insertingDaylightEvents(
            into: hours,
            date: { forecast.forecastDate(hour: $0) ?? .distantPast },
            make: { previous, next, _, symbolName in
                SunEventKey(symbolName: symbolName, previousHour: previous, nextHour: next).encoded
            }
        )
    }

    private var weather: Forecast? { forecast.forecast }
    private var hasWaveData: Bool {
        hours.contains { weather?.waveHeight(hh: $0) != nil }
    }
    private var hasWindChillData: Bool {
        forecast.availableForecastHours.contains { weather?.windChill(hh: $0) != nil }
    }

    private func weather(for source: SpotForecast?) -> Forecast? {
        source?.forecast ?? weather
    }

    private func hh(_ canonicalHour: String, source: SpotForecast?) -> String {
        guard let source,
              let sourceInitStamp = source.forecast?.initStamp, sourceInitStamp > 0,
              let baseInitStamp = forecast.forecast?.initStamp, baseInitStamp > 0,
              let canonicalOffset = Int(canonicalHour) else { return canonicalHour }
        let nativeOffsetSeconds = TimeInterval(canonicalOffset) * 3_600 + TimeInterval(baseInitStamp - sourceInitStamp)
        return String(Int((nativeOffsetSeconds / 3_600).rounded()))
    }

    @ViewBuilder
    private func frozenGrid(scrollsVertically: Bool) -> some View {
        if scrollsVertically {
            ZStack(alignment: .topLeading) {
                ScrollView(.vertical) {
                    gridBody(includesHeader: false)
                }
#if canImport(UIKit)
                .background(ScrollViewBounceDisabler())
#endif

                stickyGridHeader
            }
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            gridBody(includesHeader: true)
        }
    }

    private func gridBody(includesHeader: Bool) -> some View {
        ScrollViewReader { scrollProxy in
            HStack(alignment: .top, spacing: cellSpacing) {
                LazyVStack(alignment: .leading, spacing: cellSpacing) {
                    if includesHeader {
                        labelHeader
                    } else {
                        Color.clear.frame(width: rowLabelWidth, height: gridHeaderHeight)
                    }
                    gridRows(in: .labels)
                }
                .frame(width: rowLabelWidth, alignment: .leading)
#if os(tvOS)
                .focusSection()
#endif

                ScrollView(.horizontal) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        LazyHStack(alignment: .top, spacing: 0) {
                            ForEach(displayedHours, id: \.self) { hour in
                                forecastColumn(for: hour, includesHeader: includesHeader)
                                    .id(hour)
                            }
                        }
                    }
                    .padding(.top, includesHeader ? 0 : gridHeaderHeight)
                }
                .contentMargins(.zero, for: .scrollContent)
                .frame(maxWidth: .infinity, alignment: .leading)
#if canImport(UIKit)
                .background(ScrollViewBounceDisabler())
#endif
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.x
                } action: { _, offset in
                    horizontalGridOffset = offset
                }
            }
            .onAppear { scrollToSelectedHour(using: scrollProxy) }
            .onChange(of: viewModel.selectedHour) { _, _ in
                scrollToSelectedHour(using: scrollProxy)
            }
        }
        .padding(.bottom)
    }

    private func scrollToSelectedHour(using proxy: ScrollViewProxy) {
        let hour = viewModel.selectedHour ?? forecast.currentForecastHour
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(hour, anchor: .center)
            }
        }
    }

    private func modelName(for source: SpotForecast) -> String {
        guard let modelID = source.model else { return source.forecast?.modelName ?? "Forecast model" }
        return viewModel.modelNamesByID[modelID] ?? source.forecast?.modelName ?? "Model \(modelID)"
    }

    private func toggleComparisonRow(_ id: String) {
        if modelComparisonMode == .all {
            modelComparisonMode = .selective
        }
        if expandedComparisonRows.contains(id) {
            expandedComparisonRows.remove(id)
        } else {
            expandedComparisonRows.insert(id)
        }
    }

    private var isModelComparisonEnabled: Bool {
        modelComparisonMode != .off
    }

    private var displaysRowTitles: Bool {
        showsRowTitles
    }

    private var comparisonRowIDs: Set<String> {
        var ids: Set<String> = [
            "windSpeed", "windGusts", "windDirection", "temperature", "temperatureReal", "windChill",
            "freezingLevel", "cloudCover", "precipitation", "pressure", "humidity"
        ]
        if hasWaveData {
            ids.formUnion(["waveHeight", "wavePeriod", "waveDirection"])
        }
        return ids
    }

    private func advanceModelComparisonMode() {
        switch modelComparisonMode {
        case .off:
            modelComparisonMode = .selective
            expandedComparisonRows = []
        case .selective:
            modelComparisonMode = .all
            expandedComparisonRows = comparisonRowIDs
        case .all:
            modelComparisonMode = .off
            expandedComparisonRows = []
        }
        onModelComparisonChanged(isModelComparisonEnabled)
    }

    private var labelHeader: some View {
        Button {
            toggleRowTitles()
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .frame(width: rowLabelWidth, height: gridHeaderHeight, alignment: displaysRowTitles ? .leading : .center)
                .background(gridLabelBackground)
                .ventusGlassEffect(theme: theme, in: Rectangle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(displaysRowTitles ? gridAccentColor : .secondary)
        .accessibilityLabel(displaysRowTitles ? "Hide row titles" : "Show row titles")
        .highPriorityGesture(
            TapGesture().onEnded { toggleRowTitles() }
        )
    }

    private func toggleRowTitles() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showsRowTitles.toggle()
        }
    }

    private var timeHeader: some View {
        ForecastGridHourHeader(
            hours: displayedHours,
            columnWidth: columnWidth,
            columnSpacing: 0,
            height: gridHeaderHeight,
            day: day(for:),
            time: time(for:),
            weatherSymbols: weatherSymbols(for:),
            daylightSymbol: daylightSymbol(for:),
            daylightOverlay: daylightColumnOverlay(for:),
            selectedHour: viewModel.selectedHour,
            onSelectHour: selectHour
        )
    }

    private var stickyGridHeader: some View {
        GeometryReader { geometry in
            HStack(spacing: cellSpacing) {
                Color.clear.frame(width: rowLabelWidth, height: gridHeaderHeight)

                timeHeader
                    .offset(x: -horizontalGridOffset)
                    .frame(
                        width: max(0, geometry.size.width - rowLabelWidth - cellSpacing),
                        height: gridHeaderHeight,
                        alignment: .leading
                    )
                    .clipped()
            }
            .overlay(alignment: .leading) {
                labelHeader
            }
        }
        .frame(height: gridHeaderHeight)
        .background(pinnedGridHeaderBackground)
        .ventusGlassEffect(theme: theme, in: Rectangle())
        .zIndex(1)
    }

    private enum GridColumn {
        case labels
        case value(String)
    }

    private struct SunEventKey {
        let symbolName: String
        let previousHour: String
        let nextHour: String

        private static let prefix = "sun:"

        var encoded: String { "\(Self.prefix)\(symbolName):\(previousHour):\(nextHour)" }

        static func decode(_ key: String) -> SunEventKey? {
            guard key.hasPrefix(prefix) else { return nil }
            let parts = key.dropFirst(prefix.count).split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { return nil }
            return SunEventKey(symbolName: parts[0], previousHour: parts[1], nextHour: parts[2])
        }
    }

    private enum ModelComparisonMode {
        case off
        case selective
        case all

        var title: String {
            switch self {
            case .off: "Compare models"
            case .selective: "Compare all"
            case .all: "Stop comparing"
            }
        }

        var symbolName: String {
            switch self {
            case .off: "arrow.left.and.right"
            case .selective: "rectangle.expand.vertical"
            case .all: "rectangle.compress.vertical"
            }
        }
    }

    @ViewBuilder private func gridRows(in column: GridColumn) -> some View {
        gridRow(id: "windSpeed", label: unitLabel("Wind speed (\(viewModel.windSpeedUnit.label))", icon: "wind", selection: $viewModel.windSpeedUnit, unitLabel: \.label), values: { windSpeed($0) }, comparisonValues: { windSpeed($1, source: $0) }, background: windColor, in: column)
        gridRow(id: "windGusts", label: unitLabel("Wind gusts (\(viewModel.windSpeedUnit.label))", icon: "wind.circle.fill", selection: $viewModel.windSpeedUnit, unitLabel: \.label), values: { windGusts($0) }, comparisonValues: { windGusts($1, source: $0) }, background: gustColor, in: column)
        gridRow(id: "windDirection", label: windDirectionLabel, values: { windDirection($0) }, comparisonValues: { windDirection($1, source: $0) }, in: column)
        gridRow(id: "temperature", label: unitLabel("Temperature (\(viewModel.temperatureUnit.label))", icon: "thermometer.medium", selection: $viewModel.temperatureUnit, unitLabel: \.label), values: { temperature($0) }, comparisonValues: { temperature($1, source: $0) }, background: temperatureColor, in: column)
        gridRow(id: "temperatureReal", label: unitLabel("Real temperature (\(viewModel.temperatureUnit.label))", icon: "thermometer.variable.and.figure", selection: $viewModel.temperatureUnit, unitLabel: \.label), values: { temperatureReal($0) }, comparisonValues: { temperatureReal($1, source: $0) }, background: temperatureColor, in: column)
        if hasWindChillData {
            gridRow(id: "windChill", label: unitLabel("Wind chill (\(viewModel.temperatureUnit.label))", icon: "thermometer.snowflake", selection: $viewModel.temperatureUnit, unitLabel: \.label), values: { windChill($0) }, comparisonValues: { windChill($1, source: $0) }, background: temperatureColor, in: column)
        }
        gridRow(id: "freezingLevel", label: unitLabel("Freezing level (\(viewModel.freezingLevelUnit.label))", icon: "snowflake", selection: $viewModel.freezingLevelUnit, unitLabel: \.label), values: { freezingLevel($0) }, comparisonValues: { freezingLevel($1, source: $0) }, in: column)
        cloudRows(in: column)
        gridRow(id: "precipitation", label: unitLabel("Precipitation (\(viewModel.precipitationUnit.label))", icon: "cloud.rain", selection: $viewModel.precipitationUnit, unitLabel: \.label), values: { precipitation($0) }, comparisonValues: { precipitation($1, source: $0) }, background: precipitationColor, in: column)
        gridRow(id: "pressure", label: unitLabel("Pressure (\(viewModel.pressureUnit.label))", icon: "gauge.medium", selection: $viewModel.pressureUnit, unitLabel: \.label), values: { pressure($0) }, comparisonValues: { pressure($1, source: $0) }, background: pressureColor, in: column)
        gridRow(id: "humidity", label: rowLabel("Humidity (%)", icon: "humidity"), values: { humidity($0) }, comparisonValues: { humidity($1, source: $0) }, background: humidityColor, in: column)
        if hasWaveData {
            gridRow(id: "waveHeight", label: unitLabel("Wave (\(viewModel.waveHeightUnit.label))", icon: "water.waves", selection: $viewModel.waveHeightUnit, unitLabel: \.label), values: { waveHeight($0) }, comparisonValues: { waveHeight($1, source: $0) }, background: waveColor, in: column)
            gridRow(id: "wavePeriod", label: rowLabel("Wave period (s)", icon: "waveform"), values: { wavePeriod($0) }, comparisonValues: { wavePeriod($1, source: $0) }, background: wavePeriodColor, in: column)
            gridRow(id: "waveDirection", label: rowLabel("Wave direction", icon: "location.north.line"), values: { waveDirection($0) }, comparisonValues: { waveDirection($1, source: $0) }, in: column)
        }
    }

    @ViewBuilder private func gridRow<Label: View>(
        id: String,
        label: Label,
        values: @escaping (String) -> GridCell,
        comparisonValues: @escaping (SpotForecast, String) -> GridCell,
        showsComparisonControl: Bool = true,
        background: @escaping (GridCell) -> Color = { _ in .clear },
        in column: GridColumn
    ) -> some View {
        let isExpanded = expandedComparisonRows.contains(id)
        switch column {
        case .labels:
            VStack(spacing: cellSpacing) {
                HStack(spacing: 4) {
                    if showsComparisonControl, isModelComparisonEnabled, viewModel.displayedModelForecasts.count > 1 {
                        Button {
                            toggleComparisonRow(id)
                        } label: {
                            Image(systemName: isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(gridAccentColor)
                    }
                    label
                }
                .font(gridRowTitleFont)
                .padding(.horizontal, 8)
                .frame(width: rowLabelWidth, height: gridRowHeight, alignment: displaysRowTitles ? .leading : .center)
                .background(gridLabelBackground)

                if isExpanded {
                    ForEach(Array(viewModel.displayedModelForecasts.enumerated()), id: \.offset) { _, source in
                        Text(modelName(for: source))
                            .font(.caption2)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .frame(width: rowLabelWidth, height: comparisonRowHeight, alignment: displaysRowTitles ? .leading : .center)
                            .background(gridLabelBackground)
                    }
                }
            }
        case .value(let hour):
            VStack(spacing: cellSpacing) {
                forecastValueCell(hour: hour, values: values, background: background)
                if isExpanded {
                    ForEach(Array(viewModel.displayedModelForecasts.enumerated()), id: \.offset) { _, source in
                        forecastValueCell(
                            hour: hour,
                            values: { comparisonValues(source, $0) },
                            background: background,
                            height: comparisonRowHeight
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder private func cloudRows(in column: GridColumn) -> some View {
        if showsCloudLayers {
            cloudLayerRows(in: column)
        } else {
            gridRow(id: "cloudCover", label: cloudCoverLabel("Cloud cover (%)"), values: { cloudCover($0) }, comparisonValues: { cloudCover($1, source: $0) }, background: cloudColor, in: column)
        }
    }

    @ViewBuilder private func cloudLayerRows(in column: GridColumn) -> some View {
        let isComparisonExpanded = expandedComparisonRows.contains("cloudCover")
        switch column {
        case .labels:
            VStack(spacing: cellSpacing) {
                HStack(spacing: 4) {
                    if isModelComparisonEnabled, viewModel.displayedModelForecasts.count > 1 {
                        Button {
                            toggleComparisonRow("cloudCover")
                        } label: {
                            Image(systemName: isComparisonExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(gridAccentColor)
                    }

                    Button {
                        showsCloudLayers.toggle()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                rowIcon("cloud.fill")
                                Text("Cloud cover (%)")
                            }
                            Text("high / mid / low")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .foregroundStyle(gridAccentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
#if os(tvOS)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
#endif
                }
                .font(gridRowTitleFont)
                .padding(.horizontal, 8)
                .frame(width: rowLabelWidth, height: gridRowHeight * 3, alignment: .leading)
                .background(gridLabelBackground)

                if isComparisonExpanded {
                    ForEach(Array(viewModel.displayedModelForecasts.enumerated()), id: \.offset) { _, source in
                        HStack {
                            Text(modelName(for: source))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .frame(width: rowLabelWidth, height: comparisonRowHeight * 3, alignment: .leading)
                        .background(gridLabelBackground)
                    }
                }
            }
        case .value(let hour):
            VStack(spacing: cellSpacing) {
                cloudLayerValueRows(hour: hour)

                if isComparisonExpanded {
                    ForEach(Array(viewModel.displayedModelForecasts.enumerated()), id: \.offset) { _, source in
                        cloudLayerValueRows(hour: hour, source: source, height: comparisonRowHeight)
                    }
                }
            }
        }
    }

    @ViewBuilder private func cloudLayerValueRows(
        hour: String,
        source: SpotForecast? = nil,
        height: CGFloat = 30
    ) -> some View {
        forecastValueCell(hour: hour, values: { cloudCoverHigh($0, source: source) }, background: cloudColor, height: height)
        forecastValueCell(hour: hour, values: { cloudCoverMid($0, source: source) }, background: cloudColor, height: height)
        forecastValueCell(hour: hour, values: { cloudCoverLow($0, source: source) }, background: cloudColor, height: height)
    }

    private func hourColumn(for hour: String) -> some View {
        LazyVStack(spacing: cellSpacing) {
            gridRows(in: .value(hour))
        }
        .frame(width: columnWidth)
    }

    private func forecastColumn(for hour: String, includesHeader: Bool) -> some View {
        VStack(spacing: cellSpacing) {
            if includesHeader {
#if os(tvOS)
                ForecastGridHourCell(
                    hour: hour,
                    columnWidth: columnWidth,
                    height: gridHeaderHeight,
                    day: day(for:),
                    time: time(for:),
                    weatherSymbols: weatherSymbols(for:),
                    daylightSymbol: daylightSymbol(for:),
                    daylightOverlay: daylightColumnOverlay(for:),
                    isSelected: viewModel.selectedHour == hour,
                    onSelect: selectHour,
                    focusedHour: $focusedGridHour
                )
#else
                ForecastGridHourCell(
                    hour: hour,
                    columnWidth: columnWidth,
                    height: gridHeaderHeight,
                    day: day(for:),
                    time: time(for:),
                    weatherSymbols: weatherSymbols(for:),
                    daylightSymbol: daylightSymbol(for:),
                    daylightOverlay: daylightColumnOverlay(for:),
                    isSelected: viewModel.selectedHour == hour,
                    onSelect: selectHour
                )
#endif
            }
            hourColumn(for: hour)
        }
        .overlay {
            if viewModel.selectedHour == hour {
                ForecastGridDataSelectionBorder(cornerRadius: 3)
                    .stroke(gridAccentColor, lineWidth: 2)
            }
        }
    }

    private func forecastValueCell(
        hour: String,
        values: @escaping (String) -> GridCell,
        background: @escaping (GridCell) -> Color,
        height: CGFloat = 30
    ) -> some View {
        let cell = values(hour)
#if os(tvOS)
        return Text(cell.text)
            .font(cell.isDirection ? .title3 : (cell.isSnow ? .body.bold() : .body))
            .monospacedDigit()
            .foregroundStyle(cell.isSnow ? .blue : .primary)
            .frame(width: columnWidth, height: height == 30 ? gridRowHeight : height)
            .background(background(cell))
            .focusable(false)
#else
        return Button {
            selectHour(hour)
        } label: {
            Text(cell.text)
                .font(cell.isDirection ? .body : (cell.isSnow ? .caption.bold() : .caption))
                .monospacedDigit()
                .foregroundStyle(cell.isSnow ? .blue : .primary)
                .frame(width: columnWidth, height: height)
                .background(background(cell))
        }
        .buttonStyle(.plain)
#endif
    }

    @ViewBuilder
    private func unitLabel<Unit>(
        _ title: LocalizedStringKey,
        icon: String,
        selection: Binding<Unit>,
        unitLabel: @escaping (Unit) -> String
    ) -> some View where Unit: CaseIterable & Identifiable & Hashable, Unit.AllCases: RandomAccessCollection, Unit.AllCases.Element == Unit {
        ForecastUnitSelector(title, selection: selection, unitTitle: unitLabel) {
            rowLabel(title, icon: icon, isInteractive: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
    }

    private var windDirectionLabel: some View {
        Button {
            windDirectionDisplayMode = windDirectionDisplayMode.next
        } label: {
            rowLabel("Wind direction (\(windDirectionDisplayMode.indicator))", icon: "location.north.line", isInteractive: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
#if os(tvOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
#endif
    }

    private func cloudCoverLabel(_ title: LocalizedStringKey, showsIcon: Bool = true) -> some View {
        Button {
            showsCloudLayers.toggle()
        } label: {
            if showsIcon {
                rowLabel(title, icon: "cloud.fill", isInteractive: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            } else {
                Text(title)
                    .foregroundStyle(gridAccentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
#if os(tvOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
#endif
        .accessibilityLabel("Cloud cover")
        .accessibilityHint(showsCloudLayers ? "Shows total cloud cover" : "Shows high, mid, and low cloud cover")
    }

    private func rowLabel(
        _ title: LocalizedStringKey,
        icon: String,
        isInteractive: Bool = false
    ) -> some View {
        Group {
            if displaysRowTitles {
                HStack(spacing: 4) {
                    rowIcon(icon)
                    Text(title)
                }
            } else {
                rowIcon(icon)
            }
        }
        .foregroundStyle(isInteractive ? gridAccentColor : Color.primary)
    }

    /// A fixed symbol slot keeps every row title aligned despite SF Symbols
    /// having different intrinsic widths.
    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .symbolRenderingMode(name.hasPrefix("thermometer") ? .multicolor : .monochrome)
            .frame(width: 16, alignment: .center)
    }

    private var rowLabelWidth: CGFloat {
#if os(tvOS)
        return displaysRowTitles ? 250 : 64
#else
        guard displaysRowTitles else { return 44 }
        return 152
#endif
    }
    private var gridHeaderHeight: CGFloat {
#if os(tvOS)
        112
#else
        64
#endif
    }
    private var gridRowHeight: CGFloat {
#if os(tvOS)
        52
#else
        30
#endif
    }
    private var comparisonRowHeight: CGFloat {
#if os(tvOS)
        42
#else
        24
#endif
    }
    private var cellSpacing: CGFloat { 1 / displayScale }
    private var gridRowTitleFont: Font {
#if os(tvOS)
        .caption2
#else
        theme == .sunset ? .caption2 : .caption
#endif
    }
    private var gridAccentColor: Color { theme.accentColor(for: colorScheme) }
    @ViewBuilder private var gridLabelBackground: some View {
        if theme.usesMaterial {
            Rectangle().fill(.thinMaterial)
        } else {
            Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.06)
        }
    }
    @ViewBuilder private var pinnedGridHeaderBackground: some View {
        if theme.usesMaterial {
            Rectangle().fill(.regularMaterial)
        } else if theme != .system {
            theme.backgroundColor(for: colorScheme)
        } else {
#if os(iOS) || os(visionOS)
            Color(uiColor: .systemBackground)
#elseif os(tvOS)
            Color.black.opacity(0.9)
#elseif canImport(AppKit)
            Color(nsColor: .windowBackgroundColor)
#else
            Color.primary.opacity(0.1)
#endif
        }
    }

    private func displayDate(for hour: String) -> Date? {
        if let event = SunEventKey.decode(hour) {
            guard let start = forecast.forecastDate(hour: event.previousHour) else { return nil }
            return event.symbolName == "sunrise.fill" ? forecast.sunriseDate(on: start) : forecast.sunsetDate(on: start)
        }
        return forecast.forecastDate(hour: hour)
    }

    private func day(for hour: String) -> String {
        guard let date = displayDate(for: hour) else { return "" }
        return date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    private func time(for hour: String) -> String {
        guard let date = displayDate(for: hour) else { return hour }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        // Sunrise/sunset rarely land on the hour, so those columns need
        // minute precision ("jm") — real forecast hours are always on the
        // hour, so "j" alone is enough for them.
        formatter.setLocalizedDateFormatFromTemplate(SunEventKey.decode(hour) != nil ? "jm" : "j")
        let timeString = formatter.string(from: date)
        return formatter.dateFormat.contains("a") ? timeString : "\(timeString)h"
    }

    private func daylightColumnOverlay(for hour: String) -> Color {
        guard SunEventKey.decode(hour) == nil, let date = forecast.forecastDate(hour: hour) else { return .clear }
        switch forecast.daylightPhase(at: date) {
        case .night:
            return .black.opacity(theme.usesMaterial ? 0.22 : 0.30)
        case .daylight:
            return .clear
        }
    }

    private func daylightSymbol(for hour: String) -> String? {
        SunEventKey.decode(hour)?.symbolName
    }

    private func weatherSymbols(for hour: String) -> [String] {
        guard SunEventKey.decode(hour) == nil else { return [] }
        return forecast.weatherSymbolNames(hour: hour)
    }

    private func selectHour(_ hour: String) {
        if let event = SunEventKey.decode(hour) {
            onSelectHour(event.previousHour)
        } else {
            onSelectHour(hour)
        }
    }

    private func averagedRaw(_ hour: String, source: SpotForecast?, raw: (String) -> Double?) -> Double? {
        if let event = SunEventKey.decode(hour) {
            guard let a = raw(hh(event.previousHour, source: source)), let b = raw(hh(event.nextHour, source: source)) else { return nil }
            return (a + b) / 2
        }
        return raw(hh(hour, source: source))
    }

    private func windSpeed(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.windSpeed(hh: $0) }),
              let converted = Knots(value).value(in: viewModel.windSpeedUnit) else { return .empty }
        return GridCell(value: converted, text: number(converted), colorValue: value * 1.852)
    }

    private func windGusts(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        let hour = hh(hour, source: source)
        guard let value = weather(for: source)?.windGustsKnots(hh: hour), let converted = Knots(value).value(in: viewModel.windSpeedUnit) else { return .empty }
        return GridCell(value: converted, text: number(converted), colorValue: value * 1.852)
    }

    private func windDirection(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let direction = averagedRaw(hour, source: source, raw: { weather(for: source)?.windDirection(hh: $0) }) else { return .empty }
        return GridCell(value: direction, text: windDirectionText(direction), isDirection: windDirectionDisplayMode == .arrow)
    }

    private func temperature(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.temperature(hh: $0) }) else { return .empty }
        let converted = Temperature(celsius: value).value(in: viewModel.temperatureUnit)
        return GridCell(value: converted, text: number(converted), colorValue: value)
    }

    private func temperatureReal(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.temperatureReal(hh: $0) }) else { return .empty }
        let converted = Temperature(celsius: value).value(in: viewModel.temperatureUnit)
        return GridCell(value: converted, text: number(converted), colorValue: value)
    }

    private func windChill(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.windChill(hh: $0) }) else { return .empty }
        let converted = Temperature(celsius: value).value(in: viewModel.temperatureUnit)
        return GridCell(value: converted, text: number(converted), colorValue: value)
    }

    private func freezingLevel(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.freezingLevelHeightInMeters(hh: $0) }) else { return .empty }
        let converted = FreezingLevel(meters: value).value(in: viewModel.freezingLevelUnit)
        return GridCell(value: converted, text: number(converted, precision: 0))
    }

    private func cloudCover(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.cloudCoverTotal(hh: $0).map(Double.init) }) else { return .empty }
        return GridCell(value: value, text: "\(Int(value.rounded()))")
    }

    private func cloudCoverHigh(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.cloudCoverHigh(hh: $0).map(Double.init) }) else { return .empty }
        return GridCell(value: value, text: "\(Int(value.rounded()))")
    }

    private func cloudCoverMid(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.cloudCoverMid(hh: $0).map(Double.init) }) else { return .empty }
        return GridCell(value: value, text: "\(Int(value.rounded()))")
    }

    private func cloudCoverLow(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.cloudCoverLow(hh: $0).map(Double.init) }) else { return .empty }
        return GridCell(value: value, text: "\(Int(value.rounded()))")
    }

    private func precipitation(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        if let event = SunEventKey.decode(hour) {
            let a = precipitation(event.previousHour, source: source)
            let b = precipitation(event.nextHour, source: source)
            guard let av = a.value, let bv = b.value else { return .empty }
            let averaged = (av + bv) / 2
            return GridCell(
                value: averaged,
                text: number(averaged),
                colorValue: ((a.colorValue ?? av) + (b.colorValue ?? bv)) / 2,
                isSnow: a.isSnow || b.isSnow,
                usesAccumulatedPrecipitation: a.usesAccumulatedPrecipitation || b.usesAccumulatedPrecipitation
            )
        }
        let resolvedHour = hh(hour, source: source)
        let sourceWeather = weather(for: source)
        let accumulatedPrecipitation = sourceWeather?.precipitation(hh: resolvedHour)
        let millimeters = accumulatedPrecipitation ?? sourceWeather?.precipitation1(hh: resolvedHour)
        guard let millimeters else { return .empty }
        let converted = Precipitation(millimeters: millimeters).value(in: viewModel.precipitationUnit)
        let phase = (source ?? forecast).precipitationPhase(hh: resolvedHour)
        return GridCell(
            value: converted,
            text: number(converted),
            colorValue: millimeters,
            isSnow: millimeters > 0 && phase != .rain,
            usesAccumulatedPrecipitation: accumulatedPrecipitation != nil
        )
    }

    private func pressure(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.seaLevelPressure(hh: $0) }) else { return .empty }
        let converted = AtmosphericPressure(hectopascals: value).value(in: viewModel.pressureUnit)
        return GridCell(value: converted, text: number(converted, precision: 0))
    }

    private func humidity(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.relativeHumidity(hh: $0).map(Double.init) }) else { return .empty }
        return GridCell(value: value, text: "\(Int(value.rounded()))")
    }

    private func waveHeight(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.waveHeight(hh: $0) }) else { return .empty }
        let converted = WaveHeight(meters: value).value(in: viewModel.waveHeightUnit)
        return GridCell(value: converted, text: number(converted))
    }

    private func wavePeriod(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.wavePeriod(hh: $0) }) else { return .empty }
        return GridCell(value: value, text: number(value))
    }

    private func waveDirection(_ hour: String, source: SpotForecast? = nil) -> GridCell {
        guard let value = averagedRaw(hour, source: source, raw: { weather(for: source)?.waveDirection(hh: $0) }) else { return .empty }
        return GridCell(value: value, text: WindDirectionDisplayMode.arrow(forTravelToward: value), isDirection: true)
    }

    private func number(_ value: Double, precision: Int = 0) -> String {
        value.forecastFormatted(precision: precision)
    }

    private func windDirectionText(_ direction: Double) -> String {
        windDirectionDisplayMode.text(forWindFrom: direction)
    }

    private func windColor(_ cell: GridCell) -> Color {
        let kilometersPerHour = cell.colorValue ?? cell.value
        return profileColor(viewModel.userProfile?.windColor, value: kilometersPerHour)
            ?? .cyan.opacity(min((kilometersPerHour ?? 0) / 80, 1) * 0.55)
    }

    private func gustColor(_ cell: GridCell) -> Color {
        let kilometersPerHour = cell.colorValue ?? cell.value
        return profileColor(viewModel.userProfile?.windColor, value: kilometersPerHour)
            ?? .mint.opacity(min((kilometersPerHour ?? 0) / 100, 1) * 0.65)
    }

    private func temperatureColor(_ cell: GridCell) -> Color {
        guard let displayedTemperature = cell.value else { return .clear }
        let celsius = cell.colorValue ?? (viewModel.temperatureUnit == .celsius
            ? displayedTemperature
            : (displayedTemperature - 32) * 5 / 9)
        if let profileColor = profileColor(viewModel.userProfile?.temperatureColor, value: celsius) {
            return profileColor
        }
        let intensity = min(max((celsius + 10) / 40, 0), 1)
        return .yellow.opacity(0.08 + (intensity * 0.62))
    }
    private func cloudColor(_ cell: GridCell) -> Color { profileColor(viewModel.userProfile?.cloudColor, value: cell.value) ?? .gray.opacity(min((cell.value ?? 0) / 100, 1) * 0.65) }
    private func precipitationColor(_ cell: GridCell) -> Color {
        let profile = cell.usesAccumulatedPrecipitation
            ? viewModel.userProfile?.precipitationColor
            : viewModel.userProfile?.precip1Color
        let millimeters = cell.colorValue ?? cell.value
        return profileColor(profile, value: millimeters) ?? .blue.opacity(min((millimeters ?? 0) / 5, 1) * 0.5)
    }
    private func humidityColor(_ cell: GridCell) -> Color { profileColor(viewModel.userProfile?.rhColor, value: cell.value) ?? .yellow.opacity(min((cell.value ?? 0) / 100, 1) * 0.4) }
    private func pressureColor(_ cell: GridCell) -> Color { profileColor(viewModel.userProfile?.pressureColor, value: cell.value) ?? .clear }
    private func waveColor(_ cell: GridCell) -> Color { profileColor(viewModel.userProfile?.waveHeightColor, value: cell.value) ?? .cyan.opacity(min((cell.value ?? 0) / 4, 1) * 0.5) }
    private func wavePeriodColor(_ cell: GridCell) -> Color { profileColor(viewModel.userProfile?.wavePeriodColor, value: cell.value) ?? .clear }

    private func profileColor(_ colors: [CustomColor]?, value: Double?) -> Color? {
        guard let value, let colors, !colors.isEmpty else { return nil }
        let palette = colors.compactMap { color -> (threshold: Double, color: CustomColor)? in
            guard let threshold = Double(color.info ?? "") else { return nil }
            return (threshold, color)
        }
        guard let selected = palette
            .sorted(by: { $0.threshold < $1.threshold })
            .last(where: { value >= $0.threshold }) ?? palette.min(by: { $0.threshold < $1.threshold }) else {
            return nil
        }
        let red = Double(selected.color.red / 255)
        let green = Double(selected.color.green / 255)
        let blue = Double(selected.color.blue / 255)
        let sourceOpacity = Double(selected.color.alpha)
        let opacity: Double
        if colorScheme == .dark {
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            opacity = luminance > 0.72
                ? min(sourceOpacity, 0.30)
                : min(sourceOpacity, 0.78)
        } else {
            opacity = sourceOpacity
        }

        return Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    private struct GridCell {
        let value: Double?
        let text: String
        var colorValue: Double? = nil
        var isDirection = false
        var isSnow = false
        var usesAccumulatedPrecipitation = false

        static let empty = GridCell(value: nil, text: "—", colorValue: nil)
    }
}

#if canImport(UIKit)
private struct ScrollViewBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView(frame: .zero) }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            var ancestor = view.superview
            while let current = ancestor {
                if let scrollView = current as? UIScrollView {
                    scrollView.bounces = false
                    scrollView.alwaysBounceHorizontal = false
                    scrollView.alwaysBounceVertical = false
                    return
                }
                ancestor = current.superview
            }
        }
    }
}
#endif

#if DEBUG

#Preview("WindguruForecastGridView") {
    WindguruForecastGridPreview()
}

private struct WindguruForecastGridPreview: View {
    private let models: [SpotForecast]
    private let forecast: SpotForecast?
    @StateObject private var viewModel: ForecastDashboardViewModel

    init() {
        let mockup = ForecastWindguruMockup()
        let models = mockup.dashboardPreviewForecasts
        self.models = models
        forecast = models.first
        let viewModel = ForecastDashboardViewModel(forecastService: mockup, environment: .preview)
        if let forecast = models.first {
            viewModel.usePreviewForecast(forecast, spotID: forecast.identifier ?? SavedMapLocationStore.primarySpotID, modelForecasts: models)
        }
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        if let forecast {
            let modelIDs = models.compactMap(\.model)
        NavigationStack {
            WindguruForecastGridView(
                forecast: forecast,
                viewModel: viewModel,
                availableModelIDs: modelIDs,
                selectedModelIDs: modelIDs,
                windDirectionDisplayMode: .constant(.arrow),
                gridHourStep: .constant(1),
                onSelectLocation: {},
                onToggleModel: { _ in },
                onSelectHour: { _ in },
                showsModelComparisonInitially: false
            )
        }
        } else {
            ContentUnavailableView("Preview forecast unavailable", systemImage: "exclamationmark.triangle")
        }
    }
}

#endif

#endif
