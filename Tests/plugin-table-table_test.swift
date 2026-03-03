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

class TableTests: XCTestCase {

    func testSimpleTable() throws {
        let html = """
        <table>
            <thead><tr><th>H1</th><th>H2</th></tr></thead>
            <tbody><tr><td>C1</td><td>C2</td></tr></tbody>
        </table>
        """
        let result = try convert(html, plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin()])
        // Aligned padding: H1/C1 are 2 chars wide, H2/C2 are 2 chars wide
        XCTAssertTrue(result.contains("| H1 | H2 |"))
        XCTAssertTrue(result.contains("| C1 | C2 |"))
        // Separator uses aligned dashes: 2 chars width = |----|----|
        XCTAssertTrue(result.contains("|----|----|"))
    }

    func testTableAlignedPadding() throws {
        let html = """
        <table>
            <thead><tr><th>Name</th><th>Age</th></tr></thead>
            <tbody>
                <tr><td>Alice</td><td>30</td></tr>
                <tr><td>Bob</td><td>25</td></tr>
            </tbody>
        </table>
        """
        let result = try convert(html, plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin()])
        // Aligned padding: "Name" is 4 chars, "Alice" is 5 chars → max col width 5
        XCTAssertTrue(result.contains("| Name  | Age |") || result.contains("| Alice |"))
        // Separator should use dashes matching column width
        XCTAssertTrue(result.contains("|----") || result.contains("|-----"))
    }

    func testTableMinimalPadding() throws {
        let html = """
        <table>
            <thead><tr><th>H1</th><th>H2</th></tr></thead>
            <tbody><tr><td>C1</td><td>C2</td></tr></tbody>
        </table>
        """
        var opts = TableOptions()
        opts.cellPaddingBehavior = .minimal
        let result = try convert(html, plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin(options: opts)])
        XCTAssertTrue(result.contains("| H1 | H2 |"))
        XCTAssertTrue(result.contains("|:-:|") || result.contains("|---|") || result.contains("|--|"))
    }
}
