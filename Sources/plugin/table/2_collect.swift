import Foundation
import SwiftSoup

// MARK: - Problematic Node Checks

extension TablePlugin {
    func hasProblematicChildNode(_ table: Element) -> Bool {
        let problematic: Set<String> = ["h1","h2","h3","h4","h5","h6","table","hr","ul","ol","blockquote"]
        return tableDescendants(table).contains { problematic.contains($0.tagName()) }
    }

    // Returns all descendant elements (not the element itself), matching Go's dom.FindFirstNode behavior
    func tableDescendants(_ element: Element) -> [Element] {
        var result: [Element] = []
        for child in element.children() {
            result.append(child)
            result.append(contentsOf: tableDescendants(child))
        }
        return result
    }

    func hasProblematicParentNode(_ element: Element) -> Bool {
        var parent = element.parent()
        while let p = parent {
            let name = p.tagName()
            if ["a", "strong", "b", "em", "i", "del", "s", "strike"].contains(name) {
                return true
            }
            parent = p.parent()
        }
        return false
    }
}

// MARK: - Span Modifications (colspan/rowspan)

extension TablePlugin {
    struct CellModification {
        let row: Int
        let col: Int
        let data: String
    }

    func calculateModifications(rowIndex: Int, colIndex: Int, rowSpan: Int, colSpan: Int, data: String) -> [CellModification] {
        var mods: [CellModification] = []
        if colSpan <= 1 && rowSpan <= 1 { return mods }
        for dx in 1..<colSpan {
            mods.append(CellModification(row: rowIndex, col: colIndex + dx, data: data))
        }
        if rowSpan > 1 {
            for dy in 1..<rowSpan {
                for dx in 0..<colSpan {
                    mods.append(CellModification(row: rowIndex + dy, col: colIndex + dx, data: data))
                }
            }
        }
        return mods
    }

    func applyGroupedModifications(_ rows: inout [[String]], _ groupedMods: [[CellModification]]) {
        for mods in groupedMods.reversed() {
            applyModifications(&rows, mods)
        }
    }

    func applyModifications(_ rows: inout [[String]], _ mods: [CellModification]) {
        for mod in mods {
            while rows.count <= mod.row { rows.append([]) }
            while rows[mod.row].count < mod.col { rows[mod.row].append("") }
            rows[mod.row].insert(mod.data, at: mod.col)
        }
    }
}

// MARK: - Cell and Row Collection

extension TablePlugin {
    func getIntAttr(_ element: Element, _ attr: String, fallback: Int) -> Int {
        guard let val = try? element.attr(attr), !val.isEmpty,
              let num = Int(val), num >= 1 else { return fallback }
        return num
    }

    func collectCellsInRow(_ rowElement: Element, rowIndex: Int, ctx: Context) throws -> ([String], [CellModification]) {
        let cellElements = (try? rowElement.select("td,th").array()) ?? []
        var cells: [String] = []
        var allMods: [CellModification] = []

        for (colIndex, cellNode) in cellElements.enumerated() {
            let cbuf = StringWriter(); ctx.renderChildNodes(cbuf, cellNode); var content = cbuf.string
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if ctx.conv.escapeMode != .disabled {
                content = ctx.unEscapeContent(content)
                content = content.replacingOccurrences(of: "|", with: "\\|")
            }
            cells.append(content)

            let colSpan = getIntAttr(cellNode, "colspan", fallback: 1)
            let rowSpan = getIntAttr(cellNode, "rowspan", fallback: 1)
            let mergedData = options.spanCellBehavior == .mirror ? content : ""
            allMods.append(contentsOf: calculateModifications(
                rowIndex: rowIndex, colIndex: colIndex,
                rowSpan: rowSpan, colSpan: colSpan, data: mergedData
            ))
        }
        return (cells, allMods)
    }

    func collectRows(_ table: Element, headerRow: Element?, normalRows: [Element], ctx: Context) throws -> [[String]] {
        var rows: [[String]] = []
        var groupedMods: [[CellModification]] = []

        if let headerRow = headerRow {
            let (cells, mods) = try collectCellsInRow(headerRow, rowIndex: 0, ctx: ctx)
            rows.append(cells)
            groupedMods.append(mods)
        } else {
            rows.append([])
            groupedMods.append([])
        }

        for (index, rowNode) in normalRows.enumerated() {
            let (cells, mods) = try collectCellsInRow(rowNode, rowIndex: index + 1, ctx: ctx)
            rows.append(cells)
            groupedMods.append(mods)
        }

        applyGroupedModifications(&rows, groupedMods)

        if options.skipEmptyRows {
            rows = removeEmptyRows(rows)
        }
        if options.headerPromotion {
            rows = removeFirstRowIfEmpty(rows)
        }
        return rows
    }

    func removeEmptyRows(_ rows: [[String]]) -> [[String]] {
        var result: [[String]] = []
        for (i, row) in rows.enumerated() {
            if i == 0 || row.contains(where: { !$0.isEmpty }) {
                result.append(row)
            }
        }
        if result.count == 1 && result[0].allSatisfy({ $0.isEmpty }) {
            return []
        }
        return result
    }

    func removeFirstRowIfEmpty(_ rows: [[String]]) -> [[String]] {
        guard let first = rows.first, first.allSatisfy({ $0.isEmpty }) else { return rows }
        return Array(rows.dropFirst())
    }
}

// MARK: - Alignments and Caption

extension TablePlugin {
    func collectAlignments(headerRow: Element?, normalRows: [Element]) -> [String] {
        let firstRow = headerRow ?? normalRows.first
        guard let firstRow = firstRow else { return [] }
        let cellElements = (try? firstRow.select("td,th").array()) ?? []
        return cellElements.map { (try? $0.attr("align")) ?? "" }
    }

    func collectCaption(_ table: Element, ctx: Context) throws -> String? {
        guard let captionEl = try? table.select("caption").first() else { return nil }
        let cbuf = StringWriter(); ctx.renderChildNodes(cbuf, captionEl); var content = cbuf.string
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }
}
