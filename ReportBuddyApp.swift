import SwiftUI

@main
struct ReportBuddyApp: App {
    @StateObject private var updateService = UpdateService()
    @NSApplicationDelegateAdaptor(ReportBuddyDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(updateService)
        }
    }
} 