import AppKit
import EventKit

class EmailComposer {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()
    
    static func composeEmail(events: [EKEvent], language: String, subject: String, recipient: String, onlyAllDayEvents: Bool) {
        dateFormatter.locale = Locale(identifier: language)
        
        // Filtra gli eventi in base all'impostazione
        let filteredEvents = onlyAllDayEvents ? events.filter { $0.isAllDay } : events
        
        // Debug: Stampa il numero di eventi filtrati
        print("Numero di eventi filtrati: \(filteredEvents.count)")
        
        guard let service = NSSharingService(named: .composeEmail) else {
            print("Impossibile inizializzare il servizio email")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: language)
        dateFormatter.dateFormat = "d MMMM yyyy"
        
        // Formattatore per il mese e l'anno nell'oggetto
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: language)
        monthFormatter.dateFormat = "MMMM"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        
        // Sostituisci le variabili nell'oggetto
        let currentDate = Date()
        let formattedSubject = subject
            .replacingOccurrences(of: "$month", with: monthFormatter.string(from: currentDate))
            .replacingOccurrences(of: "$year", with: yearFormatter.string(from: currentDate))
        
        let bundle = Bundle.main
        
        let text = """
        \(bundle.localizedString(forKey: "Report Eventi\n\n", value: nil, table: nil))
        \(filteredEvents.map { event in
            "• \(dateFormatter.string(from: event.startDate)): \(event.title ?? bundle.localizedString(forKey: "Senza titolo", value: nil, table: nil))"
        }.joined(separator: "\n"))
        
        \(bundle.localizedString(forKey: "Totale eventi: ", value: nil, table: nil))\(filteredEvents.count)
        """
        
        if service.canPerform(withItems: [text]) {
            service.recipients = recipient.isEmpty ? nil : [recipient]
            service.subject = formattedSubject
            service.perform(withItems: [text])
        }
    }
} 
