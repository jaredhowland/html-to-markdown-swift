import XCTest
@testable import HTMLToMarkdown

private func convert(_ html: String, smartQuotes: Bool = true, replacements: Bool = true,
                     linkify: Bool = true, quoteStyle: QuoteStyle = .english) throws -> String {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(TypographyPlugin(smartQuotes: smartQuotes,
                                              replacements: replacements,
                                              linkify: linkify,
                                              quoteStyle: quoteStyle))
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class TypographyPluginTests: XCTestCase {

    func testAllFeaturesEnabled() throws {
        let html = "<p>She said \"hello\" -- visit https://example.com (c) 2024</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("\u{201C}hello\u{201D}"), "Expected smart quotes in: \(result)")
        XCTAssertTrue(result.contains("\u{2013}"), "Expected en dash in: \(result)")
        XCTAssertTrue(result.contains("[https://example.com](https://example.com)"), "Expected linkified URL in: \(result)")
        XCTAssertTrue(result.contains("©"), "Expected copyright symbol in: \(result)")
    }

    func testSmartQuotesDisabled() throws {
        let result = try convert("<p>She said \"hello\"</p>", smartQuotes: false)
        XCTAssertTrue(result.contains("\"hello\""), "Straight quotes should remain when disabled: \(result)")
        XCTAssertFalse(result.contains("\u{201C}"), "Should not have curly quotes when disabled: \(result)")
    }

    func testReplacementsDisabled() throws {
        let result = try convert("<p>(c) 2024</p>", replacements: false)
        XCTAssertFalse(result.contains("©"), "Should not replace when disabled: \(result)")
    }

    func testLinkifyDisabled() throws {
        let result = try convert("<p>Visit https://example.com today.</p>", linkify: false)
        XCTAssertFalse(result.contains("](https://"), "Should not linkify when disabled: \(result)")
        XCTAssertTrue(result.contains("https://example.com"), "URL text should remain: \(result)")
    }

    func testGermanQuoteStyle() throws {
        let result = try convert("<p>Er sagte \"Hallo\".</p>", quoteStyle: .german)
        XCTAssertTrue(result.contains("\u{201E}") && result.contains("\u{201C}"),
                      "Expected German quote characters in: \(result)")
    }
}
