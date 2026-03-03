import Foundation
import SwiftSoup

// Metadata extracted from <head> during pre-render phase.
struct FrontmatterMeta {
    var title: String?
    var author: String?
    var description: String?
    var canonicalURL: String?
    var tags: [String] = []
}

private let stateKey = "frontmatter_meta"

public class FrontmatterPlugin: Plugin {
    public var name: String { return "frontmatter" }

    public init() {}

    public func initialize(conv: Converter) throws {
        conv.Register.preRenderer({ ctx, doc in
            var meta = FrontmatterMeta()

            if let t = (try? doc.select("title").first()?.text()), !t.isEmpty {
                meta.title = t
            } else if let t = (try? doc.select("meta[property=og:title]").first()?.attr("content")), !t.isEmpty {
                meta.title = t
            }

            if let a = (try? doc.select("meta[name=author]").first()?.attr("content")), !a.isEmpty {
                meta.author = a
            } else if let a = (try? doc.select("meta[property=og:author]").first()?.attr("content")), !a.isEmpty {
                meta.author = a
            }

            if let d = (try? doc.select("meta[name=description]").first()?.attr("content")), !d.isEmpty {
                meta.description = d
            } else if let d = (try? doc.select("meta[property=og:description]").first()?.attr("content")), !d.isEmpty {
                meta.description = d
            }

            if let href = (try? doc.select("link[rel=canonical]").first()?.attr("href")), !href.isEmpty {
                meta.canonicalURL = href
            }

            var tagSet: [String] = []

            if let keywords = (try? doc.select("meta[name=keywords]").first()?.attr("content")), !keywords.isEmpty {
                let parts = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                tagSet.append(contentsOf: parts)
            }

            if let articleTags = try? doc.select("meta[property=article:tag]") {
                for el in articleTags.array() {
                    let v = (try? el.attr("content")) ?? ""
                    if !v.isEmpty { tagSet.append(v) }
                }
            }

            if let scripts = try? doc.select("script[type=application/ld+json]") {
                for script in scripts.array() {
                    guard let jsonText = try? script.html(),
                          let data = jsonText.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    if let kw = obj["keywords"] as? String {
                        let parts = kw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        tagSet.append(contentsOf: parts)
                    } else if let kwArr = obj["keywords"] as? [String] {
                        tagSet.append(contentsOf: kwArr.filter { !$0.isEmpty })
                    }
                }
            }

            var seen = Set<String>()
            meta.tags = tagSet.filter { seen.insert($0).inserted }

            ctx.setState(stateKey, val: meta)
        }, priority: PriorityEarly - 10)

        conv.Register.postRenderer({ ctx, result in
            let meta: FrontmatterMeta = ctx.getState(stateKey) ?? FrontmatterMeta()

            let words = result.split(whereSeparator: \.isWhitespace).filter { !$0.isEmpty }
            let wordCount = words.count
            let readingTime = max(1, Int(ceil(Double(wordCount) / 200.0)))

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let dateSaved = formatter.string(from: Date())

            let yaml = buildFrontmatter(
                meta: meta,
                domain: ctx.conv.domain,
                wordCount: wordCount,
                readingTime: readingTime,
                dateSaved: dateSaved
            )

            return "\(yaml)\n\n\(result)"
        }, priority: PriorityLate + 100)
    }
}

// MARK: - YAML helpers

private func yamlString(_ value: String) -> String {
    let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

private func buildFrontmatter(meta: FrontmatterMeta, domain: String, wordCount: Int, readingTime: Int, dateSaved: String) -> String {
    var lines: [String] = ["---"]

    func append(_ key: String, _ value: String?) {
        guard let v = value, !v.isEmpty else { return }
        lines.append("\(key): \(yamlString(v))")
    }

    append("title", meta.title)
    append("author", meta.author)
    append("source", domain.isEmpty ? nil : domain)
    append("url", meta.canonicalURL ?? (domain.isEmpty ? nil : domain))
    lines.append("date_saved: \(yamlString(dateSaved))")
    lines.append("word_count: \(yamlString(String(wordCount)))")
    lines.append("reading_time: \(yamlString("\(readingTime) min"))")
    append("description", meta.description)

    if !meta.tags.isEmpty {
        lines.append("tags:")
        for tag in meta.tags {
            lines.append("  - \(yamlString(tag))")
        }
    }

    lines.append("---")
    return lines.joined(separator: "\n")
}
