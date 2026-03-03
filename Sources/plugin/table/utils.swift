import Foundation
import SwiftSoup

// MARK: - Row and Separator Writing

extension TablePlugin {
    func writeRow(_ cells: [String], maxWidths: [Int]) -> String {
        var row = ""
        for (i, cell) in cells.enumerated() {
            if i == 0 { row += "|" }
            switch options.cellPaddingBehavior {
            case .aligned:
                let width = i < maxWidths.count ? maxWidths[i] : 1
                let filler = max(0, width - cell.count)
                row += " \(cell)\(String(repeating: " ", count: filler)) |"
            case .minimal:
                row += " \(cell) |"
            case .none:
                row += "\(cell)|"
            }
        }
        return row
    }

    func writeHeaderUnderline(alignments: [String], maxWidths: [Int]) -> String {
        var sep = ""
        for (i, maxWidth) in maxWidths.enumerated() {
            if i == 0 { sep += "|" }
            let align = i < alignments.count ? alignments[i] : ""
            switch options.cellPaddingBehavior {
            case .aligned:
                let left: Character = (align == "left" || align == "center") ? ":" : "-"
                let right: Character = (align == "right" || align == "center") ? ":" : "-"
                sep += "\(left)\(String(repeating: "-", count: maxWidth))\(right)|"
            case .minimal:
                let left: Character = (align == "left" || align == "center") ? ":" : "-"
                let right: Character = (align == "right" || align == "center") ? ":" : "-"
                sep += "\(left)-\(right)|"
            case .none:
                sep += "---|"
            }
        }
        return sep
    }
}
