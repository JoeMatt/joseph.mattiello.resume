import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatProjectsTab(resume: Resume) -> [(String, Int32)] {
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

        addHighlightedLine("\n  PERSONAL PROJECTS\n", headerColor)
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", defaultColor) )

        for project in resume.personalProjects {
            addHighlightedLine("  \(project.name)\n", headerColor)

            if let technologies = project.technologies, !technologies.isEmpty {
                attributedContent.append( ("    Technologies: ", defaultColor) )
                addHighlightedLine("\(technologies.joined(separator: ", "))\n", defaultColor)
            }
            if let description = project.description {
                let wrappedDesc = wrapText(description, indent: 4, width: contentWidth) + "\n"
                addHighlightedLine(wrappedDesc, defaultColor)
            }

            if let link = project.links?.first { // Get the first link's URL
                let url = link.url
                attributedContent.append( ("    URL: ", defaultColor) )
                addHighlightedLine("\(url)\n", urlColor)
            }
            attributedContent.append( ("\n  " + String(repeating: "·", count: contentWidth - 4) + "\n\n", defaultColor) )
        }
        return attributedContent
    }

    @MainActor
    static func getRawProjectsLines(resume: Resume) -> [String] {
        var lines: [String] = []
        for project in resume.personalProjects {
            lines.append(project.name)
            if let technologies = project.technologies, !technologies.isEmpty {
                lines.append(technologies.joined(separator: ", ")) // Join technologies for a single searchable line
                // Alternatively, add each technology as a separate line if preferred:
                // lines.append(contentsOf: technologies)
            }
            if let description = project.description {
                // Split description by newlines in case it's multi-line in the YAML
                lines.append(contentsOf: description.components(separatedBy: "\n"))
            }
            if let link = project.links?.first { // Get the first link's URL
                lines.append(link.url)
            }
        }
        return lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
