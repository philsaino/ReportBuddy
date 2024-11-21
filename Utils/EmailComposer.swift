import AppKit
import EventKit

class EmailComposer {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()
    
    static func composeEmail(events: [EKEvent], settings: CalendarSettings) {
        guard let selectedTemplate = settings.emailTemplates.first(where: { $0.id == settings.selectedTemplateId }) ?? settings.emailTemplates.first else {
            print("Nessun template email disponibile")
            return
        }
        
        let emailLanguage = selectedTemplate.language ?? settings.emailLanguage
        dateFormatter.locale = Locale(identifier: emailLanguage)
        
        let filteredEvents = settings.onlyAllDayEvents ? events.filter { $0.isAllDay } : events
        
        guard let service = NSSharingService(named: .composeEmail) else {
            print("Impossibile inizializzare il servizio email")
            return
        }
        
        let bundle = Bundle.main
        
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: emailLanguage)
        monthFormatter.dateFormat = "MMMM"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        
        let currentDate = Date()
        let formattedSubject = selectedTemplate.subject
            .replacingOccurrences(of: "$month", with: monthFormatter.string(from: currentDate))
            .replacingOccurrences(of: "$year", with: yearFormatter.string(from: currentDate))
        
        let text = """
        \(selectedTemplate.headerMessage)
        
        \(filteredEvents.map { event in
            "• \(dateFormatter.string(from: event.startDate)): \(event.title ?? bundle.localizedString(forKey: "Senza titolo", value: nil, table: nil))"
        }.joined(separator: "\n"))
        
        \(bundle.localizedString(forKey: "Totale eventi: ", value: nil, table: nil))\(filteredEvents.count)
        
        \(selectedTemplate.footerMessage)
        """
        
        if service.canPerform(withItems: [text]) {
            service.recipients = selectedTemplate.recipient.isEmpty ? nil : [selectedTemplate.recipient]
            service.subject = formattedSubject
            service.perform(withItems: [text])
        }
    }
} 
