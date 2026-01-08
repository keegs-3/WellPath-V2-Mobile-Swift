//
//  MarkdownContentView.swift
//  WellPath
//
//  Rich markdown renderer with engaging components:
//  - Styled headers, lists, blockquotes
//  - Collapsible sections
//  - Callout boxes (tips, warnings, info)
//  - Code blocks
//

import SwiftUI

struct MarkdownContentView: View {
    let markdown: String
    let accentColor: Color

    @State private var collapsedSections: Set<String> = []

    private var blocks: [MarkdownBlock] {
        parseMarkdown(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(blocks) { block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block.type {
        case .heading1:
            heading1View(block.content)
        case .heading2:
            heading2View(block.content)
        case .heading3:
            heading3View(block.content)
        case .paragraph:
            paragraphView(block.content)
        case .bulletList:
            bulletListView(block.items)
        case .numberedList:
            numberedListView(block.items)
        case .blockquote:
            blockquoteView(block.content)
        case .codeBlock:
            codeBlockView(block.content)
        case .calloutTip:
            calloutView(block.content, type: .tip)
        case .calloutWarning:
            calloutView(block.content, type: .warning)
        case .calloutInfo:
            calloutView(block.content, type: .info)
        case .collapsible:
            collapsibleView(title: block.title ?? "More", content: block.content, id: block.id)
        case .divider:
            dividerView()
        case .image:
            imageView(block.content)
        }
    }

    // MARK: - Heading Views

    @ViewBuilder
    private func heading1View(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(renderInlineMarkdown(text))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Rectangle()
                .fill(accentColor.opacity(0.5))
                .frame(height: 2)
                .frame(maxWidth: 60)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func heading2View(_ text: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)

            Text(renderInlineMarkdown(text))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func heading3View(_ text: String) -> some View {
        Text(renderInlineMarkdown(text))
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white.opacity(0.95))
            .padding(.top, 4)
    }

    // MARK: - Paragraph View

    @ViewBuilder
    private func paragraphView(_ text: String) -> some View {
        Text(renderInlineMarkdown(text))
            .font(.body)
            .foregroundColor(.white.opacity(0.85))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - List Views

    @ViewBuilder
    private func bulletListView(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    Text(renderInlineMarkdown(item))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                }
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func numberedListView(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1).")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(accentColor)
                        .frame(width: 24, alignment: .trailing)

                    Text(renderInlineMarkdown(item))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                }
            }
        }
    }

    // MARK: - Blockquote View

    @ViewBuilder
    private func blockquoteView(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor.opacity(0.6))
                .frame(width: 4)

            Text(renderInlineMarkdown(text))
                .font(.body)
                .italic()
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(5)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Code Block View

    @ViewBuilder
    private func codeBlockView(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Code header
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Code")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(12)
            }
        }
        .background(Color.black.opacity(0.4))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Callout View

    enum CalloutType {
        case tip, warning, info

        var icon: String {
            switch self {
            case .tip: return "lightbulb.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .tip: return .green
            case .warning: return .orange
            case .info: return .blue
            }
        }

        var title: String {
            switch self {
            case .tip: return "Tip"
            case .warning: return "Important"
            case .info: return "Note"
            }
        }
    }

    @ViewBuilder
    private func calloutView(_ text: String, type: CalloutType) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundColor(type.color)

            VStack(alignment: .leading, spacing: 6) {
                Text(type.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(type.color)

                Text(renderInlineMarkdown(text))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Collapsible View

    @ViewBuilder
    private func collapsibleView(title: String, content: String, id: String) -> some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if collapsedSections.contains(id) {
                        collapsedSections.remove(id)
                    } else {
                        collapsedSections.insert(id)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: collapsedSections.contains(id) ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(accentColor)
                        .frame(width: 16)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Spacer()

                    Text(collapsedSections.contains(id) ? "Show" : "Hide")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .cornerRadius(collapsedSections.contains(id) ? 10 : 0)
            }
            .buttonStyle(.plain)

            // Content
            if !collapsedSections.contains(id) {
                Text(renderInlineMarkdown(content))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(5)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.03))
            }
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Divider View

    @ViewBuilder
    private func dividerView() -> some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(accentColor.opacity(0.4))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Image View

    @ViewBuilder
    private func imageView(_ urlString: String) -> some View {
        if let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .tint(accentColor)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                case .failure:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 100)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("Image unavailable")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Inline Markdown Rendering

    private func renderInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Try to parse inline markdown (bold, italic, code, links)
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            result = attributed
        }

        return result
    }
}

