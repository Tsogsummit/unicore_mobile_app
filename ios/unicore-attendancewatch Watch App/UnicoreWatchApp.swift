import SwiftUI

@main
struct UnicoreWatchApp: App {
    @StateObject private var connectivity = PhoneConnectivity.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
                .task { connectivity.activate() }
        }
    }
}
