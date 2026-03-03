import Foundation
import SwiftSoup

// MARK: - Table Rendering

extension TablePlugin {
    func renderTable(_ table: Element, ctx: Context) throws -> String? {
        if !options.presentationTables {
            if let role = try? table.attr("role"), role == "presentation" {
                return nil
            }
        }
        if hasProblematicChildNode(table) { return nil }
        if hasProblematicParentNode(table) { return nil }

        let headerRow = selectHeaderRowNode(table)
        let normalRows = selectNormalRowNodes(table, headerRow: headerRow)

        var rows = try collectRows(table, headerRow: headerRow, normalRows: normalRows, ctx: ctx)
        if rows.isEmpty { return nil }

        for i in 0..<rows.count {
            for j in 0..<rows[i].count {
                if rows[i][j].contains("\n") {
                    if options.newlineBehavior == .preserve {
                        rows[i][j] = rows[i][j].replacingOccurrences(of: "\n", with: "<br />")
                    } else {
                        return nil
                    }
                }
            }
        }

        let alignments = collectAlignments(headerRow: headerRow, normalRows: normalRows)
        let caption = try collectCaption(table, ctx: ctx)

        var maxWidths: [Int] = []
        for row in rows {
            for (i, cell) in row.enumerated() {
                if i >= maxWidths.count { maxWidths.append(1) }
                let count = cell.count
                if count > maxWidths[i] { maxWidths[i] = count }
            }
        }
        guard !maxWidths.isEmpty else { return nil }

        let colCount = maxWidths.count
        for i in 0..<rows.count {
            while rows[i].count < colCount { rows[i].append("") }
        }

        var result = "\n\n"
        result += writeRow(rows[0], maxWidths: maxWidths)
        result += "\n"
        result += writeHeaderUnderline(alignments: alignments, maxWidths: maxWidths)
        result += "\n"
        for row in rows.dropFirst() {
            result += writeRow(Array(row.prefix(colCount)), maxWidths: maxWidths)
            result += "\n"
        }
        if let caption = caption {
            result += "\n\n"
            result += caption
        }
        result += "\n\n"
        return result
    }
}
