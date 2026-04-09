import Foundation

enum ProductID {
    static let monthly = "com.firstgrowth.sprout.pro.monthly"
    static let yearly = "com.firstgrowth.sprout.pro.yearly"

    static var all: [String] { [monthly, yearly] }
}