// MARK: - Markdown Block Model

struct MarkdownBlock: Identifiable {
    let id: String
    let type: BlockType
    let content: String
    let items: [String]
    let title: String?

    init(type: BlockType, content: String = "", items: [String] = [], title: String? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.content = content
        self.items = items
        self.title = title
    }

    enum BlockType {
        case heading1
        case heading2
        case heading3
        case paragraph
        case bulletList
        case numberedList
        case blockquote
        case codeBlock
        case calloutTip
        case calloutWarning
        case calloutInfo
        case collapsible
        case divider
        case image
    }
}

// MARK: - Markdown Parser

private func parseMarkdown(_ markdown: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    let lines = markdown.components(separatedBy: "\n")
    var index = 0

    while index < lines.count {
        let line = lines[index]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip empty lines
        if trimmed.isEmpty {
            index += 1
            continue
        }

        // Headers
        if trimmed.hasPrefix("### ") {
            blocks.append(MarkdownBlock(type: .heading3, content: String(trimmed.dropFirst(4))))
            index += 1
            continue
        }

        if trimmed.hasPrefix("## ") {
            blocks.append(MarkdownBlock(type: .heading2, content: String(trimmed.dropFirst(3))))
            index += 1
            continue
        }

        if trimmed.hasPrefix("# ") {
            blocks.append(MarkdownBlock(type: .heading1, content: String(trimmed.dropFirst(2))))
            index += 1
            continue
        }

        // Divider
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            blocks.append(MarkdownBlock(type: .divider))
            index += 1
            continue
        }

        // Callouts (custom syntax: > [!tip], > [!warning], > [!info])
        if trimmed.hasPrefix("> [!tip]") {
            let content = collectBlockquoteContent(lines: lines, startIndex: &index, prefix: "> [!tip]")
            blocks.append(MarkdownBlock(type: .calloutTip, content: content))
            continue
        }

        if trimmed.hasPrefix("> [!warning]") || trimmed.hasPrefix("> [!important]") {
            let content = collectBlockquoteContent(lines: lines, startIndex: &index, prefix: trimmed.hasPrefix("> [!warning]") ? "> [!warning]" : "> [!important]")
            blocks.append(MarkdownBlock(type: .calloutWarning, content: content))
            continue
        }

        if trimmed.hasPrefix("> [!info]") || trimmed.hasPrefix("> [!note]") {
            let content = collectBlockquoteContent(lines: lines, startIndex: &index, prefix: trimmed.hasPrefix("> [!info]") ? "> [!info]" : "> [!note]")
            blocks.append(MarkdownBlock(type: .calloutInfo, content: content))
            continue
        }

        // Regular blockquote
        if trimmed.hasPrefix("> ") {
            let content = collectBlockquoteContent(lines: lines, startIndex: &index, prefix: "> ")
            blocks.append(MarkdownBlock(type: .blockquote, content: content))
            continue
        }

        // Code block
        if trimmed.hasPrefix("```") {
            index += 1 // Skip opening ```
            var codeLines: [String] = []
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[index])
                index += 1
            }
            index += 1 // Skip closing ```
            blocks.append(MarkdownBlock(type: .codeBlock, content: codeLines.joined(separator: "\n")))
            continue
        }

        // Collapsible (custom syntax: <details> or :::collapse)
        if trimmed.hasPrefix("<details>") || trimmed.hasPrefix(":::collapse") {
            var title = "More Details"
            if trimmed.contains("<summary>") {
                if let summaryRange = trimmed.range(of: "<summary>"),
                   let endRange = trimmed.range(of: "</summary>") {
                    title = String(trimmed[summaryRange.upperBound..<endRange.lowerBound])
                }
            }
            index += 1
            var contentLines: [String] = []
            while index < lines.count {
                let checkLine = lines[index].trimmingCharacters(in: .whitespaces)
                if checkLine == "</details>" || checkLine == ":::" {
                    index += 1
                    break
                }
                contentLines.append(lines[index])
                index += 1
            }
            blocks.append(MarkdownBlock(type: .collapsible, content: contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), title: title))
            continue
        }

        // Image
        if trimmed.hasPrefix("![") && trimmed.contains("](") && trimmed.hasSuffix(")") {
            if let urlStart = trimmed.range(of: "]("),
               let urlEnd = trimmed.lastIndex(of: ")") {
                let url = String(trimmed[urlStart.upperBound..<urlEnd])
                blocks.append(MarkdownBlock(type: .image, content: url))
            }
            index += 1
            continue
        }

        // Bullet list
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
            var items: [String] = []
            while index < lines.count {
                let itemLine = lines[index].trimmingCharacters(in: .whitespaces)
                if itemLine.hasPrefix("- ") {
                    items.append(String(itemLine.dropFirst(2)))
                } else if itemLine.hasPrefix("* ") {
                    items.append(String(itemLine.dropFirst(2)))
                } else if itemLine.hasPrefix("• ") {
                    items.append(String(itemLine.dropFirst(2)))
                } else if !itemLine.isEmpty {
                    break
                }
                index += 1
                if itemLine.isEmpty {
                    break
                }
            }
            if !items.isEmpty {
                blocks.append(MarkdownBlock(type: .bulletList, items: items))
            }
            continue
        }

        // Numbered list
        if let firstChar = trimmed.first, firstChar.isNumber, trimmed.contains(". ") {
            var items: [String] = []
            while index < lines.count {
                let itemLine = lines[index].trimmingCharacters(in: .whitespaces)
                if let dotIndex = itemLine.firstIndex(of: "."),
                   let _ = Int(String(itemLine[..<dotIndex])) {
                    let afterDot = itemLine.index(dotIndex, offsetBy: 1)
                    if afterDot < itemLine.endIndex && itemLine[afterDot] == " " {
                        items.append(String(itemLine[itemLine.index(afterDot, offsetBy: 1)...]))
                        index += 1
                        continue
                    }
                }
                if !itemLine.isEmpty && !itemLine.first!.isNumber {
                    break
                }
                index += 1
                if itemLine.isEmpty {
                    break
                }
            }
            if !items.isEmpty {
                blocks.append(MarkdownBlock(type: .numberedList, items: items))
            }
            continue
        }

        // Regular paragraph - collect until empty line
        var paragraphLines: [String] = []
        while index < lines.count {
            let pLine = lines[index]
            let pTrimmed = pLine.trimmingCharacters(in: .whitespaces)

            // Stop at block-level elements
            if pTrimmed.isEmpty ||
               pTrimmed.hasPrefix("#") ||
               pTrimmed.hasPrefix(">") ||
               pTrimmed.hasPrefix("```") ||
               pTrimmed.hasPrefix("- ") ||
               pTrimmed.hasPrefix("* ") ||
               pTrimmed.hasPrefix("---") ||
               pTrimmed.hasPrefix("![") ||
               (pTrimmed.first?.isNumber == true && pTrimmed.contains(". ")) {
                break
            }

            paragraphLines.append(pTrimmed)
            index += 1
        }

        if !paragraphLines.isEmpty {
            blocks.append(MarkdownBlock(type: .paragraph, content: paragraphLines.joined(separator: " ")))
        }
    }

    return blocks
}

