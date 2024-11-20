import SwiftUI

struct EmailSettingsView: View {
    @Binding var settings: CalendarSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(LocalizedStringKey("Impostazioni Email")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey("Destinatario Email"))
                        .font(.headline)
                    TextField(LocalizedStringKey("Inserisci indirizzo email"), text: $settings.emailRecipient)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    Text(LocalizedStringKey("Oggetto Email"))
                        .font(.headline)
                    TextField(LocalizedStringKey("Inserisci oggetto"), text: $settings.emailSubject)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    Text(LocalizedStringKey("Variabili disponibili:"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(LocalizedStringKey("$month - Mese corrente"))
                        .font(.caption)
                    Text(LocalizedStringKey("$year - Anno corrente"))
                        .font(.caption)
                }
            }
            
            Section {
                HStack {
                    Spacer()
                    Button(LocalizedStringKey("Salva")) {
                        dismiss()
                    }
                    .keyboardShortcut(.return)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
} 