import SwiftUI

@main
struct MedLogAppApp: App { // Replace MedLogAppApp with your app's name
    @StateObject var store = MedicationStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
