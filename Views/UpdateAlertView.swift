import SwiftUI

struct UpdateAlertView: View {
    @EnvironmentObject private var updateService: UpdateService
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
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
            }
            
            if let notes = updateService.releaseNotes {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note di rilascio")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ScrollView {
                        Text(notes)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.horizontal, 8)
                    }
                    .frame(height: 300)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                }
            }
            
            HStack(spacing: 20) {
                Button(LocalizedStringKey("Non ora")) {
                    if let window = NSApp.keyWindow {
                        NSApp.stopModal()
                        window.close()
                    }
                }
                .keyboardShortcut(.escape)
                
                Button(LocalizedStringKey("Scarica")) {
                    if let urlString = updateService.downloadURL,
                       let url = URL(string: urlString) {
                        if let window = NSApp.keyWindow {
                            NSApp.stopModal()
                            window.close()
                        }
                        openURL(url)
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 700)
    }
} 