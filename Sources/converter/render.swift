import Foundation
import SwiftSoup

/// Helper function to get children
func getChildren(_ node: Node) -> [Node] {
    if let element = node as? Element {
        var children: [Node] = []
        for child in element.getChildNodes() {
            children.append(child)
        }
        return children
    }
    return []
}

/// Helper to render children
func renderChildren(_ node: Node, converter: Converter) throws -> String {
    var result = ""
    for child in getChildren(node) {
        result += try converter.convertNode(child)
    }
    return result
}
