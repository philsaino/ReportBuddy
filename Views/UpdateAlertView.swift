import SwiftUI

struct UpdateAlertView: View {
    @ObservedObject private var updateService = UpdateService.shared
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text(LocalizedStringKey("Aggiornamento Disponibile"))
                .font(.title2)
                .fontWeight(.semibold)
            
            if let version = updateService.latestVersion {
                Text(LocalizedStringKey("Versione \(version)"))
                    .foregroundColor(.secondary)
            }
            
            if let notes = updateService.releaseNotes {
                ScrollView {
                    Text(notes)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }
            
            HStack(spacing: 16) {
                Button(LocalizedStringKey("Non ora")) {
                    NSApp.stopModal()
                }
                .keyboardShortcut(.escape)
                
                Button(LocalizedStringKey("Scarica")) {
                    if let urlString = updateService.downloadURL,
                       let url = URL(string: urlString) {
                        openURL(url)
                    }
                    NSApp.stopModal()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
} 