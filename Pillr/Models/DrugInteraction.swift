import Foundation

struct DrugInteraction: Identifiable, Codable, Hashable {
    var id = UUID()
    var drugA: String
    var drugB: String
    var severity: InteractionSeverity
    var description: String
    var recommendedAction: String
    var timestamp: Date = Date()
    
    enum InteractionSeverity: String, Codable, CaseIterable {
        case minor = "Minor"
        case moderate = "Moderate"
        case major = "Major"
        case contraindicated = "Contraindicated"
        case unknown = "Unknown"
        
        var color: String {
            switch self {
            case .minor: return "#F5F5F5" // Light brown/tan
            case .moderate: return "#FFC107" // Yellow/Amber
            case .major: return "#FF9800" // Orange
            case .contraindicated: return "#F44336" // Red
            case .unknown: return "#9E9E9E" // Gray
            }
        }
    }
}

struct DrugInteractionResponse: Codable {
    var interactions: [DrugInteraction]
    var queryTimestamp: Date
    var source: String
} 