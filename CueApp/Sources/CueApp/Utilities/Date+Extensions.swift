import Foundation

extension Date {
    var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()

        // For same day (today)
        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: self)
        }
        // For yesterday
        else if calendar.isDateInYesterday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: self))"
        }
        // For within the same week (but not today or yesterday)
        else if let dayDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: self), to: calendar.startOfDay(for: now)).day,
                dayDifference >= 0 && dayDifference < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE 'at' h:mm a" // Show day name (Monday, Tuesday, etc.)
            return formatter.string(from: self)
        }
        // For same year but not same week
        else if calendar.isDate(self, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d 'at' h:mm a"
            return formatter.string(from: self)
        }
        // For different year
        else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
            return formatter.string(from: self)
        }
    }
}
