import Foundation
import SwiftSoup

func extractCodeLanguage(from element: Element) -> String {
    let cls = (try? element.attr("class")) ?? ""
    let parts = cls.components(separatedBy: " ")
    for part in parts {
        if part.hasPrefix("language-") {
            return String(part.dropFirst("language-".count))
        }
        if part.hasPrefix("lang-") {
            return String(part.dropFirst("lang-".count))
        }
    }
    return ""
}

func extractRawText(from node: Node) -> String {
    var result = ""
    for child in node.getChildNodes() {
        if let textNode = child as? TextNode {
            result += textNode.getWholeText()
        } else if let element = child as? Element {
            let tag = element.tagName()
            if tag == "br" || tag == "div" {
                result += "\n"
            }
            result += extractRawText(from: element)
        }
    }
    return result
}