private func collectBlockquoteContent(lines: [String], startIndex: inout Int, prefix: String) -> String {
    var contentLines: [String] = []

    // Handle first line
    let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
    if firstLine.count > prefix.count {
        contentLines.append(String(firstLine.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces))
    }
    startIndex += 1

    // Continue collecting lines that start with >
    while startIndex < lines.count {
        let line = lines[startIndex].trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("> ") {
            contentLines.append(String(line.dropFirst(2)))
            startIndex += 1
        } else if line.isEmpty {
            startIndex += 1
            break
        } else {
            break
        }
    }

    return contentLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Preview

#Preview {
    ScrollView {
        MarkdownContentView(
            markdown: """
            # Understanding Protein

            Protein is one of the three **macronutrients** essential for human health.

            ## Why Protein Matters

            Your body uses protein for:
            - Building and repairing tissues
            - Making enzymes and hormones
            - Supporting immune function
            - Maintaining muscle mass

            > [!tip]
            > Try to include a source of protein at every meal to keep your energy stable throughout the day.

            ## How Much Do You Need?

            Most adults need about **0.8 grams per kilogram** of body weight daily. However, this varies based on:

            1. Activity level
            2. Age and life stage
            3. Health conditions
            4. Fitness goals

            > "Protein is the building block of life." - Research Summary

            ---

            ### Best Protein Sources

            > [!info]
            > Both animal and plant proteins can help you meet your needs. Variety is key!

            > [!warning]
            > Excessive protein intake can strain the kidneys in people with existing kidney conditions.

            ```
            Daily Target Example:
            70kg adult × 0.8g = 56g protein/day
            ```
            """,
            accentColor: .green
        )
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
