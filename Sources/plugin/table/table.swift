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
}
