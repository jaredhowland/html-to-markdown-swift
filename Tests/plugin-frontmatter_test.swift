import XCTest
@testable import HTMLToMarkdown

// Helper: convert with FrontmatterPlugin registered, optional domain.
private func convert(_ html: String, domain: String = "") throws -> String {
    var opts: [ConverterOption] = []
    if !domain.isEmpty { opts.append(.domain(domain)) }
    return try HTMLToMarkdown.convert(html, plugins: [
        BasePlugin(), CommonmarkPlugin(), FrontmatterPlugin()
    ], options: opts)
}

// Helper: extract YAML frontmatter fields (between first and second "---").
private func frontmatter(_ output: String) -> [String: String] {
    let lines = output.components(separatedBy: "\n")
    guard lines.first == "---" else { return [:] }
    var result: [String: String] = [:]
    var i = 1
    while i < lines.count && lines[i] != "---" {
        let line = lines[i]
        if let colonIdx = line.firstIndex(of: ":") {
            let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIdx)...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            result[key] = value
        }
        i += 1
    }
    return result
}

// Helper: extract tags list (lines starting with "  - ").
private func tags(_ output: String) -> [String] {
    return output.components(separatedBy: "\n")
        .filter { $0.hasPrefix("  - ") }
        .map { $0.dropFirst(4).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
}

class FrontmatterPluginTests: XCTestCase {

    // MARK: - Output structure

    func testOutputStartsWithFrontmatterBlock() throws {
        let result = try convert("<html><head><title>Test</title></head><body><p>Hello</p></body></html>")
        XCTAssertTrue(result.hasPrefix("---\n"), "Output must start with ---\\n but got: \(result.prefix(20))")
    }

    func testFrontmatterClosedWithDashes() throws {
        let result = try convert("<html><head><title>Test</title></head><body><p>Hello</p></body></html>")
        let parts = result.components(separatedBy: "\n---\n")
        XCTAssertGreaterThanOrEqual(parts.count, 2, "Frontmatter must be closed with ---")
    }

    func testMarkdownContentFollowsFrontmatter() throws {
        let result = try convert("<html><head><title>T</title></head><body><p>Hello world</p></body></html>")
        XCTAssertTrue(result.contains("---\n\nHello world"), "Markdown content must follow frontmatter block")
    }

    // MARK: - date_saved always present

    func testDateSavedAlwaysPresent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNotNil(fm["date_saved"], "date_saved must always be present")
    }

    func testDateSavedIsISO8601() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        let dateStr = fm["date_saved"] ?? ""
        let formatter = ISO8601DateFormatter()
        XCTAssertNotNil(formatter.date(from: dateStr), "date_saved must be ISO 8601: \(dateStr)")
    }

    // MARK: - word_count and reading_time

    func testWordCountPresent() throws {
        let result = try convert("<html><head></head><body><p>one two three</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["word_count"], "3")
    }

    func testReadingTimePresentAndValid() throws {
        let words = Array(repeating: "word", count: 200).joined(separator: " ")
        let html = "<html><head></head><body><p>\(words)</p></body></html>"
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["reading_time"], "1 min")
    }

    func testReadingTimeRoundsUp() throws {
        let words = Array(repeating: "word", count: 201).joined(separator: " ")
        let html = "<html><head></head><body><p>\(words)</p></body></html>"
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["reading_time"], "2 min")
    }

    // MARK: - title

    func testTitleFromTitleTag() throws {
        let result = try convert("<html><head><title>My Page</title></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["title"], "My Page")
    }

    func testTitleFallsBackToOgTitle() throws {
        let html = """
        <html><head>
        <meta property="og:title" content="OG Title"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["title"], "OG Title")
    }

    func testTitleOmittedWhenAbsent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["title"], "title must be omitted when not found")
    }

    // MARK: - author

    func testAuthorFromMetaTag() throws {
        let html = """
        <html><head>
        <meta name="author" content="Jane Doe"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["author"], "Jane Doe")
    }

    func testAuthorFallsBackToOgAuthor() throws {
        let html = """
        <html><head>
        <meta property="og:author" content="OG Author"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["author"], "OG Author")
    }

    func testAuthorOmittedWhenAbsent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["author"])
    }

    // MARK: - description

    func testDescriptionFromMetaTag() throws {
        let html = """
        <html><head>
        <meta name="description" content="A test description."/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["description"], "A test description.")
    }

    func testDescriptionFallsBackToOgDescription() throws {
        let html = """
        <html><head>
        <meta property="og:description" content="OG Desc"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["description"], "OG Desc")
    }

    func testDescriptionOmittedWhenAbsent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["description"])
    }

    // MARK: - source

    func testSourceFromDomain() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>", domain: "https://example.com")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["source"], "https://example.com")
    }

    func testSourceOmittedWhenDomainNotSet() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["source"])
    }

    // MARK: - url

    func testURLFromCanonicalLink() throws {
        let html = """
        <html><head>
        <link rel="canonical" href="https://example.com/page/"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html, domain: "https://example.com")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["url"], "https://example.com/page/")
    }

    func testURLFallsBackToDomain() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>", domain: "https://example.com")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["url"], "https://example.com")
    }

    func testURLOmittedWhenNeitherPresent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["url"])
    }

    // MARK: - tags

    func testTagsFromKeywordsMeta() throws {
        let html = """
        <html><head>
        <meta name="keywords" content="swift, ios, macos"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let t = tags(result)
        XCTAssertTrue(t.contains("swift"), "tags must contain 'swift'")
        XCTAssertTrue(t.contains("ios"), "tags must contain 'ios'")
        XCTAssertTrue(t.contains("macos"), "tags must contain 'macos'")
    }

    func testTagsFromArticleTag() throws {
        let html = """
        <html><head>
        <meta property="article:tag" content="programming"/>
        <meta property="article:tag" content="swift"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let t = tags(result)
        XCTAssertTrue(t.contains("programming"))
        XCTAssertTrue(t.contains("swift"))
    }

    func testTagsFromLdJson() throws {
        let json = #"{"@context":"https://schema.org","@type":"WebPage","keywords":"schema,tags"}"#
        let html = """
        <html><head>
        <script type="application/ld+json">\(json)</script>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let t = tags(result)
        XCTAssertTrue(t.contains("schema"))
        XCTAssertTrue(t.contains("tags"))
    }

    func testTagsDeduplicatedAcrossSources() throws {
        let html = """
        <html><head>
        <meta name="keywords" content="swift, ios"/>
        <meta property="article:tag" content="swift"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let t = tags(result)
        XCTAssertEqual(t.filter { $0 == "swift" }.count, 1, "Duplicate tags must be removed")
    }

    func testTagsOmittedWhenAbsent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let t = tags(result)
        XCTAssertTrue(t.isEmpty, "tags section must be absent when no tags found")
    }

    // MARK: - YAML special character escaping

    func testYAMLSpecialCharsInTitle() throws {
        let html = """
        <html><head><title>A "quoted" title</title></head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("A \\\"quoted\\\" title"), "Double quotes must be escaped in YAML")
    }

    func testYAMLBackslashInDescription() throws {
        let html = """
        <html><head>
        <meta name="description" content="path\\to\\file"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        // The stored value should have single backslashes (YAML double-quoted string unescaping)
        // but since our test helper uses simple string parsing (not a real YAML parser),
        // just verify the output contains the escaped form
        XCTAssertTrue(result.contains("path\\\\to\\\\file"), "Backslashes must be double-escaped in YAML")
    }
}
