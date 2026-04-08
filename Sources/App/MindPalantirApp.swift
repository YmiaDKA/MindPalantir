import SwiftUI

@main
struct MindPalantirApp: App {
    @State private var store = NodeStore()
    @State private var watcher: WatcherService?
    @State private var relevanceEngine: RelevanceEngine?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
                    do {
                        try store.open()
                        await DataSeeder.seed(store: store)
                        
                        // Start file watcher
                        let w = WatcherService(store: store)
                        w.start()
                        watcher = w
                        
                        // Start relevance engine
                        let engine = RelevanceEngine(store: store)
                        engine.start(interval: 300)
                        relevanceEngine = engine
                        
                        print("🧠 MindPalantir ready — \(store.nodes.count) nodes, \(store.links.count) links")
                    } catch {
                        print("Store open failed: \(error)")
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)
    }
}
