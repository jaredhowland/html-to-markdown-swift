import Foundation

/// Heading style for Markdown output
public enum HeadingStyle: String {
    case atx = "atx"       // # Heading
    case setext = "setext" // Heading\n=======
}

/// Link rendering behavior for empty href or content
public enum LinkBehavior: String {
    case render = "render"
    case skip = "skip"
}

/// Options for the Commonmark plugin
public struct CommonmarkOptions {
    /// Delimiter for italic: "*" (default) or "_"
    public var emDelimiter: String = "*"
    /// Delimiter for bold: "**" (default) or "__"
    public var strongDelimiter: String = "**"
    /// Horizontal rule: "* * *" (default), "---", "___", etc.
    public var horizontalRule: String = "* * *"
    /// Bullet list marker: "-" (default), "+", or "*"
    public var bulletListMarker: String = "-"
    /// Code block fence: "```" (default) or "~~~"
    public var codeBlockFence: String = "```"
    /// Heading style: .atx (default) or .setext
    public var headingStyle: HeadingStyle = .atx
    /// How to handle links with empty href
    public var linkEmptyHrefBehavior: LinkBehavior = .render
    /// How to handle links with empty content
    public var linkEmptyContentBehavior: LinkBehavior = .render
    /// When true, suppresses the `<!--THE END-->` comment inserted between consecutive lists
    public var disableListEndComment: Bool = false

    public init() {}
}
