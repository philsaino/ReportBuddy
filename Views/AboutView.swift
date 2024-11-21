import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Logo e Nome App
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 128, height: 128)
            
            Text("ReportBuddy")
                .font(.title)
                .fontWeight(.bold)
            
            // Versione
            Text("Versione \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Separatore
            Divider()
                .padding(.horizontal)
            
            // Informazioni Sviluppatore
            VStack(spacing: 8) {
                Text("Sviluppato da")
                    .font(.headline)
                
                Text("Filippo Saino")
                    .font(.body)
                
                // Links
                Link("GitHub", destination: URL(string: "https://github.com/philsaino")!)
                    .padding(.top, 4)
                
                Text("Italy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 1)
            }
            .padding()
            
            // Copyright
            Text("© 2024 Filippo Saino. Tutti i diritti riservati.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 500)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
} 