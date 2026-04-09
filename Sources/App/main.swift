import SwiftUI
import AppKit

// Explicit NSApplication setup for macOS 26 compatibility
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store = NodeStore()
    private var watcher: WatcherService?
    private var relevanceEngine: RelevanceEngine?
    private var calendarSyncTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("App launching, setting up window...")

        // Create window FIRST, before async work
        let rootView = RootView()
            .environment(store)
        let hostingView = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MindPalantir"
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSLog("Window created and shown")

        // Now do data work
        Task { @MainActor in
            do {
                try store.open()
                NSLog("DB opened: \(store.dbPath)")
                
                // Seed on first run
                await DataSeeder.seed(store: store)
                NSLog("Seed complete: \(store.nodes.count) nodes, \(store.links.count) links")
                
                // Force checkpoint after bulk insert — critical for WAL persistence
                store.checkpoint()
                NSLog("Checkpoint done after seed")

                // Import calendar events (temporal anchors)
                let calImporter = CalendarImporter()
                let calCount = await calImporter.importEvents(store: store)
                NSLog("📅 Calendar: imported \(calCount) events")
                store.checkpoint()

                // Periodic calendar sync — keeps events fresh
                calendarSyncTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor in
                        let count = await calImporter.importEvents(store: self.store)
                        if count > 0 {
                            NSLog("📅 Calendar sync: \(count) new events")
                            self.store.checkpoint()
                        }
                    }
                }

                // Start background services
                let w = WatcherService(store: store)
                w.start()
                watcher = w

                let engine = RelevanceEngine(store: store)
                engine.start(interval: 300)
                relevanceEngine = engine

                NSLog("Ready: \(store.nodes.count) nodes, \(store.links.count) links")
            } catch {
                NSLog("ERROR: \(error)")
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NSLog("App terminating — closing DB")
        store.close()
    }
}

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
