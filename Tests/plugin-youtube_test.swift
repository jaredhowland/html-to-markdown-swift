import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(YouTubeEmbedPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class YouTubeEmbedPluginTests: XCTestCase {

    func testBasicYouTubeEmbed() throws {
        let html = "<iframe src=\"https://www.youtube.com/embed/dQw4w9WgXcQ\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("dQw4w9WgXcQ"), "Expected video ID in: \(result)")
        XCTAssertTrue(result.contains("youtube.com"), "Expected youtube.com in: \(result)")
    }

    func testYouTubeEmbedWithTitle() throws {
        let html = "<iframe src=\"https://www.youtube.com/embed/dQw4w9WgXcQ\" title=\"Never Gonna Give You Up\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Never Gonna Give You Up"), "Expected title in image alt in: \(result)")
        XCTAssertTrue(result.contains("dQw4w9WgXcQ"), "Expected video ID in: \(result)")
    }

    func testYouTubeNocookieDomain() throws {
        let html = "<iframe src=\"https://www.youtube-nocookie.com/embed/abc123\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("abc123"), "Expected video ID in: \(result)")
        XCTAssertTrue(result.contains("youtube.com"), "Expected youtube.com in: \(result)")
    }

    func testYouTubeProtocolRelative() throws {
        let html = "<iframe src=\"//www.youtube.com/embed/xyz789\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("xyz789"), "Expected video ID in: \(result)")
    }

    func testNonYouTubeIframePassthrough() throws {
        let html = "<iframe src=\"https://vimeo.com/video/123\"></iframe>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("img.youtube.com"), "Should not produce YouTube thumbnail for: \(result)")
        XCTAssertFalse(result.contains("youtube.com/watch"), "Should not produce YouTube watch link for: \(result)")
    }

    func testThumbnailURLFormat() throws {
        let html = "<iframe src=\"https://www.youtube.com/embed/dQw4w9WgXcQ\"></iframe>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("img.youtube.com/vi/dQw4w9WgXcQ/0.jpg"), "Expected thumbnail URL in: \(result)")
    }
}
