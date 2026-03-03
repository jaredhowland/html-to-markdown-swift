import XCTest
@testable import HTMLToMarkdown

class TextutilsSurroundingSpacesTests: XCTestCase {
    func testEmpty() {
        let (l, t, r) = SurroundingSpaces("")
        XCTAssertEqual(l, ""); XCTAssertEqual(t, ""); XCTAssertEqual(r, "")
    }
    func testOneSpace() {
        let (l, t, r) = SurroundingSpaces(" ")
        XCTAssertEqual(l, ""); XCTAssertEqual(t, ""); XCTAssertEqual(r, " ")
    }
    func testSimpleString() {
        let (l, t, r) = SurroundingSpaces("some text")
        XCTAssertEqual(l, ""); XCTAssertEqual(t, "some text"); XCTAssertEqual(r, "")
    }
    func testSpacesAround() {
        let (l, t, r) = SurroundingSpaces("  text    ")
        XCTAssertEqual(l, "  "); XCTAssertEqual(t, "text"); XCTAssertEqual(r, "    ")
    }
    func testNewlinesAround() {
        let (l, t, r) = SurroundingSpaces("\n\n text  \n\n")
        XCTAssertEqual(l, "\n\n "); XCTAssertEqual(t, "text"); XCTAssertEqual(r, "  \n\n")
    }
}
