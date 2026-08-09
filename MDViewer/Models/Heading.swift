import Foundation

struct Heading: Identifiable, Hashable, Sendable {
    let id: String
    let level: Int
    let title: String
}

struct RenderReport: Sendable {
    var milliseconds: Double = 0
    var wordCount: Int = 0
    var mathCount: Int = 0
    var diagramCount: Int = 0
}
