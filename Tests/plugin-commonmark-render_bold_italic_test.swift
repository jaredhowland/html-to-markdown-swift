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

class CommonmarkBoldItalicTests: XCTestCase {

    func testBold() throws {
        XCTAssertEqual(try convert("<strong>Bold</strong>"), "**Bold**")
    }

    func testBoldTag() throws {
        XCTAssertEqual(try convert("<b>Bold</b>"), "**Bold**")
    }

    func testItalic() throws {
        XCTAssertEqual(try convert("<em>Italic</em>"), "*Italic*")
    }

    func testItalicTag() throws {
        XCTAssertEqual(try convert("<i>Italic</i>"), "*Italic*")
    }

    func testCustomStrongDelimiter() throws {
        var opts = CommonmarkOptions()
        opts.strongDelimiter = "__"
        XCTAssertEqual(try convertPlugins("<strong>Bold</strong>", options: opts), "__Bold__")
    }

    func testCustomEmDelimiter() throws {
        var opts = CommonmarkOptions()
        opts.emDelimiter = "_"
        XCTAssertEqual(try convertPlugins("<em>Italic</em>", options: opts), "_Italic_")
    }

    func testEmptyBold() throws {
        XCTAssertEqual(try convert("<strong></strong>"), "")
    }

    func testEmptyBoldInParagraph() throws {
        // Empty bold in paragraph context: surrounding spaces collapse to one
        XCTAssertEqual(try convert("<p>some <strong></strong> text</p>"), "some text")
    }

    func testEmptyBoldWhitespace() throws {
        // Bold with only whitespace content: behaves same as empty, surrounding spaces collapse
        XCTAssertEqual(try convert("<p>some <strong> </strong> text</p>"), "some text")
    }

    func testEmptyItalic() throws {
        XCTAssertEqual(try convert("<em></em>"), "")
    }

    func testEmptyItalicInParagraph() throws {
        // Empty italic in paragraph context: surrounding spaces collapse to one
        XCTAssertEqual(try convert("<p>some <em></em> text</p>"), "some text")
    }

    func testAdjacentBoldMerges() throws {
        // Go: **bold onebold two** - adjacent bold elements without space between
        let result = try convert("<strong>bold one</strong><strong>bold two</strong>")
        XCTAssertEqual(result, "**bold onebold two**")
    }

    func testNestedBoldItalicProducesCombined() throws {
        // Go: ***hello***
        let result = try convert("<p><b><b><i><b>hello</b></i></b></b></p>")
        XCTAssertEqual(result, "***hello***")
    }

    func testAdjacentBoldMergesThroughSpan() throws {
        XCTAssertEqual(try convert("<p><strong>a</strong><span><strong>b</strong></span></p>"), "**ab**")
    }

    func testAdjacentBoldSpaceInSpanStopsMerge() throws {
        XCTAssertEqual(try convert("<p><strong>a</strong><span> <strong>b</strong></span></p>"), "**a** **b**")
    }

    func testBoldWrappingLink() throws {
        XCTAssertEqual(try convert("<p>before<b><a href=\"/\">middle</a></b>after</p>"), "before[**middle**](/)after")
    }

    func testItalicWrappingLink() throws {
        XCTAssertEqual(try convert("<p><em><a href=\"/page\">text</a></em></p>"), "[*text*](/page)")
    }

    func testStrongWrappingLink() throws {
        XCTAssertEqual(try convert("<strong><a href=\"/\">bold link</a></strong>"), "[**bold link**](/)")
    }

    func testEmphasisPreservesLeadingSpace() throws {
        // Go: before *.middle* after — surrounding spaces are outside delimiters
        let result = try convert("<p>before<em> .middle </em>after</p>")
        XCTAssertEqual(result, "before *.middle* after")
    }

    func testBoldPreservesLeadingSpace() throws {
        let result = try convert("<p>before<strong> middle </strong>after</p>")
        XCTAssertEqual(result, "before **middle** after")
    }
}
