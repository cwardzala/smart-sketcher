import SwiftUI

@main
struct SmartSketcherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 700)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 740)
        #endif
    }
}
