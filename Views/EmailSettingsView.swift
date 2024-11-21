import SwiftUI

struct EmailSettingsView: View {
    @Binding var settings: CalendarSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showingNewTemplateSheet = false
    @State private var localSettings: CalendarSettings
    @State private var showingDeleteAlert = false
    @State private var showingRenameAlert = false
    @State private var newTemplateName = ""
    
    init(settings: Binding<CalendarSettings>) {
        self._settings = settings
        self._localSettings = State(initialValue: settings.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con titolo e pulsanti
            VStack(spacing: 16) {
                Text(LocalizedStringKey("Template Email"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 24)  // Più spazio sopra il titolo
                
                // Template Selection
                HStack(spacing: 20) {
                    // Template Picker
                    HStack {
                        Picker("", selection: $localSettings.selectedTemplateId) {
                            ForEach(localSettings.emailTemplates) { template in
                                Text(template.name).tag(Optional(template.id))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 300)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Template Actions
                    if let selectedTemplate = localSettings.emailTemplates.first(where: { $0.id == localSettings.selectedTemplateId }) {
                        HStack(spacing: 20) {
                            Button(action: {
                                newTemplateName = selectedTemplate.name
                                showingRenameAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text(LocalizedStringKey("Rinomina"))
                                }
                                .frame(width: 100)
                            }
                            .buttonStyle(.borderless)
                            .help(LocalizedStringKey("Rinomina Template"))
                            
                            Button(action: {
                                showingDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(LocalizedStringKey("Elimina"))
                                }
                                .frame(width: 100)
                                .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                            .help(LocalizedStringKey("Elimina Template"))
                            .disabled(selectedTemplate.id == "default")
                            
                            Button(action: {
                                showingNewTemplateSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text(LocalizedStringKey("Nuovo"))
                                }
                                .frame(width: 100)
                            }
                            .buttonStyle(.borderless)
                            .help(LocalizedStringKey("Crea Nuovo Template"))
                        }
                    }
                }
                .padding(.horizontal, 24)  // Più spazio ai lati
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.horizontal, 24)  // Padding consistente
            
            Divider()
                .padding(.vertical, 8)  // Spazio attorno al divider
            
            // Content Area
            ScrollView {
                if let selectedTemplate = localSettings.emailTemplates.first(where: { $0.id == localSettings.selectedTemplateId }) {
                    VStack(alignment: .leading, spacing: 24) {  // Aumentato lo spacing
                        // Recipient
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Destinatario Email"))
                                .font(.headline)
                            TextField(LocalizedStringKey("Inserisci indirizzo email"), text: Binding(
                                get: { selectedTemplate.recipient },
                                set: { newValue in
                                    if let index = localSettings.emailTemplates.firstIndex(where: { $0.id == selectedTemplate.id }) {
                                        localSettings.emailTemplates[index].recipient = newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        // Subject
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Oggetto Email"))
                                .font(.headline)
                            TextField(LocalizedStringKey("Inserisci oggetto"), text: Binding(
                                get: { selectedTemplate.subject },
                                set: { newValue in
                                    if let index = localSettings.emailTemplates.firstIndex(where: { $0.id == selectedTemplate.id }) {
                                        localSettings.emailTemplates[index].subject = newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            
                            Text(LocalizedStringKey("Variabili disponibili:"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("$month - Mese corrente"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("$year - Anno corrente"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Language Selection
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Lingua Email"))
                                .font(.headline)
                            Picker("", selection: Binding(
                                get: { selectedTemplate.language ?? settings.emailLanguage },
                                set: { newValue in
                                    if let index = localSettings.emailTemplates.firstIndex(where: { $0.id == selectedTemplate.id }) {
                                        localSettings.emailTemplates[index].language = newValue
                                    }
                                }
                            )) {
                                Text("Italiano").tag("it")
                                Text("English").tag("en")
                            }
                            .labelsHidden()
                            .frame(width: 200)
                        }
                        
                        // Header Message
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Messaggio Iniziale"))
                                .font(.headline)
                            TextEditor(text: Binding(
                                get: { selectedTemplate.headerMessage },
                                set: { newValue in
                                    if let index = localSettings.emailTemplates.firstIndex(where: { $0.id == selectedTemplate.id }) {
                                        localSettings.emailTemplates[index].headerMessage = newValue
                                    }
                                }
                            ))
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                            .background(Color(NSColor.textBackgroundColor))
                        }
                        
                        // Footer Message
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Messaggio Finale"))
                                .font(.headline)
                            TextEditor(text: Binding(
                                get: { selectedTemplate.footerMessage },
                                set: { newValue in
                                    if let index = localSettings.emailTemplates.firstIndex(where: { $0.id == selectedTemplate.id }) {
                                        localSettings.emailTemplates[index].footerMessage = newValue
                                    }
                                }
                            ))
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                            .background(Color(NSColor.textBackgroundColor))
                        }
                    }
                    .padding(24)  // Padding consistente
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 24)
                }
            }
            
            Divider()
                .padding(.vertical, 8)  // Spazio attorno al divider
            
            // Footer con pulsanti
            HStack {
                Button(LocalizedStringKey("Annulla")) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button(LocalizedStringKey("Fine")) {
                    settings = localSettings
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(24)  // Padding consistente
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 800, height: 800)
        .fixedSize()
        .alert(LocalizedStringKey("Rinomina Template"), isPresented: $showingRenameAlert) {
            TextField(LocalizedStringKey("Nome Template"), text: $newTemplateName)
            Button(LocalizedStringKey("Annulla"), role: .cancel) { }
            Button(LocalizedStringKey("Rinomina")) {
                if let index = localSettings.emailTemplates.firstIndex(where: { $0.id == localSettings.selectedTemplateId }) {
                    localSettings.emailTemplates[index].name = newTemplateName
                }
            }
        } message: {
            Text(LocalizedStringKey("Inserisci il nuovo nome per il template"))
        }
        .alert(LocalizedStringKey("Elimina Template"), isPresented: $showingDeleteAlert) {
            Button(LocalizedStringKey("Annulla"), role: .cancel) { }
            Button(LocalizedStringKey("Elimina"), role: .destructive) {
                if let selectedId = localSettings.selectedTemplateId,
                   let index = localSettings.emailTemplates.firstIndex(where: { $0.id == selectedId }) {
                    localSettings.emailTemplates.remove(at: index)
                    localSettings.selectedTemplateId = localSettings.emailTemplates.first?.id
                }
            }
        } message: {
            Text(LocalizedStringKey("Sei sicuro di voler eliminare questo template?"))
        }
        .sheet(isPresented: $showingNewTemplateSheet) {
            NewTemplateView(settings: $localSettings)
        }
    }
}

struct NewTemplateView: View {
    @Binding var settings: CalendarSettings
    @Environment(\.dismiss) private var dismiss
    @State private var templateName = ""
    @State private var subject = ""
    @State private var recipient = ""
    @State private var headerMessage = ""
    @State private var footerMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(LocalizedStringKey("Nome Template"), text: $templateName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField(LocalizedStringKey("Destinatario Email"), text: $recipient)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                    
                    TextField(LocalizedStringKey("Oggetto Email"), text: $subject)
                        .textFieldStyle(.roundedBorder)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("Messaggio Iniziale"))
                            .font(.headline)
                        TextEditor(text: $headerMessage)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2))
                            )
                        
                        Text(LocalizedStringKey("Messaggio Finale"))
                            .font(.headline)
                        TextEditor(text: $footerMessage)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2))
                            )
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(LocalizedStringKey("Nuovo Template"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Annulla")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Salva")) {
                        let newTemplate = EmailTemplate(
                            id: UUID().uuidString,
                            name: templateName,
                            subject: subject,
                            recipient: recipient,
                            headerMessage: headerMessage,
                            footerMessage: footerMessage
                        )
                        settings.emailTemplates.append(newTemplate)
                        dismiss()
                    }
                    .disabled(templateName.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 700)
        .fixedSize()
    }
} 