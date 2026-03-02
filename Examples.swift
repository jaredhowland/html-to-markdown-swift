import Foundation
import HTMLToMarkdown

// MARK: - Example 1: Basic Conversion

func exampleBasic() throws {
    let html = "<strong>Bold Text</strong>"
    
    let markdown = try HTMLToMarkdown.convert(html)
    print("Input: \(html)")
    print("Output: \(markdown)")
    // Output: **Bold Text**
}

// MARK: - Example 2: Resolve Relative Links

func exampleDomain() throws {
    let html = "<img src=\"/assets/image.png\" />"
    
    let markdown = try HTMLToMarkdown.convert(html, options: [
        .domain("https://example.com")
    ])
    print("Input: \(html)")
    print("Output: \(markdown)")
    // Output: ![](https://example.com/assets/image.png)
}

// MARK: - Example 3: Custom Markdown Delimiters

func exampleCustomDelimiters() throws {
    struct CustomCommonmarkOptions: Equatable {
        var strongDelimiter: String = "__"
        var emDelimiter: String = "_"
    }
    
    let html = "<strong>Bold Text</strong>"
    
    var options = CommonmarkOptions()
    options.strongDelimiter = "__"  // Use __ instead of **
    
    let markdown = try HTMLToMarkdown.convert(
        html,
        plugins: [
            BasePlugin(),
            CommonmarkPlugin(options: options)
        ]
    )
    print("Input: \(html)")
    print("Output: \(markdown)")
    // Output: __Bold Text__
}

// MARK: - Example 4: Using Plugins

func examplePlugins() throws {
    let html = """
    <p>Text with <strong>bold</strong>, <em>italic</em>, and ~~strikethrough~~.</p>
    <table>
        <thead>
            <tr><th>Feature</th><th>Supported</th></tr>
        </thead>
        <tbody>
            <tr><td>Bold</td><td>Yes</td></tr>
        </tbody>
    </table>
    """
    
    let markdown = try HTMLToMarkdown.convert(
        html,
        plugins: [
            BasePlugin(),
            CommonmarkPlugin(),
            StrikethroughPlugin(),
            TablePlugin()
        ]
    )
    print("Conversion with multiple plugins:")
    print(markdown)
}

// MARK: - Example 5: Register Custom Tag Renderers

func exampleRegisterRenderers() throws {
    let html = "<article><h1>Article Title</h1><p>Content here</p></article>"
    
    let converter = HTMLToMarkdown.createConverter(plugins: [
        BasePlugin(),
        CommonmarkPlugin()
    ])
    
    // Register custom renderer for article tag
    converter.registerRenderer("article") { node, converter in
        let content = try renderChildren(node, converter: converter)
        return "\n---\n\(content)\n---\n"
    }
    
    let markdown = try converter.convertString(html)
    print("With custom renderer:")
    print(markdown)
}

// MARK: - Example 6: Handle Multiple Conversions with Single Converter

func examplePersistentConverter() throws {
    let converter = HTMLToMarkdown.createConverter(plugins: [
        BasePlugin(),
        CommonmarkPlugin()
    ], options: [
        .domain("https://example.com")
    ])
    
    let html1 = "<p>First HTML <a href=\"/page1\">link</a></p>"
    let html2 = "<p>Second HTML <a href=\"/page2\">link</a></p>"
    
    let md1 = try converter.convertString(html1)
    let md2 = try converter.convertString(html2)
    
    print("Using persistent converter:")
    print("Conversion 1: \(md1)")
    print("Conversion 2: \(md2)")
}

// MARK: - Example 7: Complex HTML Document

func exampleComplexDocument() throws {
    let html = """
    <article>
        <header>
            <h1>Understanding Swift</h1>
            <p>By <strong>Jane Developer</strong></p>
            <p>Published: <em>March 1, 2026</em></p>
        </header>
        <section>
            <h2>Introduction</h2>
            <p>Swift is a powerful programming language for <strong>iOS</strong>, <strong>macOS</strong>, and <strong>web</strong> development.</p>
            <blockquote>
                <p>Swift combines powerful language features with a simple and intuitive syntax.</p>
            </blockquote>
        </section>
        <section>
            <h2>Key Features</h2>
            <ul>
                <li>Type safety</li>
                <li>Memory safety</li>
                <li>Fast execution</li>
                <li>Modern syntax</li>
            </ul>
        </section>
        <section>
            <h2>Code Example</h2>
            <pre><code>let greeting = "Hello, World!"
print(greeting)</code></pre>
        </section>
        <footer>
            <p>Learn more at <a href="https://swift.org">swift.org</a></p>
        </footer>
    </article>
    """
    
    let markdown = try HTMLToMarkdown.convert(html)
    print("Complex document conversion:")
    print(markdown)
}

// MARK: - Example 8: Error Handling

func exampleErrorHandling() throws {
    do {
        let markdown = try HTMLToMarkdown.convert("<invalid>")
        print(markdown)
    } catch let error as ConversionError {
        print("Conversion error: \(error.localizedDescription)")
    } catch {
        print("Unexpected error: \(error)")
    }
}

// MARK: - Example 9: Convert Data to Markdown

func exampleDataConversion() throws {
    let htmlString = "<h1>Hello</h1><p>This is a test.</p>"
    let htmlData = htmlString.data(using: .utf8)!
    
    let markdown = try HTMLToMarkdown.convert(data: htmlData)
    print("Data conversion:")
    print(markdown)
}

// MARK: - Example 10: Custom Plugin

class CustomHighlightPlugin: Plugin {
    func register(with converter: Converter) {
        converter.registerRenderer("mark") { node, converter in
            let content = try renderChildren(node, converter: converter)
            return "==\(content)=="
        }
    }
}

func exampleCustomPlugin() throws {
    let html = "<p>This is <mark>highlighted</mark> text.</p>"
    
    let markdown = try HTMLToMarkdown.convert(
        html,
        plugins: [
            BasePlugin(),
            CommonmarkPlugin(),
            CustomHighlightPlugin()
        ]
    )
    print("Custom plugin example:")
    print(markdown)
}

// MARK: - Test All Examples

func runAllExamples() {
    print("=== Example 1: Basic Conversion ===")
    try? exampleBasic()
    print()
    
    print("=== Example 2: Resolve Relative Links ===")
    try? exampleDomain()
    print()
    
    print("=== Example 3: Custom Delimiters ===")
    try? exampleCustomDelimiters()
    print()
    
    print("=== Example 4: Using Plugins ===")
    try? examplePlugins()
    print()
    
    print("=== Example 5: Register Custom Renderers ===")
    try? exampleRegisterRenderers()
    print()
    
    print("=== Example 6: Persistent Converter ===")
    try? examplePersistentConverter()
    print()
    
    print("=== Example 7: Complex Document ===")
    try? exampleComplexDocument()
    print()
    
    print("=== Example 8: Error Handling ===")
    try? exampleErrorHandling()
    print()
    
    print("=== Example 9: Data Conversion ===")
    try? exampleDataConversion()
    print()
    
    print("=== Example 10: Custom Plugin ===")
    try? exampleCustomPlugin()
    print()
}
