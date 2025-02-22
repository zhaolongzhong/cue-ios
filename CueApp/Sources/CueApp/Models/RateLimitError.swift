import Foundation

enum RateLimitError: LocalizedError {
    case limitExceeded(remainingTime: TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .limitExceeded(let remainingTime):
            let hours = Int(remainingTime) / 3600
            let minutes = Int(remainingTime) / 60 % 60
            
            if hours > 0 {
                return "Rate limit exceeded. Please try again in \(hours) hours and \(minutes) minutes."
            } else {
                return "Rate limit exceeded. Please try again in \(minutes) minutes."
            }
        }
    }
}