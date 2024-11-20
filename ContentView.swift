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
    @State private var newKeyword = ""
    @State private var selectedCalendar: String? = nil
    @State private var showingEmailSettings = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar con le impostazioni
            List {
                Section(LocalizedStringKey("Calendari")) {
                    Picker("", selection: $selectedCalendar) {
                        Text(LocalizedStringKey("Seleziona...")).tag(nil as String?)
                        ForEach(Dictionary(grouping: viewModel.calendars) { $0.source.title }
                                .sorted(by: { $0.key < $1.key }), id: \.key) { sourceTitle, calendars in
                            Section(header: Text(sourceTitle)) {
                                ForEach(calendars, id: \.calendarIdentifier) { calendar in
                                    Label {
                                        Text(calendar.title)
                                    } icon: {
                                        Circle()
                                            .fill(Color(cgColor: calendar.cgColor))
                                            .frame(width: 10, height: 10)
                                    }
                                    .tag(calendar.calendarIdentifier as String?)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedCalendar) { oldValue, newValue in
                        if let calendarId = newValue {
                            viewModel.settings.selectedCalendarIds.insert(calendarId)
                            viewModel.saveSettings()
                            selectedCalendar = nil
                        }
                    }
                    
                    if !viewModel.settings.selectedCalendarIds.isEmpty {
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
                }
                
                Section(LocalizedStringKey("Parole Chiave")) {
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
                        .buttonStyle(.borderless)
                    }
                    
                    ForEach(viewModel.settings.eventKeywords, id: \.self) { keyword in
                        HStack {
                            Label(keyword, systemImage: "tag")
                            Spacer()
                            Button(action: {
                                viewModel.removeKeyword(keyword)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section(LocalizedStringKey("Lingua Email")) {
                    Picker("", selection: $viewModel.settings.emailLanguage) {
                        Text("Italiano").tag("it")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.settings.emailLanguage) { _, _ in
                        viewModel.saveSettings()
                    }
                    
                    Toggle(LocalizedStringKey("Solo eventi giornata intera"), isOn: $viewModel.settings.onlyAllDayEvents)
                        .onChange(of: viewModel.settings.onlyAllDayEvents) { _, _ in
                            viewModel.saveSettings()
                        }
                }
                
                Section("Impostazioni Email") {
                    Button(action: {
                        showingEmailSettings = true
                    }) {
                        Label(LocalizedStringKey("Configura Email"), systemImage: "envelope.circle")
                    }
                }
            }
            .listStyle(.sidebar)
        } detail: {
            // Area principale con la lista degli eventi
            VStack {
                Text(LocalizedStringKey("Eventi del mese corrente"))
                    .font(.headline)
                    .padding(.horizontal)
                
                if viewModel.currentEvents.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("Nessun evento trovato"),
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text(LocalizedStringKey("Seleziona un calendario e aggiungi delle parole chiave per vedere gli eventi"))
                    )
                } else {
                    List(viewModel.currentEvents, id: \.self) { event in
                        if let calendar = viewModel.calendars.first(where: { $0.calendarIdentifier == event.calendar.calendarIdentifier }) {
                            EventRow(event: event, calendar: calendar)
                                .id("\(String(describing: event.eventIdentifier))_\(event.startDate.timeIntervalSince1970)")
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    Spacer()
                    Button(action: {
                        EmailComposer.composeEmail(
                            events: viewModel.currentEvents,
                            language: viewModel.settings.emailLanguage,
                            subject: viewModel.settings.emailSubject,
                            recipient: viewModel.settings.emailRecipient,
                            onlyAllDayEvents: viewModel.settings.onlyAllDayEvents
                        )
                    }) {
                        Label(LocalizedStringKey("Esporta via Email"), systemImage: "envelope")
                    }
                    .keyboardShortcut("E", modifiers: .command)
                    .disabled(viewModel.currentEvents.isEmpty)
                }
                .padding()
            }
        }
        .navigationTitle(LocalizedStringKey("Report Eventi"))
        .sheet(isPresented: $showingEmailSettings) {
            EmailSettingsView(settings: $viewModel.settings)
                .onDisappear {
                    viewModel.saveSettings()
                }
        }
        .alert("Errore", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    viewModel.reloadEvents()
                }) {
                    Label(LocalizedStringKey("Aggiorna"), systemImage: "arrow.clockwise")
                }
                .help(LocalizedStringKey("Aggiorna la lista degli eventi"))
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    EmailComposer.composeEmail(
                        events: viewModel.currentEvents,
                        language: viewModel.settings.emailLanguage,
                        subject: viewModel.settings.emailSubject,
                        recipient: viewModel.settings.emailRecipient,
                        onlyAllDayEvents: viewModel.settings.onlyAllDayEvents
                    )
                }) {
                    Label(LocalizedStringKey("Esporta"), systemImage: "square.and.arrow.up")
                }
                .help(LocalizedStringKey("Esporta eventi via email"))
                .disabled(viewModel.currentEvents.isEmpty)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
}

struct EventRow: View {
    let event: EKEvent
    let calendar: EKCalendar
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 8, height: 8)
                
                Text(event.title ?? "Senza titolo")
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(calendar.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(calendar.source.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            }
            
            Text(event.startDate.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(event.title ?? "", forType: .string)
            }) {
                Label("Copia Titolo", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                NSWorkspace.shared.open(URL(string: "calshow://")!)
            }) {
                Label("Apri in Calendario", systemImage: "calendar")
            }
        }
    }
}

#Preview {
    ContentView()
}
