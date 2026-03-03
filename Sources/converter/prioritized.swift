public let PriorityEarly: Int = 100
public let PriorityStandard: Int = 500
public let PriorityLate: Int = 1000

struct PrioritizedValue<V> {
    let value: V
    let priority: Int
}

extension Array {
    func sortedByPriority<V>() -> [PrioritizedValue<V>] where Element == PrioritizedValue<V> {
        return self.sorted { $0.priority < $1.priority }
    }
    mutating func appendPrioritized<V>(_ value: V, _ priority: Int) where Element == PrioritizedValue<V> {
        self.append(PrioritizedValue(value: value, priority: priority))
    }
}
