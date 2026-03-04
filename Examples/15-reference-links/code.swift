import Foundation
import HTMLToMarkdown

// MARK: - Example 15: ReferenceLinkPlugin — Reference vs Inline Links
// Demonstrates the difference between reference-style links (default)
// and inline links when using ReferenceLinkPlugin.

let html = try String(contentsOf: URL(string: "https://example.com")!, encoding: .utf8)

// Reference-style links (default): links are collected and appended as
// a numbered reference list at the bottom of the document.
print("// Reference-style links (default):\n")
let referenceMarkdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    ReferenceLinkPlugin()
])
print(referenceMarkdown)

print("\n\n---\n\n// Inline links (inlineLinks: true):\n")
let inlineMarkdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    ReferenceLinkPlugin(inlineLinks: true)
])
print(inlineMarkdown)
