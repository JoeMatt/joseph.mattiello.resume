import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatExperienceTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }
        let contentWidth = Int(getmaxx(cw) - 10) // dynamically get width, less more padding for items
        let searchTerm = tuiState.activeSearchTerm
        let defaultColor = Cncurses.COLOR_PAIR(3)
        let headerColor = ResumeTUI.A_BOLD | defaultColor

        // Helper to add text, highlighting if a search term is active
        let addHighlightedLine = { (text: String, attribute: Int32) in
            if !searchTerm.isEmpty {
                attributedContent.append(contentsOf: highlightOccurrences(of: searchTerm, in: text, baseAttribute: attribute, highlightAttribute: A_HIGHLIGHT | attribute))
            } else {
                attributedContent.append((text, attribute))
            }
        }

        addHighlightedLine("\n  WORK EXPERIENCE\n", headerColor)
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", defaultColor) )

        for job in resume.experience {
            addHighlightedLine("  \(job.title) at \(job.company)\n", headerColor)
            let period = "\(job.startDate) - \(job.endDate ?? "Present")"
            addHighlightedLine("    \(period) | \(job.location)\n", defaultColor)

            if !job.responsibilities.isEmpty {
                addHighlightedLine("    Key Responsibilities:\n", headerColor)
                for resp in job.responsibilities {
                    let wrappedResp = wrapText("- " + resp, indent: 6, width: contentWidth) + "\n"
                    addHighlightedLine(wrappedResp, defaultColor)
                }
                attributedContent.append( ("\n", defaultColor) ) // Space after responsibilities
            }

            attributedContent.append( ("\n  " + String(repeating: "·", count: contentWidth - 4) + "\n\n", defaultColor) )
        }

        return attributedContent
    }

    @MainActor
    static func getRawExperienceLines(resume: Resume) -> [String] {
        var lines: [String] = []

        for job in resume.experience {
            lines.append("\(job.title) at \(job.company)")
            let period = "\(job.startDate) - \(job.endDate ?? "Present")"
            lines.append("\(period) | \(job.location)")

            if !job.responsibilities.isEmpty {
                lines.append("Key Responsibilities:") // Optional: include this header or not
                for resp in job.responsibilities {
                    lines.append(resp) // Each responsibility as a separate line
                }
            }
        }
        // Filter out any empty lines that might have been added
        return lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
