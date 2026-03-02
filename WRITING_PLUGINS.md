# Writing Custom Plugins

This guide explains how to extend html-to-markdown with custom plugins to handle specific HTML structures or add custom Markdown formatting.

## Plugin Basics

A plugin conforms to the `Plugin` protocol and can register custom renderers, tag types, and handlers for various phases of the conversion process.

```swift
protocol Plugin {
    func register(with converter: Converter)
    func handlePreRender(node: org.jsoup.nodes.Node, converter: Converter) throws
    func handleRender(node: org.jsoup.nodes.Node, converter: Converter) throws -> String?
    func handlePostRender(node: org.jsoup.nodes.Node, content: String, converter: Converter) throws -> String
    func handleTextTransform(text: String, converter: Converter) throws -> String
    func handleUnEscape(text: String, converter: Converter) throws -> String
}
```

Most handlers have default empty implementations, so you only need to implement what you need.

## Quick Start: Simple Plugin

Here's a minimal plugin that renders custom elements:

```swift
import HTMLToMarkdown

class CustomPlugin: Plugin {
    func register(with converter: Converter) {
        // Register custom tag renderers
        converter.registerRenderer("custom-element") { node, converter in
            let content = try renderChildren(node, converter: converter)
            return "CUSTOM[\(content)]"
        }
    }
}

// Usage
let html = "<custom-element>Hello World</custom-element>"
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    CustomPlugin()
])
// Output: CUSTOM[Hello World]
```

## Plugin Lifecycle

When converting HTML, plugins go through these phases in order:

### 1. Registration Phase

```swift
func register(with converter: Converter) {
    // Register renderers, tag types, and handlers
}
```

Register all your custom renderers and configurations here.

### 2. Pre-Render Phase

```swift
func handlePreRender(node: org.jsoup.nodes.Node, converter: Converter) throws {
    // Modify the HTML tree before rendering
    // E.g., remove nodes, restructure elements, etc.
}
```

Use this to modify the HTML tree before conversion. For example, you could move elements or remove unwanted nodes.

### 3. Main Render Phase

```swift
func handleRender(node: org.jsoup.nodes.Node, converter: Converter) throws -> String? {
    // Return a string if you handle this node, nil otherwise
}
```

Return a rendered Markdown string for the node, or `nil` if you don't handle it (allowing the next plugin to try).

### 4. Post-Render Phase

```swift
func handlePostRender(node: org.jsoup.nodes.Node, content: String, converter: Converter) throws -> String {
    // Modify the rendered content
    return modifiedContent
}
```

Modify the rendered Markdown after other plugins have processed it.

### 5. Text Transform Phase

```swift
func handleTextTransform(text: String, converter: Converter) throws -> String {
    // Transform text content
    return transformedText
}
```

Transform raw text before it's included in the output.

## Practical Examples

### Example 1: YouTube Embed Plugin

Automatically convert YouTube links to embedded video Markdown:

```swift
class YouTubeEmbedPlugin: Plugin {
    func register(with converter: Converter) {
        converter.registerRenderer("a") { (defaultHandler) in
            return { node, converter in
                guard let element = node as? org.jsoup.nodes.Element else { return nil }
                let href = try element.attr("href")
                
                if let videoID = extractYouTubeID(from: href) {
                    return "[![Watch on YouTube](https://img.youtube.com/vi/\(videoID)/0.jpg)](https://youtu.be/\(videoID))"
                }
                
                // Fall back to default link rendering
                return try defaultHandler(node, converter)
            }
        }()
    }
    
    private func extractYouTubeID(from url: String) -> String? {
        // Implementation to extract YouTube video ID
        if let range = url.range(of: "(?:youtube\\.com/watch\\?v=|youtu\\.be/)([a-zA-Z0-9_-]{11})", 
                                  options: .regularExpression) {
            return String(url[range]).replacingOccurrences(of: "watch?v=", with: "").replacingOccurrences(of: "youtu.be/", with: "")
        }
        return nil
    }
}
```

### Example 2: Code Annotation Plugin

Add line numbers to code blocks:

```swift
class CodeAnnotationPlugin: Plugin {
    func register(with converter: Converter) {
        converter.registerRenderer("pre") { node, converter in
            guard let element = node as? org.jsoup.nodes.Element else { return nil }
            
            let language = try? element.attr("data-language") ?? ""
            let content = try renderChildren(element, converter: converter)
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            
            var numberedLines: [String] = []
            for (index, line) in lines.enumerated() {
                numberedLines.append("\(String(format: "%3d", index + 1)) | \(line)")
            }
            
            return "```\(language ?? "")\n\(numberedLines.joined(separator: "\n"))\n```"
        }
    }
}
```

