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

    // Mirrors Go: TestValidateConfig_Empty
    func testValidateConfig_Empty() throws {
        let opts = CommonmarkOptions()
        // default options should pass validation
        XCTAssertNoThrow(try validateCommonmarkOptions(opts))
        XCTAssertEqual(opts.headingStyle, .atx, "default HeadingStyle should be atx")
    }

    // Mirrors Go: TestValidateConfig_Success
    func testValidateConfig_Success() throws {
        var opts = CommonmarkOptions()
        opts.headingStyle = .setext
        XCTAssertNoThrow(try validateCommonmarkOptions(opts))
        XCTAssertEqual(opts.headingStyle, .setext, "HeadingStyle should not be overridden")
    }

    // Mirrors Go: TestValidateConfig_RandomValue
    func testValidateConfig_RandomValue() throws {
        var opts = CommonmarkOptions()
        opts.emDelimiter = "x"
        do {
            try validateCommonmarkOptions(opts)
            XCTFail("expected an error")
        } catch let e as ValidateConfigError {
            XCTAssertEqual(e.Key, "EmDelimiter", "expected Key=EmDelimiter")
            XCTAssertEqual(e.Value, "x", "expected Value=x")
            let formatted = e.localizedDescription ?? ""
            XCTAssertEqual(formatted, "invalid value for EmDelimiter:\"x\" must be exactly 1 character of \"*\" or \"_\"")
        } catch {
            XCTFail("expected ValidateConfigError but got \(error)")
        }
    }

    // Mirrors Go: TestValidateConfig_KeyWithValue
    func testValidateConfig_KeyWithValue() throws {
        var opts = CommonmarkOptions()
        opts.strongDelimiter = "*"
        do {
            try validateCommonmarkOptions(opts)
            XCTFail("expected an error")
        } catch let e as ValidateConfigError {
            // Default error message (Go API style)
            let formatted1 = e.localizedDescription ?? ""
            let expected1 = "invalid value for StrongDelimiter:\"*\" must be exactly 2 characters of \"**\" or \"__\""
            XCTAssertEqual(formatted1, expected1, "default error message mismatch")

            // CLI-style override via KeyWithValue (mirrors Go: e.KeyWithValue = fmt.Sprintf(...))
            if e.Key == "StrongDelimiter" {
                e.KeyWithValue = "--strong_delimiter=\"\(e.Value)\""
            }
            let formatted2 = e.localizedDescription ?? ""
            let expected2 = "invalid value for --strong_delimiter=\"*\" must be exactly 2 characters of \"**\" or \"__\""
            XCTAssertEqual(formatted2, expected2, "CLI-style error message mismatch")
        } catch {
            XCTFail("expected ValidateConfigError but got \(error)")
        }
    }

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
