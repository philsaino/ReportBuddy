import SwiftUI

class AppDelegateAdapter: NSObject, NSApplicationDelegate {
    let updateService: UpdateService
    
    init(updateService: UpdateService) {
        self.updateService = updateService
        super.init()
    }
}

@main
struct ReportBuddyApp: App {
    @StateObject private var updateService = UpdateService()
    private let appDelegate: AppDelegate
    
    init() {
        // Inizializza prima l'UpdateService
        let updateService = UpdateService()
        
        // Poi inizializza l'AppDelegate con l'UpdateService
        self.appDelegate = AppDelegate(updateService: updateService)
        
        // Imposta l'AppDelegate come delegato dell'applicazione
        NSApplication.shared.delegate = self.appDelegate
        
        // Infine, inizializza lo StateObject
        self._updateService = StateObject(wrappedValue: updateService)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(updateService)
                .task {
                    // Controlla gli aggiornamenti all'avvio
                    await updateService.checkForUpdates()
                    if updateService.updateAvailable {
                        await MainActor.run {
                            appDelegate.showUpdateAlert()
                        }
                    }
                }
        }
        .commands {
            // Aggiungi il menu degli aggiornamenti
            CommandGroup(after: .appInfo) {
                Button(LocalizedStringKey("Verifica Aggiornamenti")) {
                    let updateService = self.updateService
                    let appDelegate = self.appDelegate
                    Task {
                        await updateService.checkForUpdates()
                        if updateService.updateAvailable {
                            await MainActor.run {
                                appDelegate.showUpdateAlert()
                            }
                        } else {
                            await MainActor.run {
                                appDelegate.showNoUpdatesAlert()
                            }
                        }
                    }
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }
    }
} 