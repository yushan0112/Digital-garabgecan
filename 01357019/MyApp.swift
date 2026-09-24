import SwiftUI

@main struct MyApp: App {
    /// One store for the whole app; every screen reads it out of the environment.
    @State private var store = YardStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
