import SwiftUI

@main
struct WakerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Waker", systemImage: state.isRunning ? "bolt.circle.fill" : "bolt.circle") {
            MenuBarContentView(state: state)
                .onAppear {
                    state.handleMenuOpened()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
