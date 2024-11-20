import Foundation

struct CalendarSettings: Codable {
    var selectedCalendarIds: Set<String>
    var eventKeywords: [String]
    var emailLanguage: String
    var emailSubject: String
    var emailRecipient: String
    var onlyAllDayEvents: Bool
    
    static let defaultSettings = CalendarSettings(
        selectedCalendarIds: [],
        eventKeywords: [],
        emailLanguage: Locale.current.language.languageCode?.identifier ?? "en",
        emailSubject: "Report presenze buoni pasto - $month $year",
        emailRecipient: "",
        onlyAllDayEvents: true
    )
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