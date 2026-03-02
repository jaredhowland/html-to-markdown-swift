import Foundation
import SwiftSoup

/// Options for the Table plugin
public struct TableOptions {
    public var removePadding: Bool = false
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
        // Table
        converter.registerRenderer("table") { node, converter in
            guard let tableElement = node as? Element else { return nil }
            
            var markdown = "\n"
            
            // Get all rows
            var rows: [[String]] = []
            var headerRow: [String] = []
            var alignments: [String] = []
            
            // Process table structure
            if let thead = try? tableElement.select("thead").first() {
                if let tr = try? thead.select("tr").first() {
                    let cells = try tr.select("th, td")
                    for cell in cells {
                        let content = try renderChildren(cell, converter: converter)
                        let text = collapseWhitespace(content)
                        headerRow.append(text)
                        
                        // Get alignment
                        let align = (try? cell.attr("align")) ?? ""
                        alignments.append(align)
                    }
                }
            }
            
            // Get all body rows
            let bodySelector = try? tableElement.select("tbody tr")
            if let bodyRows = bodySelector {
                for tr in bodyRows {
                    var row: [String] = []
                    let cells = try tr.select("td, th")
                    for cell in cells {
                        let content = try renderChildren(cell, converter: converter)
                        let text = collapseWhitespace(content)
                        row.append(text)
                    }
                    if !row.isEmpty {
                        rows.append(row)
                    }
                }
            }
            
            // Use footer as header if no thead
            if headerRow.isEmpty {
                if let tfoot = try? tableElement.select("tfoot").first() {
                        if let tr = try? tfoot.select("tr").first() {
                            let cells = try tr.select("th, td")
                            for cell in cells {
                                let content = try renderChildren(cell, converter: converter)
                                let text = collapseWhitespace(content)
                                headerRow.append(text)
                            }
                        }
                }
            }
            
            // Build markdown table
            if !headerRow.isEmpty {
                // Header row
                markdown += "| " + headerRow.joined(separator: " | ") + " |\n"
                
                // Separator row
                let separators = headerRow.map { _ in "---" }
                markdown += "| " + separators.joined(separator: " | ") + " |\n"
                
                // Body rows
                for r in rows {
                    var row = r
                    while row.count < headerRow.count {
                        row.append("")
                    }
                    markdown += "| " + row.prefix(headerRow.count).joined(separator: " | ") + " |\n"
                }
            }
            
            return markdown + "\n"
        }
    }
}
