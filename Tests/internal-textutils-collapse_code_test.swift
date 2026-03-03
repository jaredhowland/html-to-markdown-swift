import XCTest
@testable import HTMLToMarkdown

class TextutilsCollapseCodeTests: XCTestCase {
    func testEmpty()            { XCTAssertEqual(CollapseInlineCodeContent(""), "") }
    func testNotNeeded()        { XCTAssertEqual(CollapseInlineCodeContent("a b"), "a b") }
    func testOneNewline()       { XCTAssertEqual(CollapseInlineCodeContent("a\nb"), "a b") }
    func testMultipleNewlines() { XCTAssertEqual(CollapseInlineCodeContent("a\nb\n\nc"), "a b c") }
    func testAlsoTrim()         { XCTAssertEqual(CollapseInlineCodeContent(" a b "), "a b") }
    func testRealisticCSS() {
        let input = "\n\t\tbody {\n\t\t\tcolor: yellow;\n\t\t\tfont-size: 16px;\n\t\t}\n\t\t"
        XCTAssertEqual(CollapseInlineCodeContent(input), "body { color: yellow; font-size: 16px; }")
    }
}
