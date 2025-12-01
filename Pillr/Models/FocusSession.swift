import Foundation

struct FocusSession: Identifiable, Codable {
    enum State: String, Codable {
        case upcoming
        case active
        case finished
    }
    
    let id: UUID
    let createdAt: Date
    let startDate: Date
    let durationMinutes: Int
    var manuallyEndedAt: Date?
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        startDate: Date,
        durationMinutes: Int,
        manuallyEndedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.manuallyEndedAt = manuallyEndedAt
    }
    
    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
    
    var totalDurationSeconds: Double {
        Double(durationMinutes * 60)
    }
    
    func state(relativeTo date: Date = Date()) -> State {
        if let manuallyEndedAt, date >= manuallyEndedAt {
            return .finished
        }
        
        if date < startDate {
            return .upcoming
        }
        
        if date >= endDate {
            return .finished
        }
        
        return .active
    }
    
    func isExpired(relativeTo date: Date = Date()) -> Bool {
        state(relativeTo: date) == .finished
    }
    
    func secondsUntilStart(relativeTo date: Date = Date()) -> Int {
        max(0, Int(startDate.timeIntervalSince(date)))
    }
    
    func secondsRemaining(relativeTo date: Date = Date()) -> Int {
        switch state(relativeTo: date) {
        case .upcoming:
            return Int(totalDurationSeconds)
        case .active:
            return max(0, Int(endDate.timeIntervalSince(date)))
        case .finished:
            return 0
        }
    }
}
