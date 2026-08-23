//
//  ForecastDashboardView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 07/22/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS)
import CoreLocation
@preconcurrency import MapKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
public struct ForecastDashboardView: View {
    private enum DashboardSheet: String, Identifiable, Equatable {
        case spotPicker
        case modelPicker
        case login
        case favorites
        case forecastMap
        case weatherBackgroundSettings
        case help
        case about

        var id: String { rawValue }
    }

    private let forecastService: ForecastWindguruProtocol
    private let environment: AppEnvironment
    private let analytics: AnalyticsLogging
    private let spotSearch: @MainActor (String) async throws -> SpotResult?
    private let favoriteSpotsLoader: @MainActor (String, String) async throws -> SpotResult?
    private let spotInfoLoader: @MainActor (String) async throws -> SpotInfo?
    private let usesPreviewForecast: Bool
#if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSpotID: String
    @StateObject private var account: WindguruAccount
    @StateObject private var viewModel: ForecastDashboardViewModel
    @State private var windDirectionDisplayMode: WindDirectionDisplayMode = .arrow
    @State private var gridHourStep: Int
    @State private var activeSheet: DashboardSheet?
    @State private var content: ForecastViewMode
    @State private var weatherBackgroundStyle: WeatherBackgroundStyle
    @State private var theme: VentusTheme
    @State private var appLanguage: AppLanguage
    @State private var appAppearanceMode: AppAppearanceMode
    @State private var showsDashboardModelComparison = false
    @State private var iPadMapPosition: MapCameraPosition = .automatic
    @State private var selectedMapLocationID: SavedMapLocation.ID?
    @State private var favoriteMapLocations = [SavedMapLocation]()
#if os(tvOS)
    @Namespace private var tvDashboardFocus
    @State private var showsTVMenu = false
#endif

    public init(
        forecastService: ForecastWindguruProtocol = ForecastWindguruService(),
        initialViewMode: ForecastViewMode? = nil,
        initialWeatherBackgroundStyle: WeatherBackgroundStyle? = nil,
        previewForecast: SpotForecast? = nil,
        previewModelForecasts: [SpotForecast] = [],
        environment: AppEnvironment
    ) {
        self.forecastService = forecastService
        self.environment = environment
        self.analytics = environment.analytics
        usesPreviewForecast = previewForecast != nil
        let initialSpotID = previewForecast?.identifier ?? environment.selectedSpotStore.load()
        _selectedSpotID = State(initialValue: initialSpotID)
        _weatherBackgroundStyle = State(
            initialValue: initialWeatherBackgroundStyle ?? environment.weatherBackgroundStyleStore.load()
        )
        _theme = State(initialValue: environment.ventusThemeStore.load())
        _content = State(initialValue: initialViewMode ?? environment.forecastViewModeStore.load())
        _gridHourStep = State(initialValue: environment.gridHourStepStore.load())
        _appLanguage = State(initialValue: environment.appLanguageStore.load())
        _appAppearanceMode = State(initialValue: environment.appAppearanceModeStore.load())
        let viewModel = ForecastDashboardViewModel(forecastService: forecastService, environment: environment)
        if let previewForecast {
            viewModel.usePreviewForecast(previewForecast, spotID: initialSpotID, modelForecasts: previewModelForecasts)
        }
        _viewModel = StateObject(wrappedValue: viewModel)
        _showsDashboardModelComparison = State(initialValue: false)
        _account = StateObject(wrappedValue: WindguruAccount(credentialStore: environment.windguruCredentialStore))
        spotSearch = { try await forecastService.searchSpots(byLocation: $0) }
        favoriteSpotsLoader = { try await forecastService.favoriteSpots(withUsername: $0, password: $1) }
        spotInfoLoader = { try await forecastService.spotInfo(bySpotId: $0) }
    }

