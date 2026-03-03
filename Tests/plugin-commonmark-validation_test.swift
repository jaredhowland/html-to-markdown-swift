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

class CommonmarkValidationTests: XCTestCase {

    func testValidationErrorEmDelimiter() throws {
        var opts = CommonmarkOptions()
        opts.emDelimiter = "x"
        XCTAssertThrowsError(try convertPlugins("<em>text</em>", options: opts))
    }

    func testValidationErrorStrongDelimiter() throws {
        var opts = CommonmarkOptions()
        opts.strongDelimiter = "xx"
        XCTAssertThrowsError(try convertPlugins("<strong>text</strong>", options: opts))
    }

    func testValidationErrorBulletMarker() throws {
        var opts = CommonmarkOptions()
        opts.bulletListMarker = "x"
        XCTAssertThrowsError(try convertPlugins("<ul><li>item</li></ul>", options: opts))
    }
}
