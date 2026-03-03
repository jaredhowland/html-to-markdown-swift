import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(MarkdownExtraPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class MarkdownExtraPluginTests: XCTestCase {

    // MARK: - Definition Lists

    func testDefinitionListMEFormat() throws {
        let html = "<dl><dt>Apple</dt><dd>A fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Apple"), "Expected term in: \(result)")
        XCTAssertTrue(result.contains(":   A fruit"), "Expected ME definition format in: \(result)")
    }

    func testDefinitionListNotBold() throws {
        let html = "<dl><dt>Apple</dt><dd>A fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("**Apple**"), "Term must NOT be bold in ME format: \(result)")
    }

    func testMultipleDefinitions() throws {
        let html = "<dl><dt>Apple</dt><dd>Fruit</dd><dt>Orange</dt><dd>Citrus fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Apple"), "Expected Apple in: \(result)")
        XCTAssertTrue(result.contains("Orange"), "Expected Orange in: \(result)")
        XCTAssertTrue(result.contains(":   Fruit"), "Expected Fruit definition in: \(result)")
        XCTAssertTrue(result.contains(":   Citrus fruit"), "Expected Orange definition in: \(result)")
    }
}
