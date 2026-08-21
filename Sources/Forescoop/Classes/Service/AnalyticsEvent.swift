//
//  AnalyticsEvent.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/20/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation

public enum AnalyticsEvent {
    case screenView(String)
    case spotSelected(id: String)
    case coordinateLocationSelected
    case viewModeChanged(String)
    case forecastLoadSucceeded(spotID: String, modelCount: Int)
    case forecastLoadFailed(spotID: String, reason: String)
    case modelToggled(modelID: String, isEnabled: Bool)
    case modelComparisonToggled(isEnabled: Bool)
    case unitChanged(kind: String, value: String)
    case themeChanged(String)
    case appearanceModeChanged(String)
    case weatherBackgroundChanged(String)
    case languageChanged(String)
    case loginAttempted
    case loginSucceeded
    case loginFailed(reason: String)
    case logoutTapped
    case favoriteAdded(spotID: String)
    case favoriteRemoved(spotID: String)
    case alertCreated(condition: String)
    case alertDeleted
    case widgetAddRequested
    case siriInsightRequested

    var name: String {
        switch self {
        case .screenView: "screen_view"
        case .spotSelected: "spot_selected"
        case .coordinateLocationSelected: "coordinate_location_selected"
        case .viewModeChanged: "view_mode_changed"
        case .forecastLoadSucceeded: "forecast_load_succeeded"
        case .forecastLoadFailed: "forecast_load_failed"
        case .modelToggled: "model_toggled"
        case .modelComparisonToggled: "model_comparison_toggled"
        case .unitChanged: "unit_changed"
        case .themeChanged: "theme_changed"
        case .appearanceModeChanged: "appearance_mode_changed"
        case .weatherBackgroundChanged: "weather_background_changed"
        case .languageChanged: "language_changed"
        case .loginAttempted: "login_attempted"
        case .loginSucceeded: "login"
        case .loginFailed: "login_failed"
        case .logoutTapped: "logout"
        case .favoriteAdded: "favorite_added"
        case .favoriteRemoved: "favorite_removed"
        case .alertCreated: "forecast_alert_created"
        case .alertDeleted: "forecast_alert_deleted"
        case .widgetAddRequested: "widget_add_requested"
        case .siriInsightRequested: "siri_insight_requested"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .screenView(let screenName):
            ["screen_name": screenName, "screen_class": screenName]
        case .spotSelected(let id):
            ["spot_id": id]
        case .coordinateLocationSelected:
            nil
        case .viewModeChanged(let mode):
            ["mode": mode]
        case .forecastLoadSucceeded(let spotID, let modelCount):
            ["spot_id": spotID, "model_count": modelCount]
        case .forecastLoadFailed(let spotID, let reason):
            ["spot_id": spotID, "reason": reason]
        case .modelToggled(let modelID, let isEnabled):
            ["model_id": modelID, "enabled": isEnabled]
        case .modelComparisonToggled(let isEnabled):
            ["enabled": isEnabled]
        case .unitChanged(let kind, let value):
            ["kind": kind, "value": value]
        case .themeChanged(let theme):
            ["theme": theme]
        case .appearanceModeChanged(let mode):
            ["mode": mode]
        case .weatherBackgroundChanged(let style):
            ["style": style]
        case .languageChanged(let language):
            ["language": language]
        case .loginFailed(let reason):
            ["reason": reason]
        case .favoriteAdded(let spotID), .favoriteRemoved(let spotID):
            ["spot_id": spotID]
        case .alertCreated(let condition):
            ["condition": condition]
        case .loginAttempted, .loginSucceeded, .logoutTapped, .alertDeleted,
             .widgetAddRequested, .siriInsightRequested:
            nil
        }
    }
}