    private var forecast: SpotForecast? { get { viewModel.forecast } nonmutating set { viewModel.forecast = newValue } }
    private var coordinateLocationName: String? { get { viewModel.coordinateLocationName } nonmutating set { viewModel.coordinateLocationName = newValue } }
    private var errorMessage: String? { get { viewModel.errorMessage } nonmutating set { viewModel.errorMessage = newValue } }
    private var isLoading: Bool { get { viewModel.isLoading } nonmutating set { viewModel.isLoading = newValue } }
    private var selectedHour: String? { get { viewModel.selectedHour } nonmutating set { viewModel.selectedHour = newValue } }
    private var selectedModelIDs: [String] { get { viewModel.selectedModelIDs } nonmutating set { viewModel.selectedModelIDs = newValue } }
    private var usableModelIDs: [String] { get { viewModel.usableModelIDs } nonmutating set { viewModel.usableModelIDs = newValue } }
    private var displayedForecastSpotID: String? { get { viewModel.displayedForecastSpotID } nonmutating set { viewModel.displayedForecastSpotID = newValue } }
    private var modelIDsBySpot: [String: [String]] { get { viewModel.modelIDsBySpot } nonmutating set { viewModel.modelIDsBySpot = newValue } }
    private var selectedModelIDsBySpot: [String: [String]] { get { viewModel.selectedModelIDsBySpot } nonmutating set { viewModel.selectedModelIDsBySpot = newValue } }
    private var modelNamesByID: [String: String] { get { viewModel.modelNamesByID } nonmutating set { viewModel.modelNamesByID = newValue } }
    private var displayedModelForecasts: [SpotForecast] { get { viewModel.displayedModelForecasts } nonmutating set { viewModel.displayedModelForecasts = newValue } }
    private var savedMapLocations: [SavedMapLocation] { get { viewModel.savedMapLocations } nonmutating set { viewModel.savedMapLocations = newValue } }
    private var severeWeatherAlert: ForecastSevereWeatherAlert? { viewModel.severeWeatherAlert }

    private var selectedHourBinding: Binding<String?> {
        Binding(get: { viewModel.selectedHour }, set: { viewModel.selectedHour = $0 })
    }

    private var usesWideLayout: Bool {
#if os(macOS) || os(tvOS)
        true
#else
        horizontalSizeClass == .regular
#endif
    }

    private var isProUser: Bool {
        account.isProUser && account.isAuthenticated
    }

    private func sheetBinding(_ sheet: DashboardSheet) -> Binding<Bool> {
        Binding(
            get: { activeSheet == sheet },
            set: { isPresented in
                if isPresented {
                    activeSheet = sheet
                } else if activeSheet == sheet {
                    activeSheet = nil
                }
            }
        )
    }

    private var accountMenu: some View {
        DashboardAccountMenu(
            isShowingGrid: content == .grid,
            isShowingWorkspace: content == .workspace,
            isShowingGraph: content == .graph,
            isShowingOverview: content == .overview,
            showsWorkspaceOption: ForecastViewMode.workspace.isAvailable,
            showsOverviewOption: ForecastViewMode.overview.isAvailable,
            isLoggedIn: !account.username.isEmpty,
            onShowDashboard: { setContent(.dashboard) },
            onShowGrid: { setContent(.grid) },
            onShowWorkspace: { setContent(.workspace) },
            onShowGraph: { setContent(.graph) },
            onShowOverview: { setContent(.overview) },
            onShowSettings: { activeSheet = .weatherBackgroundSettings },
            onShowHelp: { activeSheet = .help },
            onShowAbout: { activeSheet = .about },
            onShowAccount: { activeSheet = .login },
            onShowFavorites: { activeSheet = .favorites },
            onLogout: logout
        )
    }

#if os(tvOS)
    private var tvMenu: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tvMenuButton("Forecast Dashboard", symbol: "rectangle.3.group") { setContent(.dashboard) }
                    tvMenuButton("Forecast Grid", symbol: "tablecells") { setContent(.grid) }
                    tvMenuButton("Grid and Dashboard", symbol: "rectangle.split.2x1") { setContent(.workspace) }
                    tvMenuButton("Forecast Graph", symbol: "chart.xyaxis.line") { setContent(.graph) }
                    tvMenuButton("Overview", symbol: "square.grid.2x2") { setContent(.overview) }

                    Divider()

                    tvMenuButton("Settings", symbol: "gearshape") { presentTVMenuSheet(.weatherBackgroundSettings) }
                    tvMenuButton("Help", symbol: "questionmark.circle") { presentTVMenuSheet(.help) }
                    tvMenuButton("About", symbol: "info.circle") { presentTVMenuSheet(.about) }

                    Divider()

                    if account.username.isEmpty {
                        tvMenuButton("Login", symbol: "person.crop.circle") { presentTVMenuSheet(.login) }
                    } else {
                        tvMenuButton("Profile", symbol: "person.crop.circle") { presentTVMenuSheet(.login) }
                        tvMenuButton("Favorites", symbol: "star") { presentTVMenuSheet(.favorites) }
                        tvMenuButton("Logout", symbol: "rectangle.portrait.and.arrow.right", role: .destructive, action: logout)
                    }
                }
                .frame(maxWidth: 700, alignment: .leading)
                .padding(48)
            }
            .navigationTitle("Menu")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { showsTVMenu = false }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close menu")
                }
            }
        }
    }

    private func tvMenuButton(
        _ title: String,
        symbol: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) {
            showsTVMenu = false
            action()
        } label: {
            Label(title, systemImage: symbol)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func presentTVMenuSheet(_ sheet: DashboardSheet) {
        showsTVMenu = false
        DispatchQueue.main.async {
            activeSheet = sheet
        }
    }
#endif

    private func setContent(_ mode: ForecastViewMode) {
        content = mode
        analytics.log(.viewModeChanged(mode.rawValue))
    }

    private func logout() {
        analytics.log(.logoutTapped)
        account.signOut()
        selectedSpotID = SavedMapLocationStore.primarySpotID
        viewModel.resetSessionForecastState()
        viewModel.clearPersistedSessionData()
        favoriteMapLocations = []
        selectedMapLocationID = nil

        applyDevicePreferences()

        activeSheet = nil
        Task { await loadForecast() }
    }

    private func startSession(username: String, isProUser: Bool) {
        account.signIn(username: username, isProUser: isProUser)
        viewModel.resetSessionForecastState()
        activeSheet = nil
        Task {
            await loadFavoriteMapLocations()
            await loadPreferredForecast()
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let forecast {
                    Group {
                        if content == .grid {
                            forecastGridContent(for: forecast)
                        } else if content == .workspace {
                            forecastWorkspaceContent(for: forecast)
                        } else if content == .graph {
                            ForecastGraphView(
                                forecast: forecast,
                                selectedHour: selectedHourBinding,
                                coordinateLocationName: coordinateLocationName,
                                windSpeedUnit: $viewModel.windSpeedUnit,
                                waveHeightUnit: $viewModel.waveHeightUnit,
                                modelForecasts: displayedModelForecasts,
                                modelNamesByID: modelNamesByID,
                                isModelComparisonEnabled: $showsDashboardModelComparison,
                                onSelectLocation: { activeSheet = .spotPicker },
                                onShowMap: { activeSheet = .forecastMap }
                            )
                        } else if content == .overview {
                            overviewContent(for: forecast)
                        } else {
                            forecastContent(for: forecast)
                        }
                    }
                } else if isLoading {
                    ProgressView("Loading forecast…")
                } else if let errorMessage {
                    unavailableForecastContent(errorMessage: errorMessage)
                } else {
                    ContentUnavailableView("Forecast unavailable", systemImage: "cloud.sun")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top) {
                if let severeWeatherAlert {
                    Label(severeWeatherAlert.title, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.red.gradient)
                        .accessibilityLabel(severeWeatherAlert.title + ". " + severeWeatherAlert.body)
                }
            }
            .background {
                if let forecast {
                    if content == .graph {
                        Group {
                            if theme.usesMaterial {
                                Rectangle().fill(.ultraThinMaterial)
                            } else {
                                theme.backgroundColor(for: colorScheme)
                            }
                        }
                        .ignoresSafeArea()
                    } else {
                        weatherBackground(for: forecast)
                    }
                }
            }
            .navigationTitle("Ventus")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
#if os(macOS)
                ToolbarItem(placement: .navigation) {
                    accountMenu
                }
#elseif os(tvOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsTVMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Menu")
                }
#else
                ToolbarItem(placement: .topBarLeading) {
                    accountMenu
                }
#endif
                ToolbarItem(placement: .primaryAction) {
                    HStack {
#if os(tvOS)
                        Button {
                            Task { await loadForecast() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Refresh forecast")
#else
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await loadForecast() }
                        }
#endif
                        if (content == .dashboard || content == .graph), displayedModelForecasts.count > 1 {
#if os(tvOS)
                            Button {
                                showsDashboardModelComparison.toggle()
                            } label: {
                                Image(systemName: "arrow.left.and.right")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Compare models")
                            .opacity(showsDashboardModelComparison ? 1 : 0.6)
#else
                            Button("Compare models", systemImage: "arrow.left.and.right") {
                                showsDashboardModelComparison.toggle()
                            }
                            .tint(showsDashboardModelComparison ? .accentColor : .secondary)
#endif
                        }
                    }
                }
            }
            .task {
                guard !usesPreviewForecast else { return }
                await loadUserPreferences()
                await loadFavoriteMapLocations()
                await loadPreferredForecast()
            }
            .onChange(of: selectedSpotID) { _, spotID in environment.selectedSpotStore.save(spotID) }
            .onChange(of: content) { _, mode in environment.forecastViewModeStore.save(mode) }
#if os(tvOS)
            .sheet(isPresented: $showsTVMenu) {
                tvMenu
            }
#endif
            .sheet(isPresented: sheetBinding(.spotPicker), onDismiss: {
                refreshSavedMapLocations()
                Task { await loadFavoriteMapLocations() }
            }) {
                WindguruSpotPicker(
                    forecastService: forecastService,
                    account: account,
                    environment: environment,
                    onSpotSelected: { spot in
                        guard let spotId = spot.identifier else { return }
                        activeSheet = nil
                        Task { await loadForecast(spotId: spotId) }
                    },
                    onSpotIDSelected: { spotID in
                        activeSheet = nil
                        Task { await loadForecast(spotId: spotID) }
                    },
                    onFavoriteSelected: { spot in
                        guard let spotID = spot.identifier else { return }
                        activeSheet = nil
                        Task { await loadForecast(spotId: spotID) }
                    },
                    onCoordinateSelected: { coordinate, locationName in
                        activeSheet = nil
                        Task { await loadForecast(coordinate: coordinate, locationName: locationName) }
                    }
                )
#if os(macOS)
                .macSheetFrame(widthFraction: 0.45, minWidth: 560, heightFraction: 0.55, minHeight: 520)
#endif
            }
            .sheet(isPresented: sheetBinding(.modelPicker)) {
                let forecastSpotID = displayedForecastSpotID ?? selectedSpotID
                let availableModelIDs = modelIDsBySpot[forecastSpotID] ?? []
                let selectedForecastModelIDs = selectedModelIDsBySpot[forecastSpotID] ?? availableModelIDs
                ForecastModelPicker(
                    forecastService: forecastService,
                    spotID: forecastSpotID,
                    selectedModelIDs: Set(selectedForecastModelIDs),
                    usableModelIDs: Set(availableModelIDs),
                    isProUser: isProUser
                ) { modelIDs in
                    activeSheet = nil
                    Task {
                        await loadForecast(
                            spotId: forecastSpotID,
                            modelIDs: modelIDs,
                            persistSelection: forecastSpotID == selectedSpotID
                        )
                    }
                }
            }
            .sheet(isPresented: sheetBinding(.login)) {
                WindguruLoginView(
                    forecastService: forecastService,
                    username: account.username,
                    onLoggedIn: { username, isProUser in
                        if username.isEmpty {
                            logout()
                            return
                        }
                        startSession(username: username, isProUser: isProUser)
                    },
                    onProfileLoaded: applyUserPreferences
                )
#if os(macOS)
                .macSheetFrame(widthFraction: 0.4, minWidth: 520, heightFraction: 0.45, minHeight: 420)
#endif
            }
            .sheet(isPresented: sheetBinding(.favorites), onDismiss: {
                Task { await loadFavoriteMapLocations() }
            }) {
                WindguruFavoritesView(
                    forecastService: forecastService,
                    account: account,
                    onSpotSelected: { spot in
                        guard let spotID = spot.identifier else { return }
                        activeSheet = nil
                        Task { await loadForecast(spotId: spotID) }
                    }
                )
#if os(macOS)
                .macSheetFrame(widthFraction: 0.45, minWidth: 560, heightFraction: 0.55, minHeight: 520)
#endif
            }
            .sheet(isPresented: sheetBinding(.weatherBackgroundSettings)) {
                SettingsView(
                    weatherBackgroundStyle: $weatherBackgroundStyle,
                    forecastViewMode: $content,
                    theme: $theme,
                    appLanguage: $appLanguage,
                    appAppearanceMode: $appAppearanceMode,
                    gridHourStep: $gridHourStep,
                    forecastService: forecastService,
                    account: account,
                    environment: environment
                )
            }
            .sheet(isPresented: sheetBinding(.help)) {
                NavigationStack {
                    VentusHelpView()
                }
#if os(tvOS)
                .presentationDetents([.large])
#endif
            }
            .sheet(isPresented: sheetBinding(.about)) {
                aboutSheet
            }
#if !os(tvOS)
            .sheet(isPresented: sheetBinding(.forecastMap)) {
                MapLocationPicker(
                    initialCoordinate: forecast?.location?.coordinate,
                    isSelectionEnabled: false,
                    savedLocations: savedMapLocations,
                    favoriteLocations: favoriteMapLocations,
                    forecast: forecast,
                    selectedForecastHour: selectedHour,
                    environment: environment,
                    onSelection: { _ in }
                )
#if os(macOS)
                .macSheetFrame(widthFraction: 0.6, minWidth: 640, heightFraction: 0.6, minHeight: 520)
#endif
            }
#endif
        }
        .modifier(VentusThemeModifier(theme: theme))
        .appLanguage(appLanguage)
        .appAppearance(appAppearanceMode)
        .id(appLanguage)
        .environment(\.appEnvironment, environment)
        .forecastAccessibilityContainer(
            "Ventus forecast dashboard",
            hint: "Choose a location, forecast hour, view mode, or settings.",
            identifier: "forecast.dashboard"
        )
    }

    @ViewBuilder
    private var aboutSheet: some View {
        NavigationStack {
            AboutView()
        }
#if os(macOS)
        .macSheetFrame(widthFraction: 0.5, minWidth: 640, heightFraction: 0.5, minHeight: 480)
#endif
    }

    private func steppedHours(for forecast: SpotForecast) -> [String] {
        forecast.steppedForecastHours(anchorHour: forecast.currentForecastHour, step: environment.gridHourStepStore.load(), includingPast: false)
    }

    private func moveSelectedHour(by offset: Int, in forecast: SpotForecast) {
        let hours = steppedHours(for: forecast)
        guard let currentHour = selectedHour ?? forecast.currentForecastHour,
              let currentIndex = hours.firstIndex(of: currentHour) else { return }
        let newIndex = hours.index(currentIndex, offsetBy: offset)
        guard hours.indices.contains(newIndex) else { return }
        selectedHour = hours[newIndex]
    }

#if !os(tvOS)
    private func hourSwipeGesture(for forecast: SpotForecast) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.3, abs(horizontal) > 40 else { return }
                moveSelectedHour(by: horizontal < 0 ? 1 : -1, in: forecast)
            }
    }
#endif

    @ViewBuilder
    private func overviewContent(for forecast: SpotForecast) -> some View {
#if !os(watchOS) && canImport(WidgetKit)
        WidgetPreviewScreen(
            forecast: forecast,
            coordinateLocationName: coordinateLocationName,
            theme: theme,
            temperatureUnit: $viewModel.temperatureUnit,
            onSelectLocation: { activeSheet = .spotPicker },
            onShowMap: { activeSheet = .forecastMap }
        )
#else
        forecastContent(for: forecast)
#endif
    }

    private func forecastContent(
        for forecast: SpotForecast,
        includesLocationWorkspace: Bool = true,
        showsLocationHeader: Bool = true,
        showsModelSummary: Bool = true,
        isCompactOverview: Bool = false
    ) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                ForecastHourSelector(
                    forecast: forecast,
                    selectedHour: selectedHourBinding
                )
#if os(tvOS)
                .prefersDefaultFocus(true, in: tvDashboardFocus)
#endif
                ForecastDaylightSummary(forecast: forecast)

                if usesWideLayout {
                    HStack(alignment: .top, spacing: 56) {
                        VStack(alignment: .leading, spacing: 28) {
                            ForecastOverview(forecast: forecast, selectedHour: selectedHour, temperatureUnit: $viewModel.temperatureUnit, coordinateLocationName: coordinateLocationName, modelForecasts: displayedModelForecasts, modelNamesByID: modelNamesByID, isModelComparisonEnabled: showsDashboardModelComparison, showsLocationHeader: showsLocationHeader, showsModelSummary: showsModelSummary, isCompact: isCompactOverview, onSelectLocation: { activeSheet = .spotPicker }, onSelectModel: { activeSheet = .modelPicker }, onShowMap: { activeSheet = .forecastMap })
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 28) {
                            ForecastWindDetails(forecast: forecast, selectedHour: selectedHour, windSpeedUnit: $viewModel.windSpeedUnit, windDirectionDisplayMode: $windDirectionDisplayMode, temperatureUnit: $viewModel.temperatureUnit, modelForecasts: displayedModelForecasts, modelNamesByID: modelNamesByID, isModelComparisonEnabled: showsDashboardModelComparison)
                            ForecastWeatherDetails(forecast: forecast, selectedHour: selectedHour, waveHeightUnit: $viewModel.waveHeightUnit, precipitationUnit: $viewModel.precipitationUnit, freezingLevelUnit: $viewModel.freezingLevelUnit, pressureUnit: $viewModel.pressureUnit, modelForecasts: displayedModelForecasts, modelNamesByID: modelNamesByID, isModelComparisonEnabled: showsDashboardModelComparison)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if includesLocationWorkspace {
#if !os(tvOS)
                        DashboardLocationWorkspace(
                            savedLocations: savedMapLocations,
                            favoriteLocations: favoriteLocationsNotSaved,
                            mapPosition: $iPadMapPosition,
                            selectedLocationID: $selectedMapLocationID,
                            selectedHour: selectedHour,
                            forecast: forecast,
                            onManageLocations: { activeSheet = .spotPicker },
                            onSelectLocation: selectMapLocation
                        )
#endif
                    }

                    ForecastIntelligenceSummary(forecast: forecast, hour: selectedHour, coordinateLocationName: coordinateLocationName, temperatureUnit: viewModel.temperatureUnit, windSpeedUnit: viewModel.windSpeedUnit, precipitationUnit: viewModel.precipitationUnit, freezingLevelUnit: viewModel.freezingLevelUnit, pressureUnit: viewModel.pressureUnit, waveHeightUnit: viewModel.waveHeightUnit)
                } else {
                    VStack(spacing: 24) {
                        ForecastOverview(forecast: forecast, selectedHour: selectedHour, temperatureUnit: $viewModel.temperatureUnit, coordinateLocationName: coordinateLocationName, modelForecasts: displayedModelForecasts, modelNamesByID: modelNamesByID, isModelComparisonEnabled: showsDashboardModelComparison, showsLocationHeader: showsLocationHeader, showsModelSummary: showsModelSummary, isCompact: isCompactOverview, onSelectLocation: { activeSheet = .spotPicker }, onSelectModel: { activeSheet = .modelPicker }, onShowMap: { activeSheet = .forecastMap })
                        ForecastWindDetails(forecast: forecast, selectedHour: selectedHour, windSpeedUnit: $viewModel.windSpeedUnit, windDirectionDisplayMode: $windDirectionDisplayMode, temperatureUnit: $viewModel.temperatureUnit, modelForecasts: displayedModelForecasts, modelNamesByID: modelNamesByID, isModelComparisonEnabled: showsDashboardModelComparison)
                        ForecastWeatherDetails(forecast: forecast, selectedHour: selectedHour, waveHeightUnit: $viewModel.waveHeightUnit, precipitationUnit: $viewModel.precipitationUnit, freezingLevelUnit: $viewModel.freezingLevelUnit, pressureUnit: $viewModel.pressureUnit, modelForecasts: displayedModelForecasts, modelNamesByID: modelNamesByID, isModelComparisonEnabled: showsDashboardModelComparison)
                        ForecastIntelligenceSummary(forecast: forecast, hour: selectedHour, coordinateLocationName: coordinateLocationName, temperatureUnit: viewModel.temperatureUnit, windSpeedUnit: viewModel.windSpeedUnit, precipitationUnit: viewModel.precipitationUnit, freezingLevelUnit: viewModel.freezingLevelUnit, pressureUnit: viewModel.pressureUnit, waveHeightUnit: viewModel.waveHeightUnit)
                    }
                }

            }
            .frame(maxWidth: forecastContentMaximumWidth)
            .padding()
        }
