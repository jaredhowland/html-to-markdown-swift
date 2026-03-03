import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(RMarkdownPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class RMarkdownPluginTests: XCTestCase {

    // MARK: - Inherits Pandoc features

    func testInheritsMath() throws {
        let html = "<p>Formula: <span class=\"math inline\">\\(x^2\\)</span></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("$x^2$"), "RMarkdown should inherit math from Pandoc: \(result)")
    }

    func testInheritsDefinitionLists() throws {
        let html = "<dl><dt>Term</dt><dd>Definition</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains(":   Definition"), "RMarkdown should inherit def lists from Pandoc: \(result)")
    }

    func testInheritsSubSup() throws {
        let html = "<p>H<sub>2</sub>O and E=mc<sup>2</sup></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("~2~"), "Expected subscript: \(result)")
        XCTAssertTrue(result.contains("^2^"), "Expected superscript: \(result)")
    }

    // MARK: - Figure Captions

    func testFigureWithCaption() throws {
        let html = "<figure><img src=\"plot.png\" alt=\"\"><figcaption>Figure 1: A scatter plot</figcaption></figure>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("![Figure 1: A scatter plot](plot.png)"), "Expected fig caption as alt: \(result)")
    }

    func testFigureWithoutCaption() throws {
        let html = "<figure><img src=\"plot.png\" alt=\"My alt\"></figure>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("![My alt](plot.png)"), "Expected alt text used when no caption: \(result)")
    }

    func testFigureCaptionOverridesAlt() throws {
        let html = "<figure><img src=\"chart.png\" alt=\"old alt\"><figcaption>New caption</figcaption></figure>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("![New caption](chart.png)"), "Caption should override alt: \(result)")
        XCTAssertFalse(result.contains("old alt"), "Old alt should not appear: \(result)")
    }

    // MARK: - Tabsets

    func testTabsetRenderedAsSections() throws {
        let html = """
        <div class="tabset">
          <ul class="nav nav-tabs">
            <li><a href="#tab-a">Tab A</a></li>
            <li><a href="#tab-b">Tab B</a></li>
          </ul>
          <div class="tab-content">
            <div class="tab-pane" id="tab-a"><p>Content A</p></div>
            <div class="tab-pane" id="tab-b"><p>Content B</p></div>
          </div>
        </div>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("## Tab A"), "Expected Tab A heading in: \(result)")
        XCTAssertTrue(result.contains("## Tab B"), "Expected Tab B heading in: \(result)")
        XCTAssertTrue(result.contains("Content A"), "Expected Tab A content in: \(result)")
        XCTAssertTrue(result.contains("Content B"), "Expected Tab B content in: \(result)")
    }

    func testNonTabsetDivUnaffected() throws {
        let html = "<div class=\"content\"><p>Regular content</p></div>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Regular content"), "Regular divs should be unaffected: \(result)")
    }
}
