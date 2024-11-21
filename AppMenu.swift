import SwiftUI
import AppKit

final class ReportBuddyDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    private let updateService = UpdateService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        
        // ReportBuddy Menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: "ReportBuddy", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        
        // About
        appMenu.addItem(withTitle: NSLocalizedString("About ReportBuddy", comment: ""),
                       action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                       keyEquivalent: "")
        
        appMenu.addItem(.separator())
        
        // Preferences
        appMenu.addItem(withTitle: NSLocalizedString("Preferences...", comment: ""),
                       action: #selector(openPreferences),
                       keyEquivalent: ",")
        
        appMenu.addItem(.separator())
        
        // Check for Updates
        appMenu.addItem(withTitle: NSLocalizedString("Check for Updates...", comment: ""),
                       action: #selector(checkForUpdates),
                       keyEquivalent: "u")
        
        appMenu.addItem(.separator())
        
        // Quit
        appMenu.addItem(withTitle: NSLocalizedString("Quit ReportBuddy", comment: ""),
                       action: #selector(NSApplication.terminate(_:)),
                       keyEquivalent: "q")
        
        // File Menu
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        
        fileMenu.addItem(withTitle: NSLocalizedString("Refresh", comment: ""),
                        action: #selector(refreshEvents),
                        keyEquivalent: "r")
        
        fileMenu.addItem(withTitle: NSLocalizedString("Export via Email", comment: ""),
                        action: #selector(exportViaEmail),
                        keyEquivalent: "e")
        
        // Window Menu
        let windowMenu = NSMenu(title: NSLocalizedString("Window", comment: ""))
        let windowMenuItem = NSMenuItem(title: NSLocalizedString("Window", comment: ""), action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        
        windowMenu.addItem(withTitle: NSLocalizedString("Minimize", comment: ""),
                          action: #selector(NSWindow.miniaturize(_:)),
                          keyEquivalent: "m")
        
        windowMenu.addItem(withTitle: NSLocalizedString("Zoom", comment: ""),
                          action: #selector(NSWindow.zoom(_:)),
                          keyEquivalent: "")
        
        windowMenu.addItem(.separator())
        
        windowMenu.addItem(withTitle: NSLocalizedString("Bring All to Front", comment: ""),
                          action: #selector(NSApplication.arrangeInFront(_:)),
                          keyEquivalent: "")
        
        // Help Menu
        let helpMenu = NSMenu(title: NSLocalizedString("Help", comment: ""))
        let helpMenuItem = NSMenuItem(title: NSLocalizedString("Help", comment: ""), action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        
        helpMenu.addItem(withTitle: NSLocalizedString("ReportBuddy Help", comment: ""),
                        action: #selector(showHelp),
                        keyEquivalent: "?")
        
        // Add all menus to main menu
        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(windowMenuItem)
        mainMenu.addItem(helpMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
        NSApplication.shared.windowsMenu = windowMenu
    }
    
    @objc func openPreferences() {
        if settingsWindow == nil {
            let viewModel = CalendarViewModel()
            let contentView = EmailSettingsView(settings: .constant(viewModel.settings))
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 800),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = NSLocalizedString("Preferences", comment: "")
            settingsWindow?.contentView = NSHostingView(rootView: contentView)
            settingsWindow?.center()
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func checkForUpdates() {
        Task {
            await updateService.checkForUpdates()
            if updateService.updateAvailable {
                await MainActor.run {
                    showUpdateAlert()
                }
            } else {
                await MainActor.run {
                    showNoUpdatesAlert()
                }
            }
        }
    }
    
    private func showUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Aggiornamento Disponibile", comment: "")
        alert.informativeText = updateService.releaseNotes ?? ""
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Scarica", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Non ora", comment: ""))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let urlString = updateService.downloadURL,
               let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func showNoUpdatesAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Nessun Aggiornamento", comment: "")
        alert.informativeText = NSLocalizedString("Stai utilizzando l'ultima versione di ReportBuddy", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }
    
    @objc func refreshEvents() {
        NotificationCenter.default.post(name: Notification.Name("RefreshEvents"), object: nil)
    }
    
    @objc func exportViaEmail() {
        NotificationCenter.default.post(name: Notification.Name("ExportEmail"), object: nil)
    }
    
    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("ReportBuddy Help", comment: "")
        alert.informativeText = NSLocalizedString("La documentazione è disponibile su GitHub", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Apri nel Browser", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Annulla", comment: ""))
        
        if alert.runModal() == .alertFirstButtonReturn {
            let helpURL = URL(string: "https://github.com/philsaino/ReportBuddy/wiki")!
            NSWorkspace.shared.open(helpURL)
        }
    }
}

// Modifica l'estensione per le costanti delle notifiche
extension Notification.Name {
    static let refreshEvents = Notification.Name("RefreshEvents")
    static let exportEmail = Notification.Name("ExportEmail")
} 