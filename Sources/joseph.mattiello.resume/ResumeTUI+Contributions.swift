import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatContributionsTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }
        let contentWidth = Int(getmaxx(cw) - 10)
        let searchTerm = tuiState.activeSearchTerm
        let defaultColor = Cncurses.COLOR_PAIR(3)
        let headerColor = ResumeTUI.A_BOLD | defaultColor
        let urlColor = Cncurses.COLOR_PAIR(4) | ResumeTUI.A_UNDERLINE

        // Helper to add text, highlighting if a search term is active
        let addHighlightedLine = { (text: String, attribute: Int32) in
            if !searchTerm.isEmpty {
                attributedContent.append(contentsOf: highlightOccurrences(of: searchTerm, in: text, baseAttribute: attribute, highlightAttribute: A_HIGHLIGHT | attribute))
            } else {
                attributedContent.append((text, attribute))
            }
        }

        addHighlightedLine("\n  OPEN SOURCE CONTRIBUTIONS\n", headerColor)
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", defaultColor) )

        for contrib in resume.openSourceContributions {
            addHighlightedLine("  \(contrib.name)\n", headerColor)
            if let technologies = contrib.technologies, !technologies.isEmpty {
                 attributedContent.append( ("    Technologies: ", defaultColor) )
                 addHighlightedLine("\(technologies.joined(separator: ", "))\n", defaultColor)
            }
            if let description = contrib.description {
                let wrappedDesc = wrapText(description, indent: 4, width: contentWidth) + "\n"
                addHighlightedLine(wrappedDesc, defaultColor)
            }

            if let link = contrib.links?.first { // Get the first link's URL
                let url = link.url
                attributedContent.append( ("    URL: ", defaultColor) )
                addHighlightedLine("\(url)\n", urlColor)
            }
            attributedContent.append( ("\n  " + String(repeating: "·", count: contentWidth - 4) + "\n\n", defaultColor) )
        }
        return attributedContent
    }

    @MainActor
    static func getRawContributionsLines(resume: Resume) -> [String] {
        var lines: [String] = []
        for contrib in resume.openSourceContributions {
            lines.append(contrib.name)
            if let technologies = contrib.technologies, !technologies.isEmpty {
                lines.append(technologies.joined(separator: ", "))
            }
            if let description = contrib.description {
                lines.append(contentsOf: description.components(separatedBy: "\n"))
            }
            if let link = contrib.links?.first {
                lines.append(link.url)
            }
        }
        return lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
