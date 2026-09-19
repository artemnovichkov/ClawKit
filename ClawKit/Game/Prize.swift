import SwiftUI

/// How hard a prize is to find and to hold on to.
enum Rarity: Int, CaseIterable, Codable, Comparable {
    case common, rare, epic, legendary

    var title: String {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .epic: "Epic"
        case .legendary: "Legendary"
        }
    }

    /// Relative chance to appear in the machine.
    var spawnWeight: Double {
        switch self {
        case .common: 60
        case .rare: 25
        case .epic: 11
        case .legendary: 4
        }
    }

    /// Chance that the claw holds the prize once it closes on it.
    var gripChance: Double {
        switch self {
        case .common: 0.6
        case .rare: 0.45
        case .epic: 0.3
        case .legendary: 0.2
        }
    }

    var color: Color {
        switch self {
        case .common: Color(red: 0.55, green: 0.55, blue: 0.6)
        case .rare: Color(red: 0.25, green: 0.55, blue: 0.95)
        case .epic: Color(red: 0.62, green: 0.35, blue: 0.9)
        case .legendary: Color(red: 0.95, green: 0.65, blue: 0.1)
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Everything an iOS developer might pull out of the machine.
enum PrizeKind: String, CaseIterable, Codable, Identifiable {
    case star, heart, braces, warning, gear
    case bug, hammer, spinner, stateCube
    case bird, simulator
    case buildSucceeded, approved, duo

    var id: String { rawValue }

    var name: String {
        switch self {
        case .star: "Star"
        case .heart: "Heart"
        case .braces: "Curly Braces"
        case .warning: "Warning"
        case .gear: "Gear"
        case .bug: "Bug"
        case .hammer: "Hammer"
        case .spinner: "Spinner"
        case .stateCube: "@State"
        case .bird: "Bird"
        case .simulator: "Simulator"
        case .buildSucceeded: "Build Succeeded"
        case .approved: "Approved"
        case .duo: "Tiny Duo"
        }
    }

    var rarity: Rarity {
        switch self {
        case .star, .heart, .braces, .warning, .gear: .common
        case .bug, .hammer, .spinner, .stateCube: .rare
        case .bird, .simulator: .epic
        case .buildSucceeded, .approved, .duo: .legendary
        }
    }

    /// The SF Symbol for the prize on the shelf.
    var symbol: String {
        switch self {
        case .star: "star.fill"
        case .heart: "heart.fill"
        case .braces: "curlybraces"
        case .warning: "exclamationmark.triangle.fill"
        case .gear: "gearshape.fill"
        case .bug: "ladybug.fill"
        case .hammer: "hammer.fill"
        case .spinner: "progress.indicator"
        case .stateCube: "at"
        case .bird: "bird.fill"
        case .simulator: "iphone.gen3"
        case .buildSucceeded: "checkmark.circle.fill"
        case .approved: "checkmark.seal.fill"
        case .duo: "laptopcomputer"
        }
    }

    /// The main plasticine color.
    var color: Color {
        Color(uiColor: uiColor)
    }

    var uiColor: UIColor {
        switch self {
        case .star: UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)
        case .heart: UIColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 1)
        case .braces: UIColor(red: 0.6, green: 0.45, blue: 0.95, alpha: 1)
        case .warning: UIColor(red: 1.0, green: 0.72, blue: 0.15, alpha: 1)
        case .gear: UIColor(red: 0.55, green: 0.65, blue: 0.75, alpha: 1)
        case .bug: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        case .hammer: UIColor(red: 0.45, green: 0.6, blue: 0.85, alpha: 1)
        case .spinner: UIColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1)
        case .stateCube: UIColor(red: 0.2, green: 0.75, blue: 0.7, alpha: 1)
        case .bird: UIColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1)
        case .simulator: UIColor(red: 0.3, green: 0.32, blue: 0.4, alpha: 1)
        case .buildSucceeded: UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1)
        case .approved: UIColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 1)
        case .duo: UIColor(red: 0.25, green: 0.27, blue: 0.35, alpha: 1)
        }
    }

    /// Picks a random prize, weighted by rarity.
    static func random() -> PrizeKind {
        let total = allCases.reduce(0) { $0 + $1.rarity.spawnWeight / Double($1.rarity.count) }
        var roll = Double.random(in: 0..<total)
        for kind in allCases {
            roll -= kind.rarity.spawnWeight / Double(kind.rarity.count)
            if roll < 0 { return kind }
        }
        return .star
    }
}

private extension Rarity {
    /// How many prize kinds share this rarity.
    var count: Int {
        PrizeKind.allCases.count { $0.rarity == self }
    }
}
