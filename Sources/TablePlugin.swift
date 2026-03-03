import Foundation
import SwiftSoup

// MARK: - TablePlugin Option Types

/// How cells affected by colspan/rowspan should be rendered
public enum SpanCellBehavior: String {
    /// Render an empty cell (default)
    case empty = "empty"
    /// Render the same content as the original cell
    case mirror = "mirror"
}

/// How to handle newlines in table cells
public enum NewlineBehavior: String {
    /// Skip tables with newlines in cells (default)
    case skip = "skip"
    /// Preserve newlines in cells
    case preserve = "preserve"
}

/// How to pad table cells
public enum CellPaddingBehavior: String {
    /// Pad cells to match the widest cell in each column (default)
    case aligned = "aligned"
    /// Add a single space at the start and end of each cell
    case minimal = "minimal"
    /// No extra padding
    case none = "none"
}

/// Options for the Table plugin
public struct TableOptions {
    /// How cells affected by colspan/rowspan are rendered (default: .empty)
    public var spanCellBehavior: SpanCellBehavior = .empty
    /// How newlines in cells are handled (default: .skip)
    public var newlineBehavior: NewlineBehavior = .skip
    /// How cells are padded (default: .aligned)
    public var cellPaddingBehavior: CellPaddingBehavior = .aligned
    /// Whether to omit rows where all cells are empty (default: false)
    public var skipEmptyRows: Bool = false
    /// Whether to promote the first body row to header if no header exists (default: false)
    public var headerPromotion: Bool = false
    /// Whether to convert tables with role="presentation" (default: false)
    public var presentationTables: Bool = false

    public init() {}
}

/// Plugin for GFM table support
class TablePlugin: Plugin {
    let options: TableOptions

    init(options: TableOptions = TableOptions()) {
        self.options = options
    }

    func register(with converter: Converter) {
        converter.registerTagType("td", type: .inline, priority: .standard)
        converter.registerTagType("th", type: .inline, priority: .standard)

        converter.registerRenderer("table") { [weak self] node, converter in
            guard let self = self, let tableElement = node as? Element else { return nil }
            return try self.renderTable(tableElement, converter: converter)
        }

        // Register fallback block renderers for table structural elements without
        // collapseInlineSpaces, matching Go's renderFallbackRow and default block rendering.
        // This prevents collapsing spaces inside markdown table cells (e.g. "|      |").
        for tag in ["tr", "tbody", "thead", "tfoot"] {
            converter.registerRenderer(tag) { node, converter in
                let children = try renderChildren(node, converter: converter)
                return trimConsecutiveNewlines("\n\n\(children)\n\n")
            }
        }
    }

    // MARK: - Row Selection

