import Foundation

extension Date {
    /// Returns a human-readable relative time string (e.g., "2 minutes ago", "3 hours ago")
    func relativeTimeString() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: self,
            to: now
        )

        if let years = components.year, years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        }

        if let months = components.month, months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }

        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }

        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }

        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }

        if let seconds = components.second, seconds > 5 {
            return "\(seconds) seconds ago"
        }

        return "Just now"
    }
}
