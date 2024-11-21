import SwiftUI
import WebKit

// Aggiungi questa estensione per il metodo with
extension NSMenuItem {
    func with(_ configure: (NSMenuItem) -> Void) -> NSMenuItem {
        configure(self)
        return self
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        
        // App Menu (ReportBuddy)
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Informazioni su ReportBuddy", comment: ""),
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        ))
        
        appMenu.addItem(.separator())
        
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Verifica Aggiornamenti", comment: ""),
            action: #selector(checkForUpdates),
            keyEquivalent: "u"
        ))
        
        appMenu.addItem(.separator())
        
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Preferenze", comment: ""),
            action: #selector(openPreferences),
            keyEquivalent: ","
        ))
        
        appMenu.addItem(.separator())
        
        let servicesMenu = NSMenu()
        let servicesMenuItem = NSMenuItem(title: NSLocalizedString("Servizi", comment: ""), action: nil, keyEquivalent: "")
        servicesMenuItem.submenu = servicesMenu
        appMenu.addItem(servicesMenuItem)
        NSApp.servicesMenu = servicesMenu
        
        appMenu.addItem(.separator())
        
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Nascondi ReportBuddy", comment: ""),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        ))
        
        let hideOthersItem = NSMenuItem(
            title: NSLocalizedString("Nascondi altre", comment: ""),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Mostra tutte", comment: ""),
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        ))
        
        appMenu.addItem(.separator())
        
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Esci", comment: ""),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        
        // File Menu
        let fileMenu = NSMenu(title: NSLocalizedString("File", comment: ""))
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        
        fileMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Aggiorna", comment: ""),
            action: #selector(refreshEvents),
            keyEquivalent: "r"
        ).with {
            $0.isEnabled = true
        })
        
        fileMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Esporta via Email", comment: ""),
            action: #selector(exportEmail),
            keyEquivalent: "e"
        ).with {
            $0.isEnabled = true
        })
        
        // Window Menu
        let windowMenu = NSMenu(title: NSLocalizedString("Finestra", comment: ""))
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        
        windowMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Minimizza", comment: ""),
            action: #selector(NSWindow.miniaturize(_:)),
            keyEquivalent: "m"
        ))
        
        windowMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Zoom", comment: ""),
            action: #selector(NSWindow.zoom(_:)),
            keyEquivalent: ""
        ))
        
        // Help Menu
        let helpMenu = NSMenu(title: NSLocalizedString("Aiuto", comment: ""))
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        
        helpMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Aiuto ReportBuddy", comment: ""),
            action: #selector(showHelp),
            keyEquivalent: "?"
        ))
        
        // Add all menus to the main menu
        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(windowMenuItem)
        mainMenu.addItem(helpMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
        
        // Controlla gli aggiornamenti
        Task {
            await UpdateService.shared.checkForUpdates()
            if UpdateService.shared.updateAvailable {
                await MainActor.run {
                    showUpdateAlert()
                }
            }
        }
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
            settingsWindow?.title = NSLocalizedString("Preferenze", comment: "")
            settingsWindow?.contentView = NSHostingView(rootView: contentView)
            settingsWindow?.center()
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func refreshEvents() {
        NotificationCenter.default.post(name: .refreshEvents, object: nil)
    }
    
    @objc func exportEmail() {
        NotificationCenter.default.post(name: .exportEmail, object: nil)
    }
    
    @objc func showHelp() {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let helpFileName = "Help.\(language)"
        
        if let helpURL = Bundle.main.url(forResource: helpFileName, withExtension: "html") {
            let helpWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            let webView = WKWebView(frame: .zero)
            webView.loadFileURL(helpURL, allowingReadAccessTo: helpURL.deletingLastPathComponent())
            
            helpWindow.contentView = webView
            helpWindow.title = NSLocalizedString("Aiuto ReportBuddy", comment: "")
            helpWindow.center()
            helpWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func showUpdateAlert() {
        let alert = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        let hostingView = NSHostingView(rootView: UpdateAlertView())
        alert.contentView = hostingView
        alert.center()
        
        NSApp.runModal(for: alert)
        alert.close()
    }
    
    @objc func checkForUpdates() {
        Task {
            await UpdateService.shared.checkForUpdates()
            if UpdateService.shared.updateAvailable {
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
    
    private func showNoUpdatesAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Nessun Aggiornamento", comment: "")
        alert.informativeText = NSLocalizedString("Stai utilizzando l'ultima versione di ReportBuddy", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }
}

// Modifica l'estensione per le costanti delle notifiche
extension Notification.Name {
    static let refreshEvents = Notification.Name("RefreshEvents")
    static let exportEmail = Notification.Name("ExportEmail")
} 