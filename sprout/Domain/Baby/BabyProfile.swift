import Foundation
import SwiftData

@Model
final class BabyProfile {
    var name: String
    var birthDate: Date
    var gender: Gender?
    var createdAt: Date
    var isActive: Bool

    enum Gender: String, Codable {
        case male
        case female
    }

    init(
        name: String = "宝宝",
        birthDate: Date = .now,
        gender: Gender? = nil,
        createdAt: Date = .now,
        isActive: Bool = true
    ) {
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.createdAt = createdAt
        self.isActive = isActive
    }
}
