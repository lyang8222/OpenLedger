import Foundation
import OpenLedgerCore

enum CategoryRuleStore {
    private static let key = "category.rules"

    static func load() -> [CategoryRule] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rules = try? JSONDecoder().decode([CategoryRule].self, from: data) else {
            return []
        }
        return rules
    }

    static func save(_ rules: [CategoryRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
