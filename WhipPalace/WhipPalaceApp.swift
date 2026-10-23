import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .portrait
    }
}

@main
struct WhipPalaceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Palette.mainBackground.ignoresSafeArea()
            switch baseScreen {
            case .launch:
                LaunchView()
            case .loadError:
                LoadErrorView()
            case .mainMenu:
                MainMenuView()
            case .palaceMap:
                PalaceMapView()
            case .gameplay:
                GameView()
            case .results:
                ResultsView()
            case .ballAppearance:
                BallAppearanceView()
            case .royalWhipPack:
                RoyalWhipPackView()
            case .howToPlay:
                HowToPlayView()
            case .settings:
                EmptyView()
            case .about:
                AboutView()
            }
            if app.screen == .settings {
                SettingsView()
            }
        }
        .onChange(of: app.purchases.pendingPackPresentation) { _, pending in
            if pending {
                app.presentPackFromAppStoreIfNeeded()
            }
        }
        .onChange(of: app.screen) { _, _ in
            app.presentPackFromAppStoreIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                app.audio.handleBackground()
                if app.screen == .gameplay || (app.screen == .settings && app.settingsOrigin == .gameplay) {
                    app.becomeInactiveDuringGameplay()
                }
            } else if baseScreen != .gameplay {
                app.audio.apply(settings: app.settings.settings)
                if app.screen != .launch && app.screen != .loadError {
                    app.audio.playMenuMusic()
                }
            }
        }
    }

    private var baseScreen: AppScreen {
        if app.screen == .settings {
            return app.settingsOrigin == .gameplay ? .gameplay : app.settingsOrigin
        }
        return app.screen
    }
}
