import XCTest
@testable import HTMLToMarkdown

private func makeConverter(style: EmojiOutputStyle = .shortcode) throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(EmojiPlugin(outputStyle: style))
    return conv
}

private func convert(_ html: String, style: EmojiOutputStyle = .shortcode) throws -> String {
    let conv = try makeConverter(style: style)
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class EmojiPluginTests: XCTestCase {


    func testEmojiImgToShortcode() throws {
        let html = "<p>Hello <img class=\"emoji\" src=\"https://github.githubassets.com/images/icons/emoji/unicode/1f600.png\" alt=\":grinning:\"> world</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains(":grinning:"), "Expected shortcode in: \(result)")
        XCTAssertFalse(result.contains("<img"), "Should not have raw img tag: \(result)")
    }

    func testEmojiImgToUnicode() throws {
        let html = "<p>Hello <img class=\"emoji\" src=\"https://github.githubassets.com/images/icons/emoji/unicode/1f600.png\" alt=\":grinning:\"> world</p>"
        let result = try convert(html, style: .unicode)
        XCTAssertTrue(result.contains("😀"), "Expected unicode emoji in: \(result)")
        XCTAssertFalse(result.contains(":grinning:"), "Should not have shortcode in unicode mode: \(result)")
    }

    func testNonEmojiImgUnaffected() throws {
        let html = "<p><img src=\"photo.jpg\" alt=\"A photo\"></p>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("<img"), "Non-emoji img should not have raw tag: \(result)")
        XCTAssertTrue(result.contains("A photo"), "Alt text should be preserved: \(result)")
    }

    func testUnicodeEmojiToShortcode() throws {
        let html = "<p>I love 😄 this</p>"
        let result = try convert(html)
        // 😄 is U+1F604, shortcode is "smile"
        XCTAssertTrue(result.contains(":smile:"), "Expected :smile: in: \(result)")
        XCTAssertFalse(result.contains("😄"), "Unicode should be converted in shortcode mode: \(result)")
    }

    func testUnicodeEmojiPassthroughInUnicodeMode() throws {
        let html = "<p>I love 😄 this</p>"
        let result = try convert(html, style: .unicode)
        XCTAssertTrue(result.contains("😄"), "Unicode emoji should pass through in unicode mode: \(result)")
    }

    func testShortcodeLookupValid() throws {
        XCTAssertNotNil(emojiShortcodes["smile"], "smile should be in table")
        XCTAssertNotNil(emojiShortcodes["heart"], "heart should be in table")
        XCTAssertNotNil(emojiShortcodes["+1"], "+1 should be in table")
    }

    func testEmojiInCodeBlockUnaffected() throws {
        let html = "<pre><code>var emoji = \"😄\"</code></pre>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("😄"), "Emoji in code block should NOT be converted: \(result)")
        XCTAssertFalse(result.contains(":smile:"), "Should not convert in code block: \(result)")
    }

    func testMultipleEmoji() throws {
        let html = "<p>❤️ and 🎉</p>"
        let result = try convert(html)
        let colonCount = result.filter { $0 == ":" }.count
        XCTAssertGreaterThanOrEqual(colonCount, 4, "Expected at least 2 shortcodes (4 colons) in: \(result)")
    }
}
