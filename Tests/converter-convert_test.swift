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

class ConverterConvertTests: XCTestCase {

    func testEmptyHTML() throws {
        let result = try convert("")
        XCTAssertEqual(result, "")
    }

    func testMixedContent() throws {
        let html = "<h1>Title</h1><p>This is <strong>bold</strong> and <em>italic</em>.</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("# Title"))
        XCTAssertTrue(result.contains("**bold**"))
        XCTAssertTrue(result.contains("*italic*"))
    }

    func testConvertData() throws {
        let html = "<strong>Bold</strong>"
        let data = html.data(using: .utf8)!
        let result = try HTMLToMarkdown.convert(data: data)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(result, "**Bold**")
    }

    func testLargeHTML() throws {
        var html = ""
        for i in 1...100 {
            html += "<p>Paragraph \(i)</p>"
        }
        let startTime = Date()
        let result = try convert(html)
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertTrue(duration < 5.0, "Conversion took too long: \(duration)s")
        XCTAssertTrue(result.contains("Paragraph 1"))
        XCTAssertTrue(result.contains("Paragraph 100"))
    }

    // Mirrors Go: TestConvertString_ErrNoRenderHandlers
    func testConvertString_ErrNoRenderHandlers() throws {
        let conv = Converter(plugins: [], options: [])
        XCTAssertThrowsError(try conv.convertString("<strong>bold text</strong>")) { err in
            XCTAssertTrue(
                err.localizedDescription.contains("no render handlers are registered"),
                "expected 'no render handlers' error but got: \(err)"
            )
        }
    }

    // Mirrors Go: TestConvertString_ErrBasePluginMissing
    func testConvertString_ErrBasePluginMissing() throws {
        XCTAssertThrowsError(
            try HTMLToMarkdown.convert("<strong>bold text</strong>", plugins: [CommonmarkPlugin()])
        ) { err in
            XCTAssertTrue(
                err.localizedDescription.contains("base"),
                "expected 'base plugin required' error but got: \(err)"
            )
        }
    }

    // Mirrors Go: TestWithEscapeMode (simplified — tests observable effect of escape mode)
    func testWithEscapeMode() throws {
        let html = "<p>hello*world</p>"

        let smartResult = try HTMLToMarkdown.convert(
            html,
            plugins: [BasePlugin(), CommonmarkPlugin()],
            options: [.escapeMode(.smart)]
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let disabledResult = try HTMLToMarkdown.convert(
            html,
            plugins: [BasePlugin(), CommonmarkPlugin()],
            options: [.escapeMode(.disabled)]
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertNotEqual(smartResult, disabledResult, "smart and disabled modes should produce different output")
        XCTAssertTrue(disabledResult.contains("*"), "disabled mode should not escape *")
        XCTAssertFalse(disabledResult.contains("\\*"), "disabled mode should not add backslash escape")
    }
}
