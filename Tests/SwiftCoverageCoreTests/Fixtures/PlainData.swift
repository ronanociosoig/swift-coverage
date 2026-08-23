import Foundation

/// A plain data type: only stored properties and a synthesized-style
/// initializer, no branching logic anywhere. `LogicUnitCollectorTests`
/// asserts this file produces zero `LogicUnit`s.
struct PlainData {
    let id: UUID
    let name: String
    let createdAt: Date

    init(id: UUID, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

struct AnotherPlainData {
    var count: Int
    var label: String
}
