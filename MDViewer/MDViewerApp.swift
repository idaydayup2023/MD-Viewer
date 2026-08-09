import SwiftUI

@main
struct MDViewerApp: App {
    @StateObject private var model = ReaderModel()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacApplicationDelegate.self)
    private var applicationDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ReaderRootView()
                .environmentObject(model)
                .onOpenURL { model.open($0) }
                #if os(macOS)
                .onAppear {
                    applicationDelegate.attach(to: model)
                }
                #endif
        }
        .commands {
            ReaderCommands(model: model)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 420)
                .padding()
        }
        #endif
    }
}
