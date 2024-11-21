import Foundation

struct CalendarSettings: Codable {
    var selectedCalendarIds: Set<String>
    var eventKeywords: [String]
    var emailLanguage: String
    var onlyAllDayEvents: Bool
    var emailTemplates: [EmailTemplate]
    var selectedTemplateId: String?
    var dateRange: DateRangeSettings
    
    static let defaultSettings = CalendarSettings(
        selectedCalendarIds: [],
        eventKeywords: [],
        emailLanguage: Locale.current.language.languageCode?.identifier ?? "en",
        onlyAllDayEvents: true,
        emailTemplates: [
            EmailTemplate(
                id: "default",
                name: "Template Standard",
                subject: "Report presenze buoni pasto - $month $year",
                recipient: "",
                headerMessage: "Gentile,\n\ndi seguito il report degli eventi del calendario:",
                footerMessage: "\nCordiali saluti",
                language: nil
            )
        ],
        selectedTemplateId: "default",
        dateRange: DateRangeSettings()
    )
}

struct EmailTemplate: Codable, Identifiable {
    let id: String
    var name: String
    var subject: String
    var recipient: String
    var headerMessage: String
    var footerMessage: String
    var language: String?
}

struct DateRangeSettings: Codable {
    var useCustomRange: Bool
    var startDate: Date
    var endDate: Date
    
    init() {
        self.useCustomRange = false
        // Default: mese corrente
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        
        // Inizio mese
        self.startDate = calendar.date(from: components) ?? now
        
        // Fine mese
        var endComponents = DateComponents()
        endComponents.month = 1
        endComponents.day = -1
        self.endDate = calendar.date(byAdding: endComponents, to: self.startDate) ?? now
    }
}

class SettingsManager {
    static let shared = SettingsManager()
    private let settingsKey = "com.yourcompany.ReportBuddy.settings"
    
    func saveSettings(_ settings: CalendarSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    func loadSettings() -> CalendarSettings {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(CalendarSettings.self, from: data) {
            return settings
        }
        return CalendarSettings.defaultSettings
    }
} 