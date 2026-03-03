import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(ReplacementsPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class ReplacementsPluginTests: XCTestCase {

    func testCopyright() throws {
        let result = try convert("<p>(c) 2024 Acme Corp</p>")
        XCTAssertTrue(result.contains("© 2024 Acme Corp"), "Expected © in: \(result)")
    }

    func testCopyrightUppercase() throws {
        let result = try convert("<p>(C) 2024</p>")
        XCTAssertTrue(result.contains("© 2024"), "Expected © in: \(result)")
    }

    func testRegistered() throws {
        let result = try convert("<p>Acme(r) brand</p>")
        XCTAssertTrue(result.contains("Acme® brand"), "Expected ® in: \(result)")
    }

    func testTrademark() throws {
        let result = try convert("<p>Acme(tm) product</p>")
        XCTAssertTrue(result.contains("Acme™ product"), "Expected ™ in: \(result)")
    }

    func testTrademarkUppercase() throws {
        let result = try convert("<p>Acme(TM)</p>")
        XCTAssertTrue(result.contains("Acme™"), "Expected ™ in: \(result)")
    }

    func testEllipsis() throws {
        let result = try convert("<p>Wait...</p>")
        XCTAssertTrue(result.contains("Wait…"), "Expected … in: \(result)")
    }

    func testEmDash() throws {
        let result = try convert("<p>word---word</p>")
        XCTAssertTrue(result.contains("word\u{2014}word"), "Expected em dash in: \(result)")
    }

    func testEnDash() throws {
        let result = try convert("<p>2020--2024</p>")
        XCTAssertTrue(result.contains("2020\u{2013}2024"), "Expected en dash in: \(result)")
    }

    func testPlusMinus() throws {
        let result = try convert("<p>Temperature: 37+-0.5 degrees</p>")
        XCTAssertTrue(result.contains("37±0.5"), "Expected ± in: \(result)")
    }

    func testHorizontalRulePreserved() throws {
        // Standalone --- should NOT be converted to em dash
        let result = try convert("<hr>")
        XCTAssertFalse(result.contains("—"), "Horizontal rule should not become em dash: \(result)")
    }

    func testEmDashInProse() throws {
        let result = try convert("<p>The result---unexpected---was good.</p>")
        XCTAssertTrue(result.contains("result\u{2014}unexpected\u{2014}was"),
                      "Em dashes between words should work: \(result)")
    }

    func testCodeBlockUntouched() throws {
        let result = try convert("<pre><code>(c) 2024 -- not replaced</code></pre>")
        XCTAssertTrue(result.contains("(c) 2024 -- not replaced"),
                      "Code block content must not be replaced in: \(result)")
        XCTAssertFalse(result.contains("©"), "Should not replace in code block: \(result)")
    }

    func testInlineCodeUntouched() throws {
        let result = try convert("<p>Use <code>(c)</code> in code</p>")
        XCTAssertTrue(result.contains("`(c)`"), "Inline code must not be replaced in: \(result)")
        XCTAssertFalse(result.contains("©"), "Should not replace in inline code: \(result)")
    }
}
