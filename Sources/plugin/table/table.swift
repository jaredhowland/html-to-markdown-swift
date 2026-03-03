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
    var name: String { return "table" }
    let options: TableOptions

    init(options: TableOptions = TableOptions()) {
        self.options = options
    }

    func initialize(conv: Converter) throws {
        conv.Register.tagType("td", .inline, priority: PriorityStandard)
        conv.Register.tagType("th", .inline, priority: PriorityStandard)

        conv.Register.rendererFor("table", .block, { [weak self] ctx, w, n in
            guard let self = self, let tableElement = n as? Element else { return .tryNext }
            guard let result = try? self.renderTable(tableElement, ctx: ctx) else { return .tryNext }
            w.writeString(result)
            return .success
        }, priority: PriorityStandard)

        for tag in ["tr", "tbody", "thead", "tfoot"] {
            let tagLower = tag
            conv.Register.renderer({ ctx, w, n in
                let name = (n as? Element)?.tagName().lowercased() ?? n.nodeName().lowercased()
                guard name == tagLower else { return .tryNext }
                let buf = StringWriter()
                ctx.renderChildNodes(buf, n)
                w.writeString(trimConsecutiveNewlines("\n\n\(buf.string)\n\n"))
                return .success
            }, priority: PriorityStandard)
        }
    }
}
