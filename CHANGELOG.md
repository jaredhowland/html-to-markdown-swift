# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.5.0] - 2026-03-02

### Added

#### Core Features
- Initial Swift port of html-to-markdown Go library with full feature parity
- HTML to Markdown conversion with `HTMLToMarkdown.convert()` API
- Support for HTML strings and Data input
- Thread-safe converter with internal synchronization

#### Markdown Support
- **CommonMark Specification**: Full support for standard Markdown
  - Bold text (`<strong>`, `<b>` → `**text**`)
  - Italic text (`<em>`, `<i>` → `*text*`)
  - Bold and italic combinations
  - Links with href and title attributes
  - Images with alt text and titles
  - Absolute and relative URL support
  - Inline code with backticks
  - Code blocks with language specification
  - Blockquotes with nesting support
  - All heading levels (h1-h6)
  - Unordered and ordered lists with nesting
  - Horizontal rules
  - Line breaks
  - HTML comment removal

#### Plugin System
- Extensible plugin architecture with `Plugin` protocol
- Built-in plugins:
  - **BasePlugin**: HTML structure handling and tag removal
  - **CommonmarkPlugin**: Markdown standard implementation (configurable)
  - **StrikethroughPlugin**: Strikethrough text support (~~text~~)
  - **TablePlugin**: GitHub Flavored Markdown tables
- Plugin lifecycle hooks: PreRender, Render, PostRender, TextTransform, UnEscape
- Custom renderer registration
- Tag type configuration (block/inline/remove)

#### Configuration Options
- **Domain Resolution**: Convert relative links to absolute URLs
- **CSS Selectors**: Include/exclude elements by css selector
- **Escape Mode**: Smart (default) or disabled special character escaping
- **Custom Renderers**: Register custom converters for specific tags
- **Custom Tag Types**: Configure block/inline/remove behavior

#### Utilities
- Helper functions for node manipulation
- Whitespace management (collapse, trim consecutive newlines)
- Character escaping utility
- Attribute access helpers
- Children rendering functions

#### Testing
- Comprehensive test suite with 35+ tests
- Coverage includes:
  - Basic markdown elements
  - Complex nested structures
  - Plugin functionality
  - Error handling
  - Performance benchmarks
  - Edge cases

#### Documentation
- **README.md**: Complete user guide with examples
- **ESCAPING.md**: Character escaping behavior guide
- **WRITING_PLUGINS.md**: Plugin development guide with examples
- **CONTRIBUTING.md**: Contribution guidelines
- **Examples.swift**: 10+ practical usage examples
- **IMPLEMENTATION_SUMMARY.md**: Comprehensive implementation overview
- Inline DocC documentation throughout source code

#### Platform Support
- macOS 10.15+
- iOS 13+
- tvOS 13+
- watchOS 6+
- Swift 5.5+

### Technical Details

#### Dependencies
- SwiftSoup (2.4.0+) for HTML parsing

#### Thread Safety
- Full NSLock-based synchronization for concurrent use

#### Performance
- Efficient HTML parsing with SwiftSoup
- Minimal memory allocations
- Streaming-friendly architecture

### Known Limitations

- CSS selector filtering uses SwiftSoup's engine (minor compatibility differences)
- Complex table features (rowspan/colspan) have basic support
- Performance is acceptable but may differ from Go in extreme cases

### Future Plans

- Additional plugins (GitHub Flavored Markdown extended, Task lists, Embeds)
- Async/await API for large document processing
- Streaming conversion support
- Link reference definition support
- Enhanced table formatting options

---

## Notes for Users

### Migration from Go Library

If you were using the Go library:

```go
// Go
htmltomarkdown.ConvertString(html)
```

```swift
// Swift equivalent
try HTMLToMarkdown.convert(html)
```

The Swift API is more idiomatically Swift while maintaining compatible conversion behavior.

### Reporting Issues

When reporting issues:
1. Include the exact HTML input
2. Describe expected output
3. Describe actual output
4. Provide your Swift version and platform
5. Include a minimal reproducible example

### Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## Release Information

**Version**: 2.5.0
**Release Date**: March 2, 2026
**Status**: Stable
**License**: MIT

This is the initial release of the Swift port of html-to-markdown, providing full feature parity with the original Go library.
