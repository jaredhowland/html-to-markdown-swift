import XCTest
@testable import HTMLToMarkdown
import SwiftSoup

class GoldenFileTests: XCTestCase {

    private func runGoldenFile(inputPath: String, expectedPath: String, plugins: [Plugin],
                                options: [ConverterOption] = [], description: String) {
        guard let input = try? String(contentsOfFile: inputPath, encoding: .utf8),
              let expected = try? String(contentsOfFile: expectedPath, encoding: .utf8) else {
            XCTFail("Could not read golden files: \(inputPath)")
            return
        }

        let result: String
        do {
            result = try HTMLToMarkdown.convert(input, plugins: plugins, options: options)
        } catch {
            XCTFail("Conversion error for \(description): \(error)")
            return
        }

        let trimResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimExpected = expected.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimResult != trimExpected {
            print("\n=== DIFF for \(description) ===")
            let resultLines = trimResult.components(separatedBy: "\n")
            let expectedLines = trimExpected.components(separatedBy: "\n")
            let maxLines = max(resultLines.count, expectedLines.count)
            for i in 0..<maxLines {
                let r = i < resultLines.count ? resultLines[i] : "<MISSING>"
                let e = i < expectedLines.count ? expectedLines[i] : "<MISSING>"
                if r != e {
                    print("Line \(i+1):")
                    print("  Expected: \(e.debugDescription)")
                    print("  Got:      \(r.debugDescription)")
                }
            }
        }

        XCTAssertEqual(trimResult, trimExpected, "Golden file mismatch: \(description)")
    }

    // The Go golden file tests for commonmark render HTML comments as block HTML.
    // This matches Go's: conv.Register.RendererFor("#comment", converter.TagTypeBlock, base.RenderAsHTML, converter.PriorityEarly)
    private var commonmarkOptions: [ConverterOption] {
        return [.customRenderers([("#comment", { node, conv in
            return try RenderAsHTML(node, conv)
        })])]
    }

    private let goldenBase = "/Users/wgu/Code/xcode/html-to-markdown/html-to-markdown-main"

    func testCommonmarkBlockquote() {
        let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/blockquote"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin()],
                      options: commonmarkOptions,
                      description: "commonmark/blockquote")
    }

    func testCommonmarkBold() {
        let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/bold"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin()],
                      options: commonmarkOptions,
                      description: "commonmark/bold")
    }

    func testCommonmarkCode() {
        let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/code"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin()],
                      options: commonmarkOptions,
                      description: "commonmark/code")
    }

    func testCommonmarkHeading() {
        let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/heading"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin()],
                      options: commonmarkOptions,
                      description: "commonmark/heading")
    }

    func testCommonmarkImage() {
        let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/image"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin()],
                      options: commonmarkOptions,
                      description: "commonmark/image")
    }
    func testCommonmarkLink() {
        let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/link"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin()],
                      options: commonmarkOptions,
                      description: "commonmark/link")
    }

    func testCommonmarkList() {
        let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/list"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin()],
                      options: commonmarkOptions,
                      description: "commonmark/list")
    }

    func testCommonmarkMetadata() {
        let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/metadata"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin()],
                      options: commonmarkOptions,
                      description: "commonmark/metadata")
    }

    func testTableBasics() {
        let base = "\(goldenBase)/plugin/table/testdata/GoldenFiles/basics"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin()],
                      description: "table/basics")
    }

    func testTableColRowSpan() {
        let base = "\(goldenBase)/plugin/table/testdata/GoldenFiles/col_row_span"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin()],
                      description: "table/col_row_span")
    }

    func testTableContents() {
        let base = "\(goldenBase)/plugin/table/testdata/GoldenFiles/contents"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin()],
                      description: "table/contents")
    }

    func testTableEmail() {
        let base = "\(goldenBase)/plugin/table/testdata/GoldenFiles/email"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin()],
                      description: "table/email")
    }

    func testTableParents() {
        let base = "\(goldenBase)/plugin/table/testdata/GoldenFiles/parents"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin()],
                      description: "table/parents")
    }

    func testStrikethrough() {
        let base = "\(goldenBase)/plugin/strikethrough/testdata/GoldenFiles/strikethrough"
        runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                      plugins: [BasePlugin(), CommonmarkPlugin(), StrikethroughPlugin()],
                      description: "strikethrough/strikethrough")
    }
}
