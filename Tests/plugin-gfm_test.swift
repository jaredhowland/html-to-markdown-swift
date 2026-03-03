import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(GFMPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html)
}

class GFMPluginTests: XCTestCase {

    // MARK: - Task list items

    func testTaskListItemChecked() throws {
        let html = "<ul><li><input type=\"checkbox\" checked> Done</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("- [x] Done"), "Expected '- [x] Done' in: \(result)")
    }

    func testTaskListItemUnchecked() throws {
        let html = "<ul><li><input type=\"checkbox\"> Todo</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("- [ ] Todo"), "Expected '- [ ] Todo' in: \(result)")
    }

    func testTaskListMixed() throws {
        let html = """
        <ul>
            <li><input type="checkbox" checked> Done</li>
            <li><input type="checkbox"> Todo</li>
        </ul>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("- [x] Done"), "Expected '- [x] Done' in: \(result)")
        XCTAssertTrue(result.contains("- [ ] Todo"), "Expected '- [ ] Todo' in: \(result)")
    }

    func testTaskListNoDoubleSpace() throws {
        let html = "<ul><li><input type=\"checkbox\" checked> Text</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("- [x] Text"), "Expected '- [x] Text' (no double space) in: \(result)")
        XCTAssertFalse(result.contains("[x]  Text"), "Must not have double space after checkbox marker")
    }

    // MARK: - Definition lists

    func testDefinitionList() throws {
        let html = "<dl><dt>Term</dt><dd>Definition</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("**Term**"), "Expected '**Term**' in: \(result)")
        XCTAssertTrue(result.contains(": Definition"), "Expected ': Definition' in: \(result)")
    }

    func testDefinitionListMultipleTerms() throws {
        let html = "<dl><dt>Alpha</dt><dd>First</dd><dt>Beta</dt><dd>Second</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("**Alpha**"), "Expected '**Alpha**' in: \(result)")
        XCTAssertTrue(result.contains(": First"), "Expected ': First' in: \(result)")
        XCTAssertTrue(result.contains("**Beta**"), "Expected '**Beta**' in: \(result)")
        XCTAssertTrue(result.contains(": Second"), "Expected ': Second' in: \(result)")
    }

    // MARK: - Details / Summary

    func testDetailsWithSummary() throws {
        let html = "<details><summary>Title</summary><p>Content</p></details>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("**Title**"), "Expected '**Title**' in: \(result)")
        XCTAssertTrue(result.contains("Content"), "Expected 'Content' in: \(result)")
        let titleRange = result.range(of: "**Title**")!
        let contentRange = result.range(of: "Content")!
        XCTAssertTrue(titleRange.lowerBound < contentRange.lowerBound, "Title must appear before Content")
    }

    // MARK: - Subscript / Superscript

    func testSub() throws {
        let html = "<p>H<sub>2</sub>O</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("H<sub>2</sub>O"), "Expected 'H<sub>2</sub>O' in: \(result)")
    }

    func testSup() throws {
        let html = "<p>E=mc<sup>2</sup></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("E=mc<sup>2</sup>"), "Expected 'E=mc<sup>2</sup>' in: \(result)")
    }

    // MARK: - Abbreviations

    func testAbbrWithTitle() throws {
        let html = "<abbr title=\"HyperText Markup Language\">HTML</abbr>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("HTML (HyperText Markup Language)"),
                      "Expected 'HTML (HyperText Markup Language)' in: \(result)")
    }

    func testAbbrWithoutTitle() throws {
        let html = "<abbr>HTML</abbr>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("HTML"), "Expected 'HTML' in: \(result)")
        XCTAssertFalse(result.contains("("), "Must not have parentheses when no title")
    }

    // MARK: - Bundled plugins

    func testStrikethroughBundled() throws {
        let html = "<del>text</del>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("~~text~~"), "Expected '~~text~~' in: \(result)")
    }

    func testTableBundled() throws {
        let html = """
        <table>
            <thead><tr><th>Name</th><th>Age</th></tr></thead>
            <tbody><tr><td>Alice</td><td>30</td></tr></tbody>
        </table>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("| Name"), "Expected table header in: \(result)")
        XCTAssertTrue(result.contains("| Alice"), "Expected table row in: \(result)")
        XCTAssertTrue(result.contains("---"), "Expected table separator in: \(result)")
    }
}