### Example 3: Footnote Plugin

Convert footnotes and references:

```swift
class FootnotePlugin: Plugin {
    var footnotes: [String: String] = [:]
    
    func register(with converter: Converter) {
        converter.registerRenderer("sup") { node, converter in
            guard let element = node as? org.jsoup.nodes.Element,
                  let id = try? element.attr("id") else { return nil }
            
            let content = try renderChildren(element, converter: converter)
            self.footnotes[id] = content
            return "[^\(id)]"
        }
    }
    
    func handlePostRender(node: org.jsoup.nodes.Node, content: String, converter: Converter) throws -> String {
        if footnotes.isEmpty { return content }
        
        var result = content
        for (id, note) in footnotes {
            result += "\n[^\(id)]: \(note)"
        }
        return result
    }
}
```

### Example 4: Ignore Specific Elements

Skip certain HTML elements during conversion:

```swift
class IgnorePlugin: Plugin {
    let selectorsToIgnore: [String]
    
    init(selectors: [String]) {
        self.selectorsToIgnore = selectors
    }
    
    func register(with converter: Converter) {
        converter.registerTagType("ignored", type: .remove, priority: .early)
    }
    
    func handlePreRender(node: org.jsoup.nodes.Node, converter: Converter) throws {
        guard let element = node as? org.jsoup.nodes.Element else { return }
        
        for selector in selectorsToIgnore {
            let toRemove = try? element.select(selector)
            for el in toRemove ?? [] {
                try el.remove()
            }
        }
    }
}

// Usage
let html = """
<article>
    <h1>Title</h1>
    <div class="ad">Remove this</div>
    <p>Keep this</p>
</article>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    IgnorePlugin(selectors: [".ad", ".sidebar"])
])
```

## Helper Functions

The library provides helper functions for common plugin operations:

```swift
// Render children of a node
let content = try renderChildren(node, converter: converter)

// Get element name
if let tagName = getElementName(node) {
    // Use tagName
}

// Get children nodes
let children = getChildren(node)

// Get attribute value
if let href = getAttribute(node, "href") {
    // Use href
}

// Get all attributes
let attrs = getAttributes(node)

// Check for CSS class
if hasClass(node, "primary") {
    // Handle class
}

// Get text content
let text = getTextContent(node)

// Escape markdown special characters
let escaped = escapeMarkdown(text, mode: .smart)
```

## Tag Type Registration

Register custom tag types to control block/inline behavior:

```swift
class CustomTagPlugin: Plugin {
    func register(with converter: Converter) {
        // Block-level element
        converter.registerTagType("custom-block", type: .block, priority: .standard)
        
        // Inline element
        converter.registerTagType("custom-inline", type: .inline, priority: .standard)
        
        // Element to remove
        converter.registerTagType("custom-remove", type: .remove, priority: .standard)
        
        // Register renderers
        converter.registerRenderer("custom-block") { node, converter in
            let children = try renderChildren(node, converter: converter)
            return "\n\(children)\n"
        }
    }
}
```

## Handler Priority

Use priorities to control the order in which handlers are executed:

```swift
converter.registerTagType("tag", type: .block, priority: .early)    // Runs before standard
converter.registerTagType("tag", type: .block, priority: .standard) // Default
converter.registerTagType("tag", type: .block, priority: .late)     // Runs after standard
```

## Best Practices

1. **Keep It Simple**: Plugins should have a single responsibility
2. **Handle Errors**: Wrap potentially failing operations in try-catch blocks
3. **No Side Effects**: Plugins should not modify converter state unexpectedly
4. **Documentation**: Document what HTML your plugin handles
5. **Testing**: Write tests for your plugin's conversion behavior
6. **Performance**: Avoid expensive operations in handlers

## Testing Your Plugin

```swift
import XCTest
@testable import HTMLToMarkdown

class MyPluginTests: XCTestCase {
    func testCustomElementRendering() throws {
        let html = "<custom>content</custom>"
        let markdown = try HTMLToMarkdown.convert(html, plugins: [
            BasePlugin(),
            CommonmarkPlugin(),
            MyPlugin()
        ])
        XCTAssertTrue(markdown.contains("EXPECTED_OUTPUT"))
    }
}
```

## Publishing a Plugin

If you'd like to share your plugin:

1. Create a separate GitHub repository
2. Structure it as a Swift Package
3. Add it as a dependency to package manifests
4. Document the plugin thoroughly
5. Include examples and tests

## See Also

- [Plugin Protocol Documentation](#plugins)
- [Built-in Plugins](README.md#plugin-documentation)
- [Swift Package Documentation](https://swift.org/package-manager/)
