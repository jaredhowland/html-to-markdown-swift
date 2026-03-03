import Foundation
import SwiftSoup

extension AtlassianPlugin {
    func registerAttachments(conv: Converter) {
        // Pre-render: convert Confluence image/link attachments to standard HTML elements
        conv.Register.preRenderer({ ctx, doc in
            // Handle image attachments
            // <ac:image ac:width="500"><ri:attachment ri:filename="file.png"/></ac:image>
            let acImages = (try? doc.getElementsByTag("ac:image")) ?? Elements()
            for acImage in acImages {
                guard let attachment = try? acImage.getElementsByTag("ri:attachment").first() else { continue }
                let filename = (try? attachment.attr("ri:filename")) ?? ""
                guard !filename.isEmpty else { continue }

                guard let img = try? Element(Tag.valueOf("img"), "") else { continue }
                try? img.attr("src", filename)
                try? img.attr("alt", filename)

                // Carry over ac:width as width attribute
                let width = (try? acImage.attr("ac:width")) ?? ""
                if !width.isEmpty { try? img.attr("width", width) }

                try? acImage.replaceWith(img)
            }

            // Handle link attachments
            // <ac:link><ri:attachment ri:filename="doc.pdf"/><ac:plain-text-link-body>Label</ac:plain-text-link-body></ac:link>
            let acLinks = (try? doc.getElementsByTag("ac:link")) ?? Elements()
            for acLink in acLinks {
                guard let attachment = try? acLink.getElementsByTag("ri:attachment").first() else { continue }
                let filename = (try? attachment.attr("ri:filename")) ?? ""
                guard !filename.isEmpty else { continue }

                let label: String
                if let body = try? acLink.getElementsByTag("ac:plain-text-link-body").first(),
                   let bodyText = try? body.text(), !bodyText.isEmpty {
                    label = bodyText
                } else {
                    label = filename
                }

                guard let a = try? Element(Tag.valueOf("a"), "") else { continue }
                try? a.attr("href", filename)
                try? a.text(label)
                try? acLink.replaceWith(a)
            }
        }, priority: PriorityEarly)
    }
}
