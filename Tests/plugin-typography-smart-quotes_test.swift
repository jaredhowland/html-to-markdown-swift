import XCTest
@testable import HTMLToMarkdown

private func makeConverter(style: QuoteStyle = .english) throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(SmartQuotesPlugin(style: style))
    return conv
}

private func convert(_ html: String, style: QuoteStyle = .english) throws -> String {
    let conv = try makeConverter(style: style)
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class SmartQuotesPluginTests: XCTestCase {

    func testDoubleQuotesPaired() throws {
        let result = try convert("<p>She said \"hello\".</p>")
        XCTAssertTrue(result.contains("\u{201C}hello\u{201D}"),
                      "Expected curly double quotes in: \(result)")
        XCTAssertFalse(result.contains("\""), "Should not contain straight double quote in: \(result)")
    }

    func testDoubleQuotesAtStart() throws {
        let result = try convert("<p>\"Quote at start.\"</p>")
        XCTAssertTrue(result.contains("\u{201C}Quote at start.\u{201D}"),
                      "Expected open double quote at start in: \(result)")
    }

    func testApostropheInContraction() throws {
        let result = try convert("<p>don't</p>")
        XCTAssertTrue(result.contains("don\u{2019}t"),
                      "Expected right single quote (apostrophe) in contraction: \(result)")
    }

    func testApostropheInPossessive() throws {
        let result = try convert("<p>John's book</p>")
        XCTAssertTrue(result.contains("John\u{2019}s"),
                      "Expected apostrophe in possessive: \(result)")
    }

    func testSingleQuotesPaired() throws {
        let result = try convert("<p>She said 'hello'.</p>")
        XCTAssertTrue(result.contains("\u{2018}hello\u{2019}"),
                      "Expected curly single quotes in: \(result)")
    }

    func testQElementDoubleQuotes() throws {
        let result = try convert("<p>She said <q>hello world</q>.</p>")
        XCTAssertTrue(result.contains("\u{201C}hello world\u{201D}"),
                      "Expected <q> rendered as double quotes in: \(result)")
    }

    func testGermanQuotes() throws {
        let result = try convert("<p>Er sagte \"Hallo\".</p>", style: .german)
        // German: „Hallo" — open is U+201E „, close is U+201C "
        XCTAssertTrue(result.contains("\u{201E}Hallo\u{201C}"),
                      "Expected German double quotes in: \(result)")
    }

    func testFrenchQuotes() throws {
        let result = try convert("<p>Il dit \"bonjour\".</p>", style: .french)
        XCTAssertTrue(result.contains("\u{00AB}") && result.contains("\u{00BB}"),
                      "Expected French guillemets in: \(result)")
    }

    func testCodeBlockUntouched() throws {
        let result = try convert("<pre><code>print(\"hello\")</code></pre>")
        XCTAssertTrue(result.contains("\"hello\""),
                      "Straight quotes in code block must not be replaced in: \(result)")
        XCTAssertFalse(result.contains("\u{201C}"),
                       "Should not replace in code block: \(result)")
    }

    func testInlineCodeUntouched() throws {
        let result = try convert("<p>Run <code>echo \"hello\"</code> now.</p>")
        XCTAssertTrue(result.contains("\"hello\""),
                      "Straight quotes in inline code must not be replaced in: \(result)")
    }
}
