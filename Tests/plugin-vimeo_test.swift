import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(VimeoEmbedPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class VimeoEmbedPluginTests: XCTestCase {

    func testBasicVimeoEmbed() throws {
        let html = "<iframe src=\"https://player.vimeo.com/video/123456789\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("[Vimeo Video](https://vimeo.com/123456789)"), "Expected Vimeo link in: \(result)")
    }

    func testVimeoEmbedWithTitle() throws {
        let html = "<iframe src=\"https://player.vimeo.com/video/148751763\" title=\"Big Buck Bunny\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("[Big Buck Bunny](https://vimeo.com/148751763)"), "Expected titled Vimeo link in: \(result)")
    }

    func testVimeoEmbedWithQueryParams() throws {
        let html = "<iframe src=\"https://player.vimeo.com/video/123456789?h=abc&autopause=0\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("vimeo.com/123456789"), "Expected correct Vimeo ID in: \(result)")
    }

    func testNonVimeoIframePassthrough() throws {
        let html = "<iframe src=\"https://example.com/embed/1\"></iframe>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("vimeo.com"), "Should not produce a Vimeo link for: \(result)")
    }

    func testVimeoProtocolRelativeURL() throws {
        let html = "<iframe src=\"//player.vimeo.com/video/999\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("vimeo.com/999"), "Expected Vimeo ID 999 in: \(result)")
    }

    func testVimeoEmbedBlockLevel() throws {
        let html = "<p><iframe src=\"https://player.vimeo.com/video/111222333\" title=\"Test Video\"></iframe></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("[Test Video](https://vimeo.com/111222333)"), "Expected Vimeo link in block context: \(result)")
    }
}
