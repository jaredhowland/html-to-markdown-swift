# Contributing

We welcome contributions to the html-to-markdown Swift port! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and constructive in all interactions.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/jaredhowland/html-to-markdown.git`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Commit with clear messages: `git commit -am 'Add feature X'`
6. Push to your fork: `git push origin feature/your-feature`
7. Create a Pull Request

## Code Style

- Use Swift naming conventions (camelCase for variables/functions, PascalCase for types)
- Keep lines under 100 characters when possible
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Format code with proper indentation (4 spaces)

## Testing

- Write tests for all new features
- Run tests before submitting PR: `swift test`
- Aim for >85% test coverage
- Add tests to `Tests/HTMLToMarkdownTests.swift`

## Commit Messages

Use clear, descriptive commit messages:

```
Add feature: Brief description

Longer explanation of the changes if needed.
- Specific change 1
- Specific change 2
```

## Pull Request Process

1. Update documentation if needed
2. Ensure all tests pass
3. Update README.md if adding new features
4. Request review from maintainers
5. Respond to feedback and requests
6. Ensure branch is up to date with main before merging

## Areas for Contribution

### Features
- New plugins (Footnotes, Task Lists, Strikethrough improvements)
- Enhanced table support
- Link reference definitions
- Improved list nesting
- Custom HTML sanitization options

### Documentation
- Additional examples
- API documentation improvements
- Plugin writing guides
- Performance optimization notes

### Testing
- Edge case tests
- Cross-platform testing
- Performance benchmarks
- Golden file tests (HTML/Markdown pairs)

### Bug Fixes
- Report issues with clear HTML examples
- Include expected vs actual output
- Provide test cases when possible

## Reporting Issues

When reporting issues, include:

1. **HTML input**: The exact HTML that causes the issue
2. **Expected output**: What you expected it to convert to
3. **Actual output**: What it actually converted to
4. **Environment**: Swift version, Platform (iOS/macOS/etc)
5. **Reproducible example**: Minimal code to reproduce

Example:
```
**Issue**: Bold not working within links

**Input**: `<a href="/"><strong>Bold Link</strong></a>`
**Expected**: `[**Bold Link**](/)`
**Actual**: `[Bold Link](/)`
**Environment**: Swift 5.5, macOS
```

## Development Setup

### Requirements
- Swift 5.5 or later
- macOS, Linux, or Windows with Swift installed

### Building
```bash
swift build
```

### Running Tests
```bash
swift test
```

### Generate Documentation
```bash
swift build -Xswiftc -suppress-warnings
```

## Compatibility

This port aims for feature parity with the original Go library:
- https://github.com/JohannesKaufmann/html-to-markdown

When implementing features:
1. Test against the Go library's behavior
2. Add corresponding tests
3. Document any intentional differences

## Documentation

- Public APIs should have documentation comments
- Use DocC format for Swift documentation
- Keep README.md up to date
- Update ESCAPING.md or WRITING_PLUGINS.md if relevant

## Plugin Development

If contributing a plugin:

1. Create a new Swift Package or file
2. Conform to the `Plugin` protocol
3. Add comprehensive documentation
4. Include usage examples
5. Write tests
6. Consider thread safety

Example plugin structure:
```swift
class MyPlugin: Plugin {
    func register(with converter: Converter) {
        // Registration code
    }
    
    func handleRender(node: org.jsoup.nodes.Node, converter: Converter) throws -> String? {
        // Rendering logic
        return nil
    }
}
```

## Release Process

For maintainers:

1. Update version in Package.swift
2. Update CHANGELOG
3. Tag release: `git tag v1.2.3`
4. Push tag: `git push origin v1.2.3`
5. Create GitHub release with release notes

## Questions?

- Open an issue for discussion
- Check existing issues for similar topics
- Review the documentation first

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Acknowledgments

Thank you for contributing to make this library better! Your efforts help the community.

See [AUTHORS](AUTHORS) for a list of contributors.
