import Foundation
import SwiftSoup

public struct QuoteStyle {
    public let openDouble: Character
    public let closeDouble: Character
    public let openSingle: Character
    public let closeSingle: Character

    public init(openDouble: Character, closeDouble: Character,
                openSingle: Character, closeSingle: Character) {
        self.openDouble = openDouble
        self.closeDouble = closeDouble
        self.openSingle = openSingle
        self.closeSingle = closeSingle
    }

    public static let english = QuoteStyle(openDouble: "\u{201C}", closeDouble: "\u{201D}",
                                           openSingle: "\u{2018}", closeSingle: "\u{2019}")
    public static let german  = QuoteStyle(openDouble: "\u{201E}", closeDouble: "\u{201C}",
                                           openSingle: "\u{201A}", closeSingle: "\u{2018}")
    public static let french  = QuoteStyle(openDouble: "\u{00AB}", closeDouble: "\u{00BB}",
                                           openSingle: "\u{2039}", closeSingle: "\u{203A}")
    public static let swedish = QuoteStyle(openDouble: "\u{201D}", closeDouble: "\u{201D}",
                                           openSingle: "\u{2019}", closeSingle: "\u{2019}")
}

public class TypographyPlugin: Plugin {
    public var name: String { return "typography" }

    let enableSmartQuotes: Bool
    let enableReplacements: Bool
    let enableLinkify: Bool
    let quoteStyle: QuoteStyle

    public init(smartQuotes: Bool = true, replacements: Bool = true,
                linkify: Bool = true, quoteStyle: QuoteStyle = .english) {
        self.enableSmartQuotes = smartQuotes
        self.enableReplacements = replacements
        self.enableLinkify = linkify
        self.quoteStyle = quoteStyle
    }

    public func initialize(conv: Converter) throws {
        if enableSmartQuotes { try conv.Register.plugin(SmartQuotesPlugin(style: quoteStyle)) }
        if enableReplacements { try conv.Register.plugin(ReplacementsPlugin()) }
        if enableLinkify      { try conv.Register.plugin(LinkifyPlugin()) }
    }
}

// Stubs — will be replaced by proper implementations in subsequent tasks
public class SmartQuotesPlugin: Plugin {
    public var name: String { return "typography-smartquotes" }
    let style: QuoteStyle
    public init(style: QuoteStyle = .english) { self.style = style }
    public func initialize(conv: Converter) throws {}
}

public class ReplacementsPlugin: Plugin {
    public var name: String { return "typography-replacements" }
    public init() {}
    public func initialize(conv: Converter) throws {}
}

public class LinkifyPlugin: Plugin {
    public var name: String { return "typography-linkify" }
    public init() {}
    public func initialize(conv: Converter) throws {}
}
