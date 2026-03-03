import Foundation

/// Error thrown when CommonmarkOptions has invalid values
public struct ValidateConfigError: Error, LocalizedError {
    public let field: String
    public let value: String
    public let message: String

    public var errorDescription: String? {
        return "invalid value for \(field):\"\(value)\" \(message)"
    }
}

/// Validate CommonmarkOptions, throws ValidateConfigError on invalid values
func validateCommonmarkOptions(_ opts: CommonmarkOptions) throws {
    if opts.emDelimiter != "*" && opts.emDelimiter != "_" {
        throw ValidateConfigError(field: "EmDelimiter", value: opts.emDelimiter, message: "must be exactly 1 character of \"*\" or \"_\"")
    }
    if opts.strongDelimiter != "**" && opts.strongDelimiter != "__" {
        throw ValidateConfigError(field: "StrongDelimiter", value: opts.strongDelimiter, message: "must be exactly 2 characters of \"**\" or \"__\"")
    }
    let validHR = opts.horizontalRule.allSatisfy { $0 == "*" || $0 == "-" || $0 == "_" || $0 == " " }
    let hrCharsOnly = opts.horizontalRule.filter { $0 != " " }
    if !validHR || hrCharsOnly.count < 3 || (Set(hrCharsOnly).count > 1) {
        throw ValidateConfigError(field: "HorizontalRule", value: opts.horizontalRule, message: "must be at least 3 characters of \"*\", \"_\" or \"-\"")
    }
    if opts.bulletListMarker != "-" && opts.bulletListMarker != "+" && opts.bulletListMarker != "*" {
        throw ValidateConfigError(field: "BulletListMarker", value: opts.bulletListMarker, message: "must be one of \"-\", \"+\" or \"*\"")
    }
    if opts.codeBlockFence != "```" && opts.codeBlockFence != "~~~" {
        throw ValidateConfigError(field: "CodeBlockFence", value: opts.codeBlockFence, message: "must be one of \"```\" or \"~~~\"")
    }
    if opts.headingStyle != .atx && opts.headingStyle != .setext {
        throw ValidateConfigError(field: "HeadingStyle", value: opts.headingStyle.rawValue, message: "must be one of \"atx\" or \"setext\"")
    }
}
