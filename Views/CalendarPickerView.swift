import SwiftUI
import EventKit

struct CalendarPickerView: View {
    @Binding var selectedCalendarIds: Set<String>
    let calendars: [EKCalendar]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(calendars, id: \.calendarIdentifier) { calendar in
                    HStack {
                        Circle()
                            .fill(Color(cgColor: calendar.cgColor))
                            .frame(width: 10, height: 10)
                        
                        Text(calendar.title)
                        
                        Spacer()
                        
                        if selectedCalendarIds.contains(calendar.calendarIdentifier) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedCalendarIds.contains(calendar.calendarIdentifier) {
                            selectedCalendarIds.remove(calendar.calendarIdentifier)
                        } else {
                            selectedCalendarIds.insert(calendar.calendarIdentifier)
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Seleziona Calendari"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Fine")) {
                        dismiss()
                    }
                }
            }
        }
    }
} 