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

class ConverterURLTests: XCTestCase {

    func testLinkWithNewlineInHref() throws {
        // Newlines in href should be stripped
        let result = try convert("<a href=\"/page\n\">broken link</a>")
        XCTAssertEqual(result, "[broken link](/page)")
    }

    func testLinkWithSpaceInHref() throws {
        let result = try convert("<a href=\"http://Open Demo\">with space inside</a>")
        XCTAssertEqual(result, "[with space inside](http://Open%20Demo)")
    }

    func testLinkWithWhitespaceAroundHref() throws {
        let result = try convert("<a href=\"  example.com  \">with whitespace around</a>")
        XCTAssertEqual(result, "[with whitespace around](example.com)")
    }

    func testURLNewlineInMiddleEncoded() throws {
        // Go encodes \n as %0A (not strips) when in the middle of a URL
        let result = try convert("<a href=\"/page\n\n.html\">broken link</a>")
        XCTAssertEqual(result, "[broken link](/page%0A%0A.html)")
    }

    func testURLTabEncoded() throws {
        // Go encodes \t as %09
        let result = try convert("<a href=\"/path\there\">link</a>")
        XCTAssertEqual(result, "[link](/path%09here)")
    }

    func testURLBracketsEncoded() throws {
        // Go encodes [ and ] in URLs as %5B and %5D
        let result = try convert("<a href=\"/url[with]brackets\">link</a>")
        XCTAssertEqual(result, "[link](/url%5Bwith%5Dbrackets)")
    }

    func testURLHashPassthrough() throws {
        // Go returns "#" as-is (special case to avoid fragment confusion)
        let result = try convert("<a href=\"#\">fragment</a>")
        XCTAssertEqual(result, "[fragment](#)")
    }
}
