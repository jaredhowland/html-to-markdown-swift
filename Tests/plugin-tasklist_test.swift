import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(TaskListItemsPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class TaskListItemsPluginTests: XCTestCase {

    func testChecked() throws {
        let html = "<ul><li><input type=\"checkbox\" checked> Done</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("- [x] Done"), "Expected '- [x] Done' in: \(result)")
    }

    func testUnchecked() throws {
        let html = "<ul><li><input type=\"checkbox\"> Todo</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("- [ ] Todo"), "Expected '- [ ] Todo' in: \(result)")
    }

    func testMixed() throws {
        let html = """
        <ul>
            <li><input type="checkbox" checked> Done</li>
            <li><input type="checkbox"> Todo</li>
        </ul>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("- [x] Done"), "Expected '- [x] Done' in: \(result)")
        XCTAssertTrue(result.contains("- [ ] Todo"), "Expected '- [ ] Todo' in: \(result)")
    }

    func testNoDoubleSpace() throws {
        let html = "<ul><li><input type=\"checkbox\" checked> Text</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("- [x] Text"), "Expected '- [x] Text' (no double space) in: \(result)")
        XCTAssertFalse(result.contains("[x]  Text"), "Must not have double space after checkbox marker")
    }

    func testNestedCheckbox() throws {
        let html = "<ul><li><span><input type=\"checkbox\" checked></span> Item</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("[x]"), "Expected checkbox marker in: \(result)")
        XCTAssertTrue(result.contains("Item"), "Expected 'Item' in: \(result)")
    }

    func testRegularListUnaffected() throws {
        let html = "<ul><li>First</li><li>Second</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("- First"), "Expected '- First' in: \(result)")
        XCTAssertTrue(result.contains("- Second"), "Expected '- Second' in: \(result)")
        XCTAssertFalse(result.contains("[x]"), "Should not contain checkbox marker in: \(result)")
        XCTAssertFalse(result.contains("[ ]"), "Should not contain checkbox marker in: \(result)")
    }
}
