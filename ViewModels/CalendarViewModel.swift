import EventKit
import SwiftUI
import os.log

enum CalendarViewState: Equatable {
    case initial
    case loading
    case authorized
    case unauthorized
    case error(String)
    
    static func == (lhs: CalendarViewState, rhs: CalendarViewState) -> Bool {
        switch (lhs, rhs) {
        case (.initial, .initial),
             (.loading, .loading),
             (.authorized, .authorized),
             (.unauthorized, .unauthorized):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
    
    var message: String? {
        switch self {
        case .error(let message): return message
        case .unauthorized: return """
            Accesso al calendario negato.
            
            Per concedere l'accesso:
            1. Apri Preferenze di Sistema
            2. Vai su Privacy e Sicurezza > Calendario
            3. Attiva "Accesso completo al calendario" per ReportBuddy
            4. Riavvia l'applicazione
            """
        default: return nil
        }
    }
}

// Struttura per la cache degli eventi
private struct EventCache {
    let events: [EKEvent]
    let timestamp: Date
    let month: Int
    let year: Int
    
    var isValid: Bool {
        let calendar = Calendar.current
        let now = Date()
        return calendar.component(.month, from: timestamp) == calendar.component(.month, from: now) &&
               calendar.component(.year, from: timestamp) == calendar.component(.year, from: now)
    }
}

// Aggiungi una cache per le parole chiave processate
private struct KeywordCache {
    let keywords: Set<String>
    let timestamp: Date
    
    var isValid: Bool {
        Date().timeIntervalSince(timestamp) < 300 // 5 minuti
    }
}

enum CalendarError: LocalizedError {
    case noCalendars
    case accessDenied
    case networkError(Error)
    case invalidDate
    
    var errorDescription: String? {
        switch self {
        case .noCalendars:
            return "Nessun calendario trovato"
        case .accessDenied:
            return "Accesso al calendario negato"
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .invalidDate:
            return "Data non valida"
        }
    }
}

class CalendarViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ReportBuddy", category: "CalendarViewModel")
    private let eventStore = EKEventStore()
    private var currentTask: Task<Void, Never>?
    private var eventCache: EventCache?
    private var keywordCache: KeywordCache?
    private let calendar = Calendar.current
    
    @Published var calendars: [EKCalendar] = []
    @Published var events: [EKEvent] = []
    @Published var state: CalendarViewState = .initial
    @Published var settings: CalendarSettings
    @Published var editingKeyword: String?
    @Published var editedKeywordText: String = ""
    
    init() {
        // Inizializza settings prima di tutto
        self.settings = SettingsManager.shared.loadSettings()
        
        // Dopo l'inizializzazione completa, richiedi l'accesso
        Task {
            await checkAndRequestAccess()
        }
    }
    
    // Aggiungi un metodo separato per osservare i cambiamenti delle impostazioni
    func updateSettings(_ newSettings: CalendarSettings) {
        settings = newSettings
        refreshEvents()
    }
    
    func saveSettings() {
        SettingsManager.shared.saveSettings(settings)
        keywordCache = nil  // Invalida la cache delle keywords
        eventCache = nil    // Invalida la cache degli eventi
        refreshEvents()     // Forza l'aggiornamento degli eventi
    }
    
    func addKeyword(_ keyword: String) {
        settings.eventKeywords.append(keyword)
        keywordCache = nil  // Invalida la cache delle keywords
        saveSettings()
        refreshEvents()     // Forza l'aggiornamento degli eventi
    }
    
    func removeKeyword(_ keyword: String) {
        settings.eventKeywords.removeAll { $0 == keyword }
        keywordCache = nil  // Invalida la cache delle keywords
        saveSettings()
        refreshEvents()     // Forza l'aggiornamento degli eventi
    }
    
    func refreshEvents() {
        currentTask?.cancel()
        currentTask = Task {
            await loadEvents()
        }
    }
    
    // MARK: - Access Management
    @MainActor
    private func checkAndRequestAccess() async {
        logger.debug("Verifica accesso calendario - Inizio")
        
        let status: EKAuthorizationStatus
        if #available(macOS 14.0, *) {
            status = EKEventStore.authorizationStatus(for: .event)
            logger.debug("Status macOS 14+: \(String(describing: status))")
            
            switch status {
            case .fullAccess:
                logger.info("Accesso completo già autorizzato")
                await loadCalendars()
            case .notDetermined:
                logger.info("Accesso non ancora determinato, richiedo autorizzazione")
                await requestAccess()
            case .restricted, .denied:
                logger.warning("Accesso negato o ristretto")
                state = .unauthorized
            case .writeOnly:
                logger.warning("Solo accesso in scrittura, richiedo accesso completo")
                await requestAccess()
            @unknown default:
                logger.warning("Stato di autorizzazione sconosciuto: \(String(describing: status))")
                await requestAccess()
            }
        } else {
            status = EKEventStore.authorizationStatus(for: .event)
            logger.debug("Status macOS <14: \(String(describing: status))")
            
            switch status {
            case .authorized:
                logger.info("Accesso già autorizzato")
                await loadCalendars()
            case .notDetermined:
                logger.info("Accesso non ancora determinato, richiedo autorizzazione")
                await requestAccess()
            case .restricted, .denied:
                logger.warning("Accesso negato o ristretto")
                state = .unauthorized
            case .fullAccess:
                logger.info("Accesso completo già autorizzato")
                await loadCalendars()
            case .writeOnly:
                logger.warning("Solo accesso in scrittura, richiedo accesso completo")
                await requestAccess()
            @unknown default:
                logger.warning("Stato di autorizzazione sconosciuto")
                await requestAccess()
            }
        }
    }
    
