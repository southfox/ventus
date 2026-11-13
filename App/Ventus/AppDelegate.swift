//
//  AppDelegate.swift
//  Ventus
//
//  Created by southfox on 07/06/2017.
//  Copyright © 2023 southfox. All rights reserved.
//

import Ventus
import VentusFirebase

#if os(macOS)
import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let environment = AppEnvironment(analytics: VentusFirebase())
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        environment.analytics.configure()
        let window = NSWindow(contentViewController: NSHostingController(rootView: ForecastDashboardView(environment: environment)))
        window.title = "Ventus"
        window.setContentSize(NSSize(width: 1_180, height: 820))
        window.minSize = NSSize(width: 900, height: 650)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        addWidgetMenu()
        ForecastAlertMacBackgroundRefresh.start()
    }

    private func addWidgetMenu() {
        let widgetsMenu = NSMenu(title: "Widgets")
        let addWidgetItem = NSMenuItem(
            title: "Add Ventus Widget…",
            action: #selector(addVentusWidget(_:)),
            keyEquivalent: ""
        )
        addWidgetItem.target = self
        addWidgetItem.setAccessibilityIdentifier("widgets.addForecastWidget")
        widgetsMenu.addItem(addWidgetItem)

        let widgetsMenuItem = NSMenuItem(title: "Widgets", action: nil, keyEquivalent: "")
        widgetsMenuItem.submenu = widgetsMenu
        NSApp.mainMenu?.addItem(widgetsMenuItem)
    }

    @objc private func addVentusWidget(_ sender: Any?) {
        environment.analytics.log(.widgetAddRequested)
        let didOpenGallery = NSApp.sendAction(
            Selector(("showWidgetGallery:")),
            to: nil,
            from: sender
        )

        guard !didOpenGallery else { return }

        let alert = NSAlert()
        alert.messageText = "Add Ventus Widget"
        alert.informativeText = "Open Notification Center, click Edit Widgets, then search for “Ventus”. Choose a size and add it to Notification Center or the desktop."
        alert.addButton(withTitle: "Done")

        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

#elseif os(iOS) || os(tvOS)

import UIKit
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    let environment = AppEnvironment(analytics: VentusFirebase())

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        environment.analytics.configure()
        ForecastAlertBackgroundRefresh.register()
        ForecastAlertBackgroundRefresh.schedule()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }


    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        ForecastAlertBackgroundRefresh.schedule()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var environment: AppEnvironment?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let environment = (UIApplication.shared.delegate as? AppDelegate)?.environment ?? AppEnvironment()
        openForecast(
            from: connectionOptions.userActivities.first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?.webpageURL,
            in: environment
        )
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ForecastDashboardView(environment: environment))
        window.makeKeyAndVisible()
        self.window = window
        self.environment = environment
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let environment else { return }

        openForecast(from: userActivity.webpageURL, in: environment)
        window?.rootViewController = UIHostingController(rootView: ForecastDashboardView(environment: environment))
    }

    private func openForecast(from url: URL?, in environment: AppEnvironment) {
        guard let url,
              ["ventus-52c5b.web.app", "ventus-52c5b.firebaseapp.com"].contains(url.host),
              url.path == "/forecast/bariloche-dina-huapi" else { return }

        environment.selectedSpotStore.save("64141")
    }
}

#elseif os(visionOS)

// visionOS uses VisionVentusApp's SwiftUI lifecycle.

#else

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
}

#endif
