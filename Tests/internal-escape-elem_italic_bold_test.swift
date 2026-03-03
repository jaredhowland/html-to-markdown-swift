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

class EscapeItalicBoldTests: XCTestCase {

    func testEscapeAsteriskEmphasis() throws {
        // *word* would form emphasis — only escape the opening left-flanking *
        // (matching Go's IsItalicOrBold which only escapes left-flanking delimiters)
        let result = try convert("<p>text *emphasis* more</p>")
        XCTAssertEqual(result, "text \\*emphasis* more")
    }

    func testNoEscapeAsteriskFollowedBySpace() throws {
        // * followed by space is NOT an emphasis marker, no escaping
        let result = try convert("<p>text * more</p>")
        XCTAssertEqual(result, "text * more")
    }
}