    @MainActor
    private func requestAccess() async {
        state = .loading
        logger.debug("Richiesta accesso al calendario - Inizio")
        
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                logger.debug("Richiedo accesso completo (iOS 14+)")
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                logger.debug("Richiedo accesso base")
                granted = try await eventStore.requestAccess(to: .event)
            }
            
            if granted {
                logger.info("✅ Accesso al calendario concesso")
                await loadCalendars()
            } else {
                logger.warning("❌ Accesso al calendario negato dall'utente")
                state = .unauthorized
            }
        } catch {
            logger.error("❌ Errore durante la richiesta di accesso: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("""
                    Dettagli errore:
                    - Domain: \(nsError.domain)
                    - Code: \(nsError.code)
                    - Description: \(nsError.localizedDescription)
                    - Failure Reason: \(nsError.localizedFailureReason ?? "N/A")
                    - Recovery Suggestion: \(nsError.localizedRecoverySuggestion ?? "N/A")
                    """)
            }
            
            state = .error("""
                Errore durante la richiesta di accesso al calendario.
                
                Dettagli: \(error.localizedDescription)
                
                Suggerimenti:
                1. Verifica le autorizzazioni nelle Preferenze di Sistema
                2. Riavvia l'applicazione
                3. Se il problema persiste, prova a riavviare il sistema
                """)
        }
    }
    
    // MARK: - Calendar Loading
    @MainActor
    private func loadCalendars() async {
        state = .loading
        
        let start = DispatchTime.now()
        
        let allCalendars = eventStore.calendars(for: .event)
        let filteredCalendars = allCalendars.filter(isValidCalendar)
        calendars = filteredCalendars.sorted(by: calendarSorting)
        
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        logger.debug("Caricamento calendari completato in \(Double(nanoTime) / 1_000_000_000, privacy: .public) secondi")
        
        if calendars.isEmpty {
            state = .error("Nessun calendario trovato")
        } else {
            state = .authorized
            await updateEventCache()
        }
    }
    
    // MARK: - Event Management
    @MainActor
    private func updateEventCache() async {
        // Prima verifica se abbiamo l'autorizzazione
        let status: EKAuthorizationStatus
        if #available(macOS 14.0, *) {
            status = EKEventStore.authorizationStatus(for: .event)
            guard status == .fullAccess else {
                logger.warning("Accesso non autorizzato, richiedo autorizzazione")
                await requestAccess()
                return
            }
        } else {
            status = EKEventStore.authorizationStatus(for: .event)
            guard status == .authorized else {
                logger.warning("Accesso non autorizzato, richiedo autorizzazione")
                await requestAccess()
                return
            }
        }
        
        // Determina l'intervallo di date da usare
        let startDate: Date
        let endDate: Date
        
        if settings.dateRange.useCustomRange {
            // Usa l'intervallo personalizzato
            startDate = settings.dateRange.startDate
            endDate = settings.dateRange.endDate
        } else {
            // Usa il mese corrente (comportamento predefinito)
            let now = Date()
            startDate = calendar.monthStartDate(for: now)
            endDate = calendar.monthEndDate(for: now)
        }
        
        let selectedCalendars = calendars.filter { self.settings.selectedCalendarIds.contains($0.calendarIdentifier) }
        
        guard !selectedCalendars.isEmpty else {
            logger.debug("Nessun calendario selezionato - Pulisco gli eventi")
            events = []
            return
        }
        
        // Usa l'intervallo di date calcolato per il predicate
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
        
        let allEvents = eventStore.events(matching: predicate)
        
        // Debug log per vedere gli eventi all-day
        logger.debug("Eventi totali prima del filtro: \(allEvents.count)")
        logger.debug("Eventi all-day prima del filtro: \(allEvents.filter { $0.isAllDay }.count)")
        logger.debug("Eventi non all-day prima del filtro: \(allEvents.filter { !$0.isAllDay }.count)")
        
        // Rimuovi duplicati
        let uniqueEvents = Dictionary(grouping: allEvents) { event in
            "\(event.eventIdentifier ?? UUID().uuidString)_\(event.startDate.timeIntervalSince1970)"
        }.values.compactMap { $0.first }
        
        // Applica i filtri
        let filteredEvents = uniqueEvents
            .filter { event in
                // Se onlyAllDayEvents è false, mostra tutti gli eventi
                // Se onlyAllDayEvents è true, mostra solo gli eventi all-day
                let passesAllDayFilter = !self.settings.onlyAllDayEvents || event.isAllDay
                
                // Applica il filtro keywords solo se passa il filtro all-day
                return passesAllDayFilter && matchesKeywords(event)
            }
            .sorted { $0.startDate < $1.startDate }
        
        logger.debug("""
            Statistiche filtro:
            - Intervallo date: \(self.dateFormatter.string(from: startDate)) - \(self.dateFormatter.string(from: endDate))
            - Intervallo personalizzato: \(self.settings.dateRange.useCustomRange)
            - Eventi totali: \(allEvents.count)
            - Eventi unici: \(uniqueEvents.count)
            - Eventi finali: \(filteredEvents.count)
            - All-day only attivo: \(self.settings.onlyAllDayEvents)
            - Eventi all-day nel risultato: \(filteredEvents.filter { $0.isAllDay }.count)
            - Eventi non all-day nel risultato: \(filteredEvents.filter { !$0.isAllDay }.count)
            """)
        
        eventCache = EventCache(
            events: filteredEvents,
            timestamp: Date(),
            month: calendar.component(.month, from: Date()),
            year: calendar.component(.year, from: Date())
        )
        events = filteredEvents
        state = .authorized
    }
    
    // MARK: - Helper Methods
    private func isValidCalendar(_ calendar: EKCalendar) -> Bool {
        !calendar.isSubscribed &&
        calendar.type != .birthday &&
        calendar.type != .subscription
    }
    
    private func calendarSorting(_ cal1: EKCalendar, _ cal2: EKCalendar) -> Bool {
        if cal1.source.title != cal2.source.title {
            return cal1.source.title < cal2.source.title
        }
        return cal1.title.localizedStandardCompare(cal2.title) == .orderedAscending
    }
    
    private func getProcessedKeywords() -> Set<String> {
        if let cache = keywordCache, cache.isValid {
            return cache.keywords
        }
        let processed = Set(settings.eventKeywords.map { $0.lowercased() })
        keywordCache = KeywordCache(keywords: processed, timestamp: Date())
        return processed
    }
    
    private func matchesKeywords(_ event: EKEvent) -> Bool {
        guard let title = event.title?.lowercased() else {
            logger.debug("Evento senza titolo ignorato")
            return false
        }
        let keywords = getProcessedKeywords()
        
        if keywords.isEmpty {
            logger.debug("Nessuna keyword configurata")
            return false
        }
        
        let matches = keywords.contains { keyword in
            let contains = title.contains(keyword.lowercased())
            logger.debug("""
                Controllo keyword per evento '\(title)':
                - Keyword: '\(keyword)'
                - Match: \(contains)
                """)
            return contains
        }
        
        return matches
    }
    
    // MARK: - Public Interface
    func exportEvents() {
        Task { @MainActor in
            if let cache = eventCache, cache.isValid {
                logger.debug("Usando eventi dalla cache")
                events = cache.events
            } else {
                await updateEventCache()
            }
        }
    }
    
    // MARK: - State Helpers
    var isLoading: Bool {
        state == .loading
    }
    
    var errorMessage: String? {
        state.message
    }
    
    var isAuthorized: Bool {
        state == .authorized
    }
    
    func setError(_ message: String) {
        state = .error(message)
    }
    
    func resetError() {
        if case .error = state {
            state = .initial
            Task { @MainActor in
                await checkAndRequestAccess()
            }
        }
    }
    
    func clearError() {
        if case .error = state {
            state = .authorized
        }
    }
    
    deinit {
        currentTask?.cancel()
    }
    
    private func measurePerformance<T>(_ operation: String, block: () async throws -> T) async throws -> T {
        let start = DispatchTime.now()
        let result = try await block()
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        logger.debug("\(operation) completato in \(Double(nanoTime) / 1_000_000_000, privacy: .public) secondi")
        return result
    }
    
    @MainActor
    private func loadEvents() async {
        state = .loading
        await updateEventCache()
    }
    
    // Aggiungi un DateFormatter per il logging
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    func updateKeyword(oldKeyword: String, newKeyword: String) {
        guard !newKeyword.isEmpty else { return }
        if let index = settings.eventKeywords.firstIndex(of: oldKeyword) {
            settings.eventKeywords[index] = newKeyword
            saveSettings()
        }
    }
} 
