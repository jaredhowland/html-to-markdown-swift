import XCTest
@testable import HTMLToMarkdown

private func makeConverter(inline: Bool = false) throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(ReferenceLinkPlugin(inlineLinks: inline))
    return conv
}

private func convert(_ html: String, inline: Bool = false) throws -> String {
    let conv = try makeConverter(inline: inline)
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class ReferenceLinkPluginTests: XCTestCase {

    func testBasicReferenceLink() throws {
        let result = try convert("<p><a href=\"https://example.com\">Visit here</a></p>")
        XCTAssertTrue(result.contains("[Visit here][1]"), "Expected reference inline in: \(result)")
        XCTAssertTrue(result.contains("[1]: https://example.com"), "Expected reference def in: \(result)")
        XCTAssertFalse(result.contains("[Visit here](https://example.com)"), "Should not be inline: \(result)")
    }

    func testLinkWithTitle() throws {
        let result = try convert("<p><a href=\"https://example.com\" title=\"Example Site\">Visit</a></p>")
        XCTAssertTrue(result.contains("[Visit][1]"), "Expected reference inline in: \(result)")
        XCTAssertTrue(result.contains("[1]: https://example.com \"Example Site\""), "Expected title in ref def: \(result)")
    }

    func testReferenceAtBottomAfterContent() throws {
        let result = try convert("<p><a href=\"https://a.com\">A</a></p><p>Some text.</p>")
        let linkDefRange = result.range(of: "[1]: https://a.com")!
        let textRange = result.range(of: "Some text.")!
        XCTAssertTrue(linkDefRange.lowerBound > textRange.lowerBound, "Ref def must be after body text in: \(result)")
    }

    func testDeduplication() throws {
        let result = try convert("<p><a href=\"https://example.com\">First</a> and <a href=\"https://example.com\">Second</a></p>")
        XCTAssertTrue(result.contains("[First][1]"), "First link: \(result)")
        XCTAssertTrue(result.contains("[Second][1]"), "Second link (same URL): \(result)")
        let count = result.components(separatedBy: "[1]: https://example.com").count - 1
        XCTAssertEqual(count, 1, "Should have exactly one definition: \(result)")
    }

    func testMultipleLinksNumbered() throws {
        let result = try convert("<p><a href=\"https://a.com\">A</a> and <a href=\"https://b.com\">B</a></p>")
        XCTAssertTrue(result.contains("[A][1]"), "First link: \(result)")
        XCTAssertTrue(result.contains("[B][2]"), "Second link: \(result)")
        XCTAssertTrue(result.contains("[1]: https://a.com"), "First def: \(result)")
        XCTAssertTrue(result.contains("[2]: https://b.com"), "Second def: \(result)")
    }

    func testImageReferenceStyle() throws {
        let result = try convert("<p><img src=\"https://example.com/img.png\" alt=\"My Image\"></p>")
        XCTAssertTrue(result.contains("![My Image][1]"), "Expected image ref syntax in: \(result)")
        XCTAssertTrue(result.contains("[1]: https://example.com/img.png"), "Expected image ref def in: \(result)")
    }

    func testInlineLinkOption() throws {
        let result = try convert("<p><a href=\"https://example.com\">Visit</a></p>", inline: true)
        XCTAssertTrue(result.contains("[Visit](https://example.com)"), "Expected inline link: \(result)")
        XCTAssertFalse(result.contains("[1]:"), "Should not have ref defs when inline: \(result)")
    }

    func testEmptyHrefPassthrough() throws {
        // Empty href links should NOT generate ref numbers — let CommonmarkPlugin handle them
        let result = try convert("<p><a href=\"\">Empty href</a></p>")
        XCTAssertFalse(result.contains("[1]:"), "Empty href should not generate ref number: \(result)")
    }

    func testBlankLineSeparation() throws {
        let result = try convert("<p>Text. <a href=\"https://example.com\">Link</a></p>")
        guard let range = result.range(of: "\n\n[1]:") else {
            XCTFail("Expected exactly one blank line before ref block, got: \(result)")
            return
        }
        // The content before the blank line should not end with another newline (no double blank line)
        let before = String(result[result.startIndex..<range.lowerBound])
        XCTAssertFalse(before.hasSuffix("\n"), "Should be exactly one blank line (not two): \(result)")
    }

    func testEmptyTitleOmitted() throws {
        let result = try convert("<p><a href=\"https://example.com\">Link</a></p>")
        // Should have [1]: url with no trailing title or empty quotes
        if let range = result.range(of: "[1]: https://example.com") {
            let after = String(result[range.upperBound...]).trimmingCharacters(in: .init(charactersIn: "\n"))
            // After the definition, there should be no "\"\"" or "''" suffix on that line
            let defLine = "[1]: https://example.com"
            XCTAssertFalse(result.contains(defLine + " \"\""), "Should not have empty double quotes in: \(result)")
            XCTAssertFalse(result.contains(defLine + " ''"), "Should not have empty single quotes in: \(result)")
        } else {
            XCTFail("No reference definition found in: \(result)")
        }
    }

    func testDeduplicationFirstTitleWins() throws {
        // When same URL appears with different titles, first-encountered title is used
        let result = try convert("<p><a href=\"https://example.com\" title=\"First Title\">Link1</a> and <a href=\"https://example.com\" title=\"Second Title\">Link2</a></p>")
        XCTAssertTrue(result.contains("[Link1][1]"), "First link: \(result)")
        XCTAssertTrue(result.contains("[Link2][1]"), "Second link (same URL): \(result)")
        XCTAssertTrue(result.contains("[1]: https://example.com \"First Title\""), "First title wins: \(result)")
        XCTAssertFalse(result.contains("Second Title"), "Second title should not appear: \(result)")
    }

    func testEmojiImagePassthrough() throws {
        // img with class="emoji" should NOT get reference-style treatment
        let result = try convert("<p><img class=\"emoji\" src=\"https://github.githubassets.com/images/icons/emoji/unicode/1f600.png\" alt=\":grinning:\"></p>")
        // Should not have [1]: definition
        XCTAssertFalse(result.contains("[1]:"), "Emoji img should not generate ref def: \(result)")
        // Should have inline image syntax from CommonmarkPlugin fallthrough
        XCTAssertTrue(result.contains("![:grinning:]"), "Expected emoji alt text in: \(result)")
    }
}
