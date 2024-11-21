//
//  ContentView.swift
//  TicketReport
//
//  Created by Phil on 19/11/24.
//

import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject private var updateService: UpdateService
    @State private var showingEmailSettings = false
    @State private var newKeyword = ""
    @FocusState private var keywordFocus: Bool
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List {
                Section(LocalizedStringKey("Calendari")) {
                    Menu {
                        calendarMenuContent()
                    } label: {
                        HStack {
                            Label(LocalizedStringKey("Seleziona..."), systemImage: "calendar")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.vertical, 4)
                    
                    // Lista dei calendari selezionati
                    ForEach(Array(viewModel.settings.selectedCalendarIds), id: \.self) { calendarId in
                        if let calendar = viewModel.calendars.first(where: { $0.calendarIdentifier == calendarId }) {
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                                Spacer()
                                Button(action: {
                                    viewModel.settings.selectedCalendarIds.remove(calendarId)
                                    viewModel.saveSettings()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Section(LocalizedStringKey("Template Email")) {
                    Menu {
                        ForEach(viewModel.settings.emailTemplates) { template in
                            Button(action: {
                                viewModel.settings.selectedTemplateId = template.id
                                viewModel.saveSettings()
                            }) {
                                HStack {
                                    if viewModel.settings.selectedTemplateId == template.id {
                                        Image(systemName: "checkmark")
                                    }
                                    Text(template.name)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if let selectedTemplate = viewModel.settings.emailTemplates.first(where: { $0.id == viewModel.settings.selectedTemplateId }) {
                                Label(selectedTemplate.name, systemImage: "envelope.badge.fill")
                            } else {
                                Label(LocalizedStringKey("Seleziona Template"), systemImage: "envelope.badge.fill")
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.vertical, 4)
                }
                
                Section(LocalizedStringKey("Intervallo Date")) {
                    Toggle(LocalizedStringKey("Usa intervallo personalizzato"), isOn: Binding(
                        get: { viewModel.settings.dateRange.useCustomRange },
                        set: { newValue in
                            var newSettings = viewModel.settings
                            newSettings.dateRange.useCustomRange = newValue
                            viewModel.updateSettings(newSettings)
                        }
                    ))
                    
                    if viewModel.settings.dateRange.useCustomRange {
                        DatePicker(
                            LocalizedStringKey("Data Inizio"),
                            selection: Binding(
                                get: { viewModel.settings.dateRange.startDate },
                                set: { newValue in
                                    var newSettings = viewModel.settings
                                    newSettings.dateRange.startDate = newValue
                                    viewModel.updateSettings(newSettings)
                                }
                            ),
                            displayedComponents: [.date]
                        )
                        
                        DatePicker(
                            LocalizedStringKey("Data Fine"),
                            selection: Binding(
                                get: { viewModel.settings.dateRange.endDate },
                                set: { newValue in
                                    var newSettings = viewModel.settings
                                    newSettings.dateRange.endDate = newValue
                                    viewModel.updateSettings(newSettings)
                                }
                            ),
                            displayedComponents: [.date]
                        )
                    }
                }
                
                Section(LocalizedStringKey("Parole Chiave")) {
                    ForEach(viewModel.settings.eventKeywords, id: \.self) { keyword in
                        HStack {
                            if viewModel.editingKeyword == keyword {
                                TextField("", text: $viewModel.editedKeywordText)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        if !viewModel.editedKeywordText.isEmpty {
                                            viewModel.updateKeyword(oldKeyword: keyword, newKeyword: viewModel.editedKeywordText)
                                        }
                                        viewModel.editingKeyword = nil
                                    }
                                    .onExitCommand {
                                        viewModel.editingKeyword = nil
                                    }
                                    .focused($keywordFocus)
                                    .task {
                                        keywordFocus = true
                                    }
                            } else {
                                Text(keyword)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        viewModel.editingKeyword = keyword
                                        viewModel.editedKeywordText = keyword
                                    }
                            }
                            Spacer()
                            Button(action: {
                                viewModel.removeKeyword(keyword)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    HStack {
                        TextField(LocalizedStringKey("Nuova parola chiave"), text: $newKeyword)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if !newKeyword.isEmpty {
                                    viewModel.addKeyword(newKeyword)
                                    newKeyword = ""
                                }
                            }
                        Button(LocalizedStringKey("Aggiungi")) {
                            if !newKeyword.isEmpty {
                                viewModel.addKeyword(newKeyword)
                                newKeyword = ""
                            }
                        }
                        .disabled(newKeyword.isEmpty)
                    }
                }
                
                Section {
                    Toggle(LocalizedStringKey("Solo eventi giornata intera"), isOn: Binding(
                        get: { viewModel.settings.onlyAllDayEvents },
                        set: { newValue in
                            var newSettings = viewModel.settings
                            newSettings.onlyAllDayEvents = newValue
                            viewModel.updateSettings(newSettings)
                        }
                    ))
                }
            }
            .navigationTitle("ReportBuddy")
        } detail: {
            // Main Content
            VStack {
                Form {
                    Section(getEventsTitle()) {
                        if viewModel.events.isEmpty {
                            Text(LocalizedStringKey("Nessun evento trovato"))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.events, id: \.eventIdentifier) { event in
                                if let calendar = viewModel.calendars.first(where: { $0.calendarIdentifier == event.calendar?.calendarIdentifier }) {
                                    EventRow(event: event, calendar: calendar)
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(LocalizedStringKey("Report Eventi"))
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Button(action: {
                            viewModel.refreshEvents()
                        }) {
                            Label(LocalizedStringKey("Aggiorna"), systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            showingEmailSettings = true
                        }) {
                            Label(LocalizedStringKey("Configura Email"), systemImage: "gear")
                        }
                    }
                }
                
                // Export Button
                HStack {
                    Spacer()
                    Button(action: {
                        EmailComposer.composeEmail(
                            events: viewModel.events,
                            settings: viewModel.settings
                        )
                    }) {
                        Label(LocalizedStringKey("Esporta via Email"), systemImage: "envelope")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.events.isEmpty)
                    .padding()
                }
            }
            .sheet(isPresented: $showingEmailSettings) {
                EmailSettingsView(settings: $viewModel.settings)
            }
        }
        .onAppear {
            setupNotificationObservers()
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .refreshEvents,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.refreshEvents()
        }
        
        NotificationCenter.default.addObserver(
            forName: .exportEmail,
            object: nil,
            queue: .main
        ) { _ in
            if !viewModel.events.isEmpty {
                EmailComposer.composeEmail(
                    events: viewModel.events,
                    settings: viewModel.settings
                )
            }
        }
    }
    
    private func calendarMenuContent() -> some View {
        let groupedCalendars = Dictionary(grouping: viewModel.calendars) { $0.source.title }
        
        return ForEach(groupedCalendars.keys.sorted(), id: \.self) { sourceTitle in
            if let calendars = groupedCalendars[sourceTitle] {
                Menu(sourceTitle) {
                    ForEach(calendars.sorted { $0.title < $1.title }, id: \.calendarIdentifier) { cal in
                        Button(action: {
                            if viewModel.settings.selectedCalendarIds.contains(cal.calendarIdentifier) {
                                viewModel.settings.selectedCalendarIds.remove(cal.calendarIdentifier)
                            } else {
                                viewModel.settings.selectedCalendarIds.insert(cal.calendarIdentifier)
                            }
                            viewModel.saveSettings()
                        }) {
                            HStack {
                                if viewModel.settings.selectedCalendarIds.contains(cal.calendarIdentifier) {
                                    Image(systemName: "checkmark")
                                }
                                Circle()
                                    .fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 12, height: 12)
                                Text(cal.title)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getEventsTitle() -> LocalizedStringKey {
        if viewModel.settings.dateRange.useCustomRange {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let startDate = dateFormatter.string(from: viewModel.settings.dateRange.startDate)
            let endDate = dateFormatter.string(from: viewModel.settings.dateRange.endDate)
            return LocalizedStringKey("Eventi dal \(startDate) al \(endDate)")
        } else {
            return LocalizedStringKey("Eventi del mese corrente")
        }
    }
}

struct EventRow: View {
    let event: EKEvent
    let calendar: EKCalendar
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Titolo dell'evento
            HStack {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 10, height: 10)
                Text(event.title ?? NSLocalizedString("Senza titolo", comment: ""))
                    .font(.headline)
            }
            
            // Data dell'evento
            Text(event.startDate, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Calendario e Account
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(calendar.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                    .frame(height: 8)
                
                Image(systemName: "person.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(calendar.source.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
