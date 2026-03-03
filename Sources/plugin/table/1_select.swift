import Foundation
import SwiftSoup

// MARK: - Row Selection

extension TablePlugin {
    func selectHeaderRowNode(_ table: Element) -> Element? {
        if let thead = try? table.select("thead").first(),
           let tr = try? thead.select("tr").first() {
            return tr
        }
        if let th = try? table.select("th").first(),
           let parent = th.parent() {
            return parent
        }
        return nil
    }

    func selectNormalRowNodes(_ table: Element, headerRow: Element?) -> [Element] {
        guard let allRows = try? table.select("tr") else { return [] }
        return allRows.array().filter { $0 !== headerRow }
    }
}
