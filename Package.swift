// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "html-to-markdown",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "HTMLToMarkdown",
            targets: ["HTMLToMarkdown"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.4.0")
    ],
    targets: [
        .target(
            name: "HTMLToMarkdown",
            dependencies: ["SwiftSoup"],
            path: "Sources"
        ),
        .testTarget(
            name: "HTMLToMarkdownTests",
            dependencies: ["HTMLToMarkdown"],
            path: "Tests"
        )
    ]
)