    private func selectHeaderRowNode(_ table: Element) -> Element? {
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

    private func selectNormalRowNodes(_ table: Element, headerRow: Element?) -> [Element] {
        guard let allRows = try? table.select("tr") else { return [] }
        return allRows.array().filter { $0 !== headerRow }
    }

    // MARK: - Problematic Node Checks

    private func hasProblematicChildNode(_ table: Element) -> Bool {
        let problematic: Set<String> = ["h1","h2","h3","h4","h5","h6","table","hr","ul","ol","blockquote"]
        return tableDescendants(table).contains { problematic.contains($0.tagName()) }
    }

    // Returns all descendant elements (not the element itself), matching Go's dom.FindFirstNode behavior
    private func tableDescendants(_ element: Element) -> [Element] {
        var result: [Element] = []
        for child in element.children() {
            result.append(child)
            result.append(contentsOf: tableDescendants(child))
        }
        return result
    }

    private func hasProblematicParentNode(_ element: Element) -> Bool {
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

    // MARK: - Span Modifications (colspan/rowspan)

    private struct CellModification {
        let row: Int
        let col: Int
        let data: String
    }

    private func calculateModifications(rowIndex: Int, colIndex: Int, rowSpan: Int, colSpan: Int, data: String) -> [CellModification] {
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

    private func applyGroupedModifications(_ rows: inout [[String]], _ groupedMods: [[CellModification]]) {
        for mods in groupedMods.reversed() {
            applyModifications(&rows, mods)
        }
    }

    private func applyModifications(_ rows: inout [[String]], _ mods: [CellModification]) {
        for mod in mods {
            while rows.count <= mod.row { rows.append([]) }
            while rows[mod.row].count < mod.col { rows[mod.row].append("") }
            rows[mod.row].insert(mod.data, at: mod.col)
        }
    }

    // MARK: - Cell and Row Collection

    private func getIntAttr(_ element: Element, _ attr: String, fallback: Int) -> Int {
        guard let val = try? element.attr(attr), !val.isEmpty,
              let num = Int(val), num >= 1 else { return fallback }
        return num
    }

    private func collectCellsInRow(_ rowElement: Element, rowIndex: Int, converter: Converter) throws -> ([String], [CellModification]) {
        let cellElements = (try? rowElement.select("td,th").array()) ?? []
        var cells: [String] = []
        var allMods: [CellModification] = []

        for (colIndex, cellNode) in cellElements.enumerated() {
            var content = try renderChildren(cellNode, converter: converter)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Apply smart escaping now so cell.count reflects final visible width.
            // This mirrors Go's ctx.UnEscapeContent which resolves escape markers in cells.
            if converter.getOptions().escapeMode != .disabled {
                content = applySmartEscaping(content)
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

    private func collectRows(_ table: Element, headerRow: Element?, normalRows: [Element], converter: Converter) throws -> [[String]] {
        var rows: [[String]] = []
        var groupedMods: [[CellModification]] = []

        if let headerRow = headerRow {
            let (cells, mods) = try collectCellsInRow(headerRow, rowIndex: 0, converter: converter)
            rows.append(cells)
            groupedMods.append(mods)
        } else {
            rows.append([])
            groupedMods.append([])
        }

        for (index, rowNode) in normalRows.enumerated() {
            let (cells, mods) = try collectCellsInRow(rowNode, rowIndex: index + 1, converter: converter)
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

    private func removeEmptyRows(_ rows: [[String]]) -> [[String]] {
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

    private func removeFirstRowIfEmpty(_ rows: [[String]]) -> [[String]] {
        guard let first = rows.first, first.allSatisfy({ $0.isEmpty }) else { return rows }
        return Array(rows.dropFirst())
    }

    // MARK: - Alignments and Caption

    private func collectAlignments(headerRow: Element?, normalRows: [Element]) -> [String] {
        let firstRow = headerRow ?? normalRows.first
        guard let firstRow = firstRow else { return [] }
        let cellElements = (try? firstRow.select("td,th").array()) ?? []
        return cellElements.map { (try? $0.attr("align")) ?? "" }
    }

    private func collectCaption(_ table: Element, converter: Converter) throws -> String? {
        guard let captionEl = try? table.select("caption").first() else { return nil }
        var content = try renderChildren(captionEl, converter: converter)
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }

    // MARK: - Table Rendering

    private func renderTable(_ table: Element, converter: Converter) throws -> String? {
        if !options.presentationTables {
            if let role = try? table.attr("role"), role == "presentation" {
                return nil
            }
        }
        if hasProblematicChildNode(table) { return nil }
        if hasProblematicParentNode(table) { return nil }

        let headerRow = selectHeaderRowNode(table)
        let normalRows = selectNormalRowNodes(table, headerRow: headerRow)

        var rows = try collectRows(table, headerRow: headerRow, normalRows: normalRows, converter: converter)
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
        let caption = try collectCaption(table, converter: converter)

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

    // MARK: - Row and Separator Writing

    private func writeRow(_ cells: [String], maxWidths: [Int]) -> String {
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

    private func writeHeaderUnderline(alignments: [String], maxWidths: [Int]) -> String {
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
