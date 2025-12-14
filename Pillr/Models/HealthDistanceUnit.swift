import Foundation

enum HealthDistanceUnit: String, CaseIterable, Identifiable {
    case miles = "mi"
    case kilometers = "km"
    
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    
    func convertDistance(fromMiles miles: Double) -> Double {
        switch self {
        case .miles:
            return miles
        case .kilometers:
            return miles * 1.60934
        }
    }
}
