import Foundation

/// Error thrown when CommonmarkOptions has invalid values.
/// Fields match Go's ValidateConfigError struct exactly.
public class ValidateConfigError: Error, LocalizedError {
    public let Key: String
    public let Value: String
    /// Override the default "Key:\"Value\"" format used in the error message.
    /// Matches Go's KeyWithValue field, e.g. for CLI formatting: "--key=value"
    public var KeyWithValue: String = ""
    let patternDescription: String

    init(key: String, value: String, patternDescription: String) {
        self.Key = key
        self.Value = value
        self.patternDescription = patternDescription
    }

    public var errorDescription: String? {
        let kv = KeyWithValue.isEmpty ? "\(Key):\"\(Value)\"" : KeyWithValue
        return "invalid value for \(kv) must be \(patternDescription)"
    }
}

/// Validate CommonmarkOptions, throws ValidateConfigError on invalid values
func validateCommonmarkOptions(_ opts: CommonmarkOptions) throws {
    if opts.emDelimiter != "*" && opts.emDelimiter != "_" {
        throw ValidateConfigError(key: "EmDelimiter", value: opts.emDelimiter, patternDescription: "exactly 1 character of \"*\" or \"_\"")
    }
    if opts.strongDelimiter != "**" && opts.strongDelimiter != "__" {
        throw ValidateConfigError(key: "StrongDelimiter", value: opts.strongDelimiter, patternDescription: "exactly 2 characters of \"**\" or \"__\"")
    }
    let validHR = opts.horizontalRule.allSatisfy { $0 == "*" || $0 == "-" || $0 == "_" || $0 == " " }
    let hrCharsOnly = opts.horizontalRule.filter { $0 != " " }
    if !validHR || hrCharsOnly.count < 3 || (Set(hrCharsOnly).count > 1) {
        throw ValidateConfigError(key: "HorizontalRule", value: opts.horizontalRule, patternDescription: "at least 3 characters of \"*\", \"_\" or \"-\"")
    }
    if opts.bulletListMarker != "-" && opts.bulletListMarker != "+" && opts.bulletListMarker != "*" {
        throw ValidateConfigError(key: "BulletListMarker", value: opts.bulletListMarker, patternDescription: "one of \"-\", \"+\" or \"*\"")
    }
    if opts.codeBlockFence != "```" && opts.codeBlockFence != "~~~" {
        throw ValidateConfigError(key: "CodeBlockFence", value: opts.codeBlockFence, patternDescription: "one of \"```\" or \"~~~\"")
    }
    if opts.headingStyle != .atx && opts.headingStyle != .setext {
        throw ValidateConfigError(key: "HeadingStyle", value: opts.headingStyle.rawValue, patternDescription: "one of \"atx\" or \"setext\"")
    }
}
