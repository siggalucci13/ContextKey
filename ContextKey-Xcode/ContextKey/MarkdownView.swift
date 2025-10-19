import SwiftUI

struct MarkdownText: View {
    let content: String
    let colorScheme: ColorSchemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdown(content), id: \.id) { block in
                block.view(colorScheme: colorScheme)
            }
        }
    }

    private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var currentText = ""
        var inCodeBlock = false
        var codeLanguage = ""
        var codeContent = ""

        let lines = text.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Check for code block start
            if line.hasPrefix("```") {
                // Save any accumulated text
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }

                if inCodeBlock {
                    // End of code block
                    blocks.append(.code(language: codeLanguage, content: codeContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                    codeContent = ""
                    codeLanguage = ""
                    inCodeBlock = false
                } else {
                    // Start of code block
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    inCodeBlock = true
                }
            } else if inCodeBlock {
                codeContent += line + "\n"
            } else {
                currentText += line + "\n"
            }

            i += 1
        }

        // Add remaining text
        if !currentText.isEmpty {
            blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return blocks
    }
}

enum MarkdownBlock: Identifiable {
    case text(String)
    case code(language: String, content: String)

    var id: String {
        switch self {
        case .text(let content):
            return "text-\(content.hashValue)"
        case .code(let language, let content):
            return "code-\(language)-\(content.hashValue)"
        }
    }

    @ViewBuilder
    func view(colorScheme: ColorSchemeManager) -> some View {
        switch self {
        case .text(let content):
            InlineMarkdownText(content: content, colorScheme: colorScheme)
        case .code(let language, let content):
            CodeBlockView(language: language, content: content, colorScheme: colorScheme)
        }
    }
}

struct InlineMarkdownText: View {
    let content: String
    let colorScheme: ColorSchemeManager

    var body: some View {
        Text(parseInlineMarkdown(content))
            .foregroundColor(colorScheme.text)
            .textSelection(.enabled)
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        // Use built-in markdown parser
        var result: AttributedString
        do {
            result = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnly))
        } catch {
            // Fallback to plain text if markdown parsing fails
            result = AttributedString(text)
        }

        // Set base text color
        result.foregroundColor = colorScheme.isDarkMode ? .white : .black

        // Apply custom styling to inline code (add grey background)
        var currentIndex = result.startIndex
        while currentIndex < result.endIndex {
            let nextIndex = result.index(afterCharacter: currentIndex)

            // Check if this is inline code (has monospaced font from markdown parser)
            if let font = result[currentIndex..<nextIndex].inlinePresentationIntent,
               font.contains(.code) {
                // Apply custom background for inline code
                result[currentIndex..<nextIndex].backgroundColor = colorScheme.isDarkMode ? Color(white: 0.2) : Color(white: 0.9)
                result[currentIndex..<nextIndex].foregroundColor = colorScheme.isDarkMode ? Color.white : Color.black
            }

            currentIndex = nextIndex
        }

        return result
    }
}

struct CodeBlockView: View {
    let language: String
    let content: String
    let colorScheme: ColorSchemeManager
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(.caption)
                    .foregroundColor(colorScheme.secondaryText)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .foregroundColor(showCopied ? .green : colorScheme.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(colorScheme.isDarkMode ? Color(white: 0.15) : Color(white: 0.92))

            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: true) {
                SyntaxHighlightedText(content: content, language: language, colorScheme: colorScheme)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(colorScheme.isDarkMode ? Color(white: 0.1) : Color(white: 0.95))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorScheme.border, lineWidth: 1)
        )
    }
}

struct SyntaxHighlightedText: View {
    let content: String
    let language: String
    let colorScheme: ColorSchemeManager

    var body: some View {
        Text(highlightSyntax())
            .foregroundColor(colorScheme.text)
    }

    private func highlightSyntax() -> AttributedString {
        var result = AttributedString(content)

        // Define color scheme
        let keywordColor: Color = .purple
        let stringColor: Color = .red
        let commentColor: Color = .green
        let numberColor: Color = .blue
        let functionColor: Color = .cyan

        // Common keywords across languages
        let keywords = [
            "func", "function", "def", "class", "struct", "enum", "var", "let", "const",
            "if", "else", "for", "while", "return", "import", "from", "as", "try", "catch",
            "switch", "case", "break", "continue", "in", "public", "private", "static",
            "async", "await", "throw", "throws", "guard", "override", "self", "this",
            "true", "false", "nil", "null", "void", "int", "string", "bool", "float", "double"
        ]

        // Highlight strings (simple approach)
        highlightPattern(in: &result, pattern: "\"[^\"]*\"", color: stringColor)
        highlightPattern(in: &result, pattern: "'[^']*'", color: stringColor)

        // Highlight comments
        highlightPattern(in: &result, pattern: "//.*", color: commentColor)
        highlightPattern(in: &result, pattern: "#.*", color: commentColor)

        // Highlight numbers
        highlightPattern(in: &result, pattern: "\\b\\d+\\b", color: numberColor)

        // Highlight keywords
        for keyword in keywords {
            highlightPattern(in: &result, pattern: "\\b\(keyword)\\b", color: keywordColor)
        }

        return result
    }

    private func highlightPattern(in text: inout AttributedString, pattern: String, color: Color) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let nsString = String(text.characters) as NSString
        let matches = regex.matches(in: String(text.characters), range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            if let range = Range(match.range, in: String(text.characters)) {
                let startIndex = text.index(text.startIndex, offsetByCharacters: range.lowerBound.utf16Offset(in: String(text.characters)))
                let endIndex = text.index(text.startIndex, offsetByCharacters: range.upperBound.utf16Offset(in: String(text.characters)))
                text[startIndex..<endIndex].foregroundColor = color
            }
        }
    }
}
