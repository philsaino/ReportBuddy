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
    private let logger = Logger(subsystem: "com.yourcompany.ReportBuddy", category: "CalendarViewModel")
    
    // MARK: - Published Properties
    @Published private(set) var state: CalendarViewState = .initial
    @Published var calendars: [EKCalendar] = []
    @Published var settings: CalendarSettings
    @Published private(set) var currentEvents: [EKEvent] = []
    
    // MARK: - Private Properties
    private let eventStore = EKEventStore()
    private let calendar = Calendar.current
    private var eventCache: EventCache?
    private var keywordCache: KeywordCache?
    private var currentTask: Task<Void, Never>?
    private var saveSettingsTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init() {
        self.settings = SettingsManager.shared.loadSettings()
        logger.info("CalendarViewModel inizializzato")
        
        Task { @MainActor in
            await checkAndRequestAccess()
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
        
        // Se siamo qui, abbiamo l'autorizzazione
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            logger.error("Errore nella generazione delle date")
            state = .error(CalendarError.invalidDate.errorDescription ?? "Errore data")
            return
        }
        
        let selectedCalendars = calendars.filter { settings.selectedCalendarIds.contains($0.calendarIdentifier) }
        
        // Se non ci sono calendari selezionati o parole chiave, pulisci gli eventi
        if selectedCalendars.isEmpty || settings.eventKeywords.isEmpty {
            logger.debug("Nessun calendario selezionato o nessuna parola chiave - Pulisco gli eventi")
            currentEvents = []
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfMonth, end: endOfMonth, calendars: selectedCalendars)
        
        let allEvents = eventStore.events(matching: predicate)
        
        // Rimuovi duplicati usando un Dictionary con chiave composita
        let uniqueEvents = Dictionary(grouping: allEvents) { event in
            "\(event.eventIdentifier ?? UUID().uuidString)_\(event.startDate.timeIntervalSince1970)"
        }.compactMap { $0.value.first }
        
        let filteredEvents = uniqueEvents
            .filter { settings.onlyAllDayEvents ? $0.isAllDay : true }
            .filter(matchesKeywords)
            .sorted { $0.startDate < $1.startDate }
        
        logger.debug("Filtrati \(filteredEvents.count) eventi unici da \(allEvents.count) totali")
        
        eventCache = EventCache(
            events: filteredEvents,
            timestamp: now,
            month: calendar.component(.month, from: now),
            year: calendar.component(.year, from: now)
        )
        currentEvents = filteredEvents
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
        guard let title = event.title?.lowercased() else { return false }
        let keywords = getProcessedKeywords()
        
        // Se non ci sono keyword, non mostrare nessun evento
        if keywords.isEmpty {
            return false
        }
        
        // Controlla se almeno una keyword è contenuta nel titolo
        return keywords.contains { keyword in
            title.contains(keyword.lowercased())
        }
    }
    
    // MARK: - Public Interface
    func saveSettings() {
        SettingsManager.shared.saveSettings(settings)
        reloadEvents() // Forza il reload immediato
    }
    
    func addKeyword(_ keyword: String) {
        guard !keyword.isEmpty else { return }
        settings.eventKeywords.append(keyword)
        SettingsManager.shared.saveSettings(settings)
        reloadEvents() // Forza il reload immediato
    }
    
    func removeKeyword(_ keyword: String) {
        settings.eventKeywords.removeAll { $0 == keyword }
        // Invalida la cache delle keywords
        keywordCache = nil
        SettingsManager.shared.saveSettings(settings)
        // Forza un aggiornamento immediato
        Task { @MainActor in
            await updateEventCache()
            objectWillChange.send()
        }
    }
    
    func exportEvents() {
        Task { @MainActor in
            if let cache = eventCache, cache.isValid {
                logger.debug("Usando eventi dalla cache")
                currentEvents = cache.events
            } else {
                await updateEventCache()
            }
        }
    }
    
    func reloadEvents() {
        currentTask?.cancel()
        currentTask = Task { @MainActor in
            state = .loading // Mostra l'indicatore di caricamento
            
            // Invalida tutte le cache
            eventCache = nil
            keywordCache = nil
            
            // Ricarica i calendari e gli eventi
            await loadCalendars()
            await updateEventCache()
            
            state = .authorized
            objectWillChange.send()
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
} 
