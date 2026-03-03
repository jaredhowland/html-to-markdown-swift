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

    // Mirrors Go: TestNewCommonmarkPlugin_Italic (table-driven)
    func testNewCommonmarkPlugin_Italic() throws {
        let nonBreakingSpace = "\u{00A0}"
        let zeroWidthSpace = "\u{200B}"

        let runs: [(desc: String, input: String, expected: String)] = [
            ("simple", "<p><em>Text</em></p>", "*Text*"),
            ("normal text surrounded by italic", "<em>Italic</em>Normal<em>Italic</em>", "*Italic*Normal*Italic*"),
            ("italic text surrounded by normal", "Normal<em>Italic</em>Normal", "Normal*Italic*Normal"),
            ("with spaces inside", "<p><em>  Text  </em></p>", "*Text*"),
            ("with delimiter inside", "<p><em>*A*B*</em></p>", #"*\*A\*B\**"#),
            ("adjacent", "<em>A</em><em>B</em> <em>C</em>", "*AB* *C*"),
            ("adjacent and lots of spaces", "<em>  A  </em><em>  B  </em>  <em>  C  </em>", "*A B* *C*"),
            ("nested", "<em>A <em>B</em> C</em>", "*A B C*"),
            ("nested and lots of spaces", "<em>  A  <em>  B  </em>  C  </em>", "*A B C*"),
            ("mixed nested 1", "<em>A <strong>B</strong> C</em>", "*A **B** C*"),
            ("mixed nested 2", "<strong>A <em>B</em> C</strong>", "**A *B* C**"),
            ("mixed different italic", "<i>A<em>B</em>C</i>", "*ABC*"),
            ("next to each other in other containers",
             "<div>\n\t<em>A</em>\n\t<article><em>B</em></article>\n\t<em>C</em>\n</div>",
             "*A*\n\n*B*\n\n*C*"),
            ("empty italic #1", "before<i></i>after", "beforeafter"),
            ("empty italic #2", "before<i> </i>after", "before after"),
            ("empty italic #3", "before <i> </i> after", "before after"),
            ("italic with non-breaking-space", "before<i>\(nonBreakingSpace)</i>after", "before\(nonBreakingSpace)after"),
            ("italic with zero-width-space", "before<i>\(zeroWidthSpace)</i>after", "before*\(zeroWidthSpace)*after"),
        ]

        for run in runs {
            let result = try HTMLToMarkdown.convert(
                run.input,
                plugins: [BasePlugin(), CommonmarkPlugin()]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(result, run.expected, "[\(run.desc)]")
        }
    }
}