#if os(tvOS)
        .focusScope(tvDashboardFocus)
#endif
#if !os(tvOS)
        .simultaneousGesture(hourSwipeGesture(for: forecast))
#endif
    }

    private var forecastContentMaximumWidth: CGFloat? {
#if os(tvOS)
        nil
#else
        1_100
#endif
    }

    @ViewBuilder
    private func weatherBackground(for forecast: SpotForecast) -> some View {
        ZStack {
            if theme.usesMaterial {
                Rectangle().fill(.ultraThinMaterial)
            } else {
                theme.backgroundColor(for: colorScheme)
            }
            WeatherBackgroundRenderer(
                style: weatherBackgroundStyle,
                forecast: forecast,
                hour: selectedHour
            )
            .opacity(theme.weatherBackgroundOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private func forecastGridContent(for forecast: SpotForecast) -> some View {
        let isCoordinateForecast = coordinateLocationName != nil
        let forecastSpotID = displayedForecastSpotID ?? selectedSpotID
        let availableModelIDs = isCoordinateForecast
            ? usableModelIDs
            : modelIDsBySpot[forecastSpotID] ?? usableModelIDs
        let selectedForecastModelIDs = isCoordinateForecast
            ? selectedModelIDs
            : selectedModelIDsBySpot[forecastSpotID] ?? selectedModelIDs

        return WindguruForecastGridView(
            forecast: forecast,
            coordinateLocationName: coordinateLocationName,
            viewModel: viewModel,
            availableModelIDs: availableModelIDs,
            selectedModelIDs: selectedForecastModelIDs,
            windDirectionDisplayMode: $windDirectionDisplayMode,
            gridHourStep: $gridHourStep,
            onSelectLocation: { activeSheet = .spotPicker },
            onToggleModel: { modelID in
                let isEnabling = !selectedForecastModelIDs.contains(modelID)
                toggleGridModel(
                    modelID,
                    for: forecastSpotID,
                    coordinate: isCoordinateForecast ? forecast.location?.coordinate : nil,
                    locationName: coordinateLocationName
                )
                analytics.log(.modelToggled(modelID: modelID, isEnabled: isEnabling))
            },
            onSelectHour: { hour in
                selectedHour = hour
            },
            onShowMap: { activeSheet = .forecastMap },
            onModelComparisonChanged: { isEnabled in
                showsDashboardModelComparison = isEnabled
                analytics.log(.modelComparisonToggled(isEnabled: isEnabled))
            },
            showsModelComparisonInitially: false
        )
        .task(id: availableModelIDs) {
            await viewModel.loadModelNames(for: availableModelIDs)
        }
    }

    private func forecastWorkspaceContent(for forecast: SpotForecast) -> some View {
        ForecastGridDashboardWorkspace(environment: environment) {
            forecastGridContent(for: forecast)
        } dashboard: {
            forecastContent(
                for: forecast,
                includesLocationWorkspace: false,
                showsLocationHeader: false,
                showsModelSummary: false,
                isCompactOverview: true
            )
        }
    }

    private func toggleGridModel(
        _ modelID: String,
        for spotID: String,
        coordinate: CLLocationCoordinate2D? = nil,
        locationName: String? = nil
    ) {
        let availableModelIDs = coordinate == nil ? modelIDsBySpot[spotID] ?? usableModelIDs : usableModelIDs
        var selectedModelIDs = coordinate == nil ? selectedModelIDsBySpot[spotID] ?? self.selectedModelIDs : self.selectedModelIDs

        if selectedModelIDs.contains(modelID) {
            guard selectedModelIDs.count > 1 else { return }
            selectedModelIDs.removeAll { $0 == modelID }
        } else if availableModelIDs.contains(modelID) {
            selectedModelIDs.append(modelID)
        }

        Task {
            if let coordinate {
                await loadForecast(
                    coordinate: coordinate,
                    locationName: locationName,
                    modelIDs: selectedModelIDs
                )
            } else {
                await loadForecast(
                    spotId: spotID,
                    modelIDs: selectedModelIDs,
                    persistSelection: spotID == selectedSpotID
                )
            }
        }
    }

    private func refreshSavedMapLocations() {
        savedMapLocations = environment.savedMapLocationStore.load()
    }

    private var favoriteLocationsNotSaved: [SavedMapLocation] {
        favoriteMapLocations.filter { favorite in
            !savedMapLocations.contains { SavedMapLocationStore.isSameLocation($0, favorite) }
        }
    }

    @MainActor
    private func loadFavoriteMapLocations() async {
        guard !account.username.isEmpty, let password = account.password else {
            favoriteMapLocations = []
            return
        }

        guard let spots = try? await favoriteSpotsLoader(account.username, password)?.allSpots else {
            favoriteMapLocations = []
            return
        }

        var locations = [SavedMapLocation]()
        for spot in spots {
            guard let spotID = spot.identifier,
                  let info = try? await spotInfoLoader(spotID),
                  let coordinate = info.location?.coordinate else { continue }
            let location = SavedMapLocation(
                name: spot.name?.isEmpty == false ? spot.name! : info.name ?? "Windguru spot",
                coordinate: coordinate,
                spotID: spotID,
                placeDescription: spot.countryName ?? info.countryName
            )
            guard !locations.contains(where: { SavedMapLocationStore.isSameLocation($0, location) }) else { continue }
            locations.append(location)
        }
        favoriteMapLocations = locations
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        iPadMapPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
        ))
    }

    private func selectMapLocation(_ location: SavedMapLocation) {
        centerMap(on: location.coordinate)
        if selectedMapLocationID == location.id {
            Task { await loadSavedLocation(location) }
        } else {
            selectedMapLocationID = location.id
        }
    }

    @MainActor
    private func loadSavedLocation(_ location: SavedMapLocation) async {
        if let spotID = location.spotID, spotID != "0" {
            await loadForecast(spotId: spotID)
            return
        }

        if isProUser {
            await loadForecast(
                coordinate: location.coordinate,
                locationName: location.placeDescription?.isEmpty == false
                    ? location.placeDescription
                    : location.name
            )
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard let searchTerm = try await reverseGeocodedSearchTerm(for: clLocation) else {
                errorMessage = "The selected map location could not be identified."
                return
            }
            guard let spotID = try await spotSearch(searchTerm)?.allSpots.first?.identifier else {
                errorMessage = "No Windguru spot was found near the selected map location."
                return
            }
            await loadForecast(spotId: spotID)
        } catch {
            errorMessage = viewModel.forecastErrorMessage(for: error)
        }
    }

    private func reverseGeocodedSearchTerm(for location: CLLocation) async throws -> String? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let mapItem = try await request.mapItems.first else {
            return nil
        }

        return mapItem.addressRepresentations?.cityName
            ?? mapItem.address?.shortAddress
            ?? mapItem.address?.fullAddress
    }

    @MainActor
    private func loadUserPreferences() async {
        guard !account.username.isEmpty,
              let password = account.password,
              let user = await viewModel.loadUserProfile(username: account.username, password: password) else {
            viewModel.applyPersistedUnitPreferences()
            return
        }
        applyUserPreferences(user)
    }

    private func applyUserPreferences(_ user: User) {
        account.update(profile: user)
        viewModel.applyUserProfile(user)
    }

    private func applyDevicePreferences() {
        viewModel.applyDeviceUnitPreferences()
    }

    @MainActor
    private func loadPreferredForecast() async {
        if environment.selectedSpotStore.usesCurrentLocation {
            guard isProUser else {
                environment.selectedSpotStore.saveUsesCurrentLocation(false)
                await loadDefaultForecast()
                return
            }
            await loadCurrentLocationForecast()
            return
        }
        guard !environment.selectedSpotStore.hasSavedSelection else {
            await loadForecast(spotId: selectedSpotID, modelIDs: [])
            return
        }
        await loadDefaultForecast()
    }

    @MainActor
    private func loadDefaultForecast() async {
        let preferredSpotID: String
        if !account.username.isEmpty,
           let password = account.password,
           let favoriteSpotID = try? await favoriteSpotsLoader(account.username, password)?.allSpots.first?.identifier {
            preferredSpotID = favoriteSpotID
        } else {
            preferredSpotID = SavedMapLocationStore.primarySpotID
        }
        await loadForecast(spotId: preferredSpotID, modelIDs: [])
    }

    @MainActor
    private func loadCurrentLocationForecast() async {
        do {
            let location = try await CurrentLocationProvider().location()
            guard !account.username.isEmpty, account.password != nil else {
                await loadDefaultForecast()
                return
            }
            let placeName = try? await resolvePlaceDescription(for: location)
            await loadForecast(coordinate: location.coordinate, locationName: placeName)
        } catch {
            await loadDefaultForecast()
        }
    }

    @MainActor
    private func loadForecast(
        spotId: String? = nil,
        modelIDs: [String]? = nil,
        persistSelection: Bool = true
    ) async {
        let requestedSpotID = spotId ?? selectedSpotID
        let isChangingSpot = requestedSpotID != selectedSpotID
        let didLoad = await viewModel.loadForecast(
            spotID: requestedSpotID,
            modelIDs: modelIDs,
            isChangingSpot: isChangingSpot,
            persistSelection: persistSelection,
            account: account
        )
        if didLoad, persistSelection {
            selectedSpotID = requestedSpotID
            if isChangingSpot {
                analytics.log(.spotSelected(id: requestedSpotID))
            }
        }
        if didLoad, let forecast {
            VentusSpotlightIndexer.index(forecast: forecast, savedLocations: savedMapLocations)
        }
    }

    @MainActor
    private func loadForecast(
        coordinate: CLLocationCoordinate2D,
        locationName: String? = nil,
        modelIDs: [String]? = nil
    ) async {
        await viewModel.loadCoordinateForecast(
            coordinate: coordinate,
            locationName: locationName,
            modelIDs: modelIDs,
            account: account
        )
        if let forecast {
            VentusSpotlightIndexer.index(forecast: forecast, savedLocations: savedMapLocations)
        }
    }

    private func unavailableForecastContent(errorMessage: String) -> some View {
#if DEBUG
        ForecastOfflineView(retry: {
            Task { await loadForecast() }
        }, debugError: errorMessage)
#else
        ForecastOfflineView {
            Task { await loadForecast() }
        }
#endif
    }

}

#Preview("Forecast Dashboard · macOS", traits: .fixedLayout(width: 1_280, height: 900)) {
    let mockup = ForecastWindguruMockup()
    ForecastDashboardView(
        forecastService: mockup,
        initialViewMode: .dashboard,
        initialWeatherBackgroundStyle: .animated,
        previewForecast: mockup.dashboardPreviewForecast,
        previewModelForecasts: mockup.dashboardPreviewForecasts,
        environment: .preview
    )
}
#endif
