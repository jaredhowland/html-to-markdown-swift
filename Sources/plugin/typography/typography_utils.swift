import Foundation

/// Returns ranges in `text` that are inside Markdown code regions (fenced blocks + inline code).
private func codeRanges(in text: String) -> [Range<String.Index>] {
    var ranges: [Range<String.Index>] = []

    // Pass 1: Fenced code blocks (line-by-line scan)
    // A fenced block starts with a line beginning with 3+ backticks or tildes (after optional spaces)
    // and ends with a matching or longer fence of the same character on its own line.
    let lines = text.components(separatedBy: "\n")
    var lineStart: [String.Index] = []  // start index of each line in text
    var idx = text.startIndex
    for line in lines {
        lineStart.append(idx)
        idx = text.index(idx, offsetBy: line.utf16.count + 1, limitedBy: text.endIndex) ?? text.endIndex
    }

    var inFence = false
    var fenceChar: Character = "`"
    var fenceCount = 0
    var fenceBlockStart = text.startIndex

    for (i, line) in lines.enumerated() {
        let stripped = line
        var j = stripped.startIndex
        var leadChar: Character = " "
        var leadCount = 0
        for ch in stripped {
            if ch == "`" || ch == "~" {
                if leadCount == 0 { leadChar = ch }
                if ch == leadChar { leadCount += 1 } else { break }
            } else {
                break
            }
            j = stripped.index(after: j)
        }

        if !inFence {
            if leadCount >= 3 {
                inFence = true
                fenceChar = leadChar
                fenceCount = leadCount
                fenceBlockStart = lineStart[i]
            }
        } else {
            // Check for closing fence: same char, >= same count, rest is whitespace/empty
            if leadChar == fenceChar && leadCount >= fenceCount {
                let remainder = String(stripped[j...]).trimmingCharacters(in: .whitespaces)
                if remainder.isEmpty {
                    inFence = false
                    let lineEnd: String.Index
                    if i + 1 < lineStart.count {
                        lineEnd = lineStart[i + 1]
                    } else {
                        lineEnd = text.endIndex
                    }
                    ranges.append(fenceBlockStart..<lineEnd)
                }
            }
        }
    }

    // Pass 2: Inline code spans (character scan)
    // Skip positions already in a fenced block range
    var i = text.startIndex
    while i < text.endIndex {
        if ranges.contains(where: { $0.contains(i) }) {
            i = text.index(after: i)
            continue
        }

        guard text[i] == "`" else { i = text.index(after: i); continue }

        // Count opening backticks
        var openCount = 0
        var j = i
        while j < text.endIndex && text[j] == "`" {
            openCount += 1
            j = text.index(after: j)
        }

        // Scan forward for matching closing run
        var k = j
        var found = false
        while k < text.endIndex {
            if text[k] == "`" {
                var closeCount = 0
                var m = k
                while m < text.endIndex && text[m] == "`" {
                    closeCount += 1
                    m = text.index(after: m)
                }
                if closeCount == openCount {
                    ranges.append(i..<m)
                    i = m
                    found = true
                    break
                } else {
                    k = m
                    continue
                }
            } else {
                k = text.index(after: k)
            }
        }
        if !found {
            i = j  // skip the opening backticks, continue scan
        }
    }

    return ranges.sorted { $0.lowerBound < $1.lowerBound }
}

/// Applies `transform` only to text outside Markdown code regions.
func applyOutsideCode(_ text: String, transform: (String) -> String) -> String {
    let protected = codeRanges(in: text)
    guard !protected.isEmpty else { return transform(text) }

    var result = ""
    var current = text.startIndex

    for range in protected {
        if current < range.lowerBound {
            result += transform(String(text[current..<range.lowerBound]))
        }
        result += String(text[range])  // code region: pass through unchanged
        current = range.upperBound
    }

    if current < text.endIndex {
        result += transform(String(text[current...]))
    }
    return result
}
