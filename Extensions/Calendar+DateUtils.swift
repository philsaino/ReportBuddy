import Foundation

extension Calendar {
    func monthStartDate(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func monthEndDate(for date: Date) -> Date {
        var components = DateComponents()
        components.month = 1
        components.day = -1
        return self.date(byAdding: components, to: monthStartDate(for: date)) ?? date
    }
} 