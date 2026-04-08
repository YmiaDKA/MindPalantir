import SwiftUI

@main
struct MindPalantirApp: App {
    @State private var store = NodeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
                    do {
                        try store.open()
                    } catch {
                        print("Store open failed: \(error)")
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)
    }
}
