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
    /// Whether to promote the first body row to header if no <thead> exists (default: false)
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
        converter.registerTagType("table", type: .block, priority: .standard)
        converter.registerTagType("thead", type: .block, priority: .standard)
        converter.registerTagType("tbody", type: .block, priority: .standard)
        converter.registerTagType("tfoot", type: .block, priority: .standard)
        converter.registerTagType("tr", type: .block, priority: .standard)
        converter.registerTagType("td", type: .inline, priority: .standard)
        converter.registerTagType("th", type: .inline, priority: .standard)

        registerTableRenderers(converter: converter)
    }

    private func registerTableRenderers(converter: Converter) {
        converter.registerRenderer("table") { [weak self] node, converter in
            guard let self = self else { return nil }
            guard let tableElement = node as? Element else { return nil }

            // Skip presentation tables unless configured to convert them
            if !self.options.presentationTables {
                let role = (try? tableElement.attr("role")) ?? ""
                if role == "presentation" { return "" }
            }

            var headerRow: [String] = []
            var alignments: [String] = []
            var rows: [[String]] = []

            // Collect header from <thead>
            if let thead = try? tableElement.select("thead").first(),
               let tr = try? thead.select("tr").first() {
                let cells = try tr.select("th, td")
                for cell in cells {
                    let content = try renderChildren(cell, converter: converter)
                    headerRow.append(collapseWhitespace(content))
                    alignments.append((try? cell.attr("align")) ?? "")
                }
            }

            // Collect body rows from <tbody>
            if let bodyRows = try? tableElement.select("tbody tr") {
                for tr in bodyRows {
                    var row: [String] = []
                    for cell in try tr.select("td, th") {
                        let content = try renderChildren(cell, converter: converter)
                        row.append(collapseWhitespace(content))
                    }
                    if !row.isEmpty { rows.append(row) }
                }
            }

            // Fall back to <tfoot> as header if no <thead>
            if headerRow.isEmpty {
                if let tfoot = try? tableElement.select("tfoot").first(),
                   let tr = try? tfoot.select("tr").first() {
                    for cell in try tr.select("th, td") {
                        let content = try renderChildren(cell, converter: converter)
                        headerRow.append(collapseWhitespace(content))
                    }
                }
            }

            // If still no header, optionally promote first body row
            if headerRow.isEmpty && self.options.headerPromotion && !rows.isEmpty {
                headerRow = rows.removeFirst()
            }

            guard !headerRow.isEmpty else { return "" }

            // Check for newlines in cells (if skip behavior)
            if self.options.newlineBehavior == .skip {
                let allCells = [headerRow] + rows
                let hasNewline = allCells.flatMap { $0 }.contains { $0.contains("\n") }
                if hasNewline { return "" }
            }

            // Skip empty rows if configured
            if self.options.skipEmptyRows {
                rows = rows.filter { row in
                    row.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                }
            }

            // Fill short rows with empty cells
            let colCount = headerRow.count
            rows = rows.map { row in
                var r = row
                while r.count < colCount { r.append("") }
                return r
            }

            // Calculate max column widths
            var maxWidths = Array(repeating: 0, count: colCount)
            for (i, cell) in headerRow.enumerated() where i < colCount {
                maxWidths[i] = max(maxWidths[i], cell.count)
            }
            for row in rows {
                for (i, cell) in row.enumerated() where i < colCount {
                    maxWidths[i] = max(maxWidths[i], cell.count)
                }
            }

            var markdown = "\n\n"

            // Header row
            markdown += self.writeRow(headerRow, maxWidths: maxWidths)
            markdown += "\n"

            // Separator row
            markdown += self.writeSeparator(alignments: alignments, maxWidths: maxWidths)
            markdown += "\n"

            // Body rows
            for row in rows {
                markdown += self.writeRow(Array(row.prefix(colCount)), maxWidths: maxWidths)
                markdown += "\n"
            }

            markdown += "\n"
            return markdown
        }
    }

    private func writeRow(_ cells: [String], maxWidths: [Int]) -> String {
        var row = ""
        for (i, cell) in cells.enumerated() {
            if i == 0 { row += "|" }
            switch options.cellPaddingBehavior {
            case .aligned:
                let filler = max(0, (i < maxWidths.count ? maxWidths[i] : 0) - cell.count)
                row += " \(cell)\(String(repeating: " ", count: filler)) |"
            case .minimal:
                row += " \(cell) |"
            case .none:
                row += "\(cell)|"
            }
        }
        return row
    }

    private func writeSeparator(alignments: [String], maxWidths: [Int]) -> String {
        var sep = ""
        for (i, maxWidth) in maxWidths.enumerated() {
            if i == 0 { sep += "|" }
            let align = i < alignments.count ? alignments[i] : ""
            switch options.cellPaddingBehavior {
            case .aligned:
                let leftChar: Character = (align == "left" || align == "center") ? ":" : "-"
                let rightChar: Character = (align == "right" || align == "center") ? ":" : "-"
                sep += "\(leftChar)\(String(repeating: "-", count: maxWidth))\(rightChar)|"
            case .minimal:
                let leftChar: Character = (align == "left" || align == "center") ? ":" : "-"
                let rightChar: Character = (align == "right" || align == "center") ? ":" : "-"
                sep += "\(leftChar)-\(rightChar)|"
            case .none:
                sep += "---|"
            }
        }
        return sep
    }
}
