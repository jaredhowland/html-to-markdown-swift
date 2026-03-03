import XCTest
@testable import HTMLToMarkdown

// helper — trimming wrapper
private func convert(_ html: String, options: [ConverterOption] = []) throws -> String {
    return try HTMLToMarkdown.convert(html, options: options)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
private func convert(_ html: String, plugins: [Plugin]) throws -> String {
    return try HTMLToMarkdown.convert(html, plugins: plugins)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
private func convertPlugins(_ html: String, options: CommonmarkOptions) throws -> String {
    return try HTMLToMarkdown.convert(html, plugins: [BasePlugin(), CommonmarkPlugin(options: options)])
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

class EscapeCodeTests: XCTestCase {

    func testEscapeTildeFencedCode() throws {
        // "~~~" at start of line would open a fenced code block — escape first ~
        XCTAssertEqual(try convert("<p>~~~fenced code~~~</p>"), "\\~~~fenced code~~~")
    }

    func testEscapeBacktickFencedOpening() throws {
        // "```code```": only the FIRST backtick in the 3+ opening fence is escaped,
        // matching Go's IsFencedCode skip behaviour.
        XCTAssertEqual(try convert("<p>```code```</p>"), "\\```code\\`\\`\\`")
    }
}
