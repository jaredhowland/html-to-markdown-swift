import XCTest
@testable import HTMLToMarkdown

class TextutilsDelimiterTests: XCTestCase {
    func testSimpleText() {
        XCTAssertEqual(DelimiterForEveryLine("bold text", delimiter: "**"), "**bold text**")
    }
    func testWhitespaceOutside() {
        XCTAssertEqual(DelimiterForEveryLine(" bold text ", delimiter: "**"), " **bold text** ")
    }
    func testNonBreakingSpaceOutside() {
        let nbsp = "\u{00A0}"
        XCTAssertEqual(
            DelimiterForEveryLine("\(nbsp)bold text\(nbsp)\(nbsp)", delimiter: "**"),
            "\(nbsp)**bold text**\(nbsp)\(nbsp)"
        )
    }
    func testEveryLine() {
        XCTAssertEqual(DelimiterForEveryLine("line 1\nline 2", delimiter: "**"), "**line 1**\n**line 2**")
    }
    func testSkipEmptyLines() {
        XCTAssertEqual(DelimiterForEveryLine("line 1\n\n\nline 2", delimiter: "_"), "_line 1_\n\n\n_line 2_")
    }
    func testNonBreakingSpaceEveryLine() {
        let nbsp = "\u{00A0}"
        let input = "bold\(nbsp)\ntext\(nbsp)"
        let expected = "**bold**\(nbsp)\n**text**\(nbsp)"
        XCTAssertEqual(DelimiterForEveryLine(input, delimiter: "**"), expected)
    }
}
