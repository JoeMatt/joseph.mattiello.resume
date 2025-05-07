import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatContributionsTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }
        let contentWidth = Int(getmaxx(cw) - 10)

        attributedContent.append( ("\n  OPEN SOURCE CONTRIBUTIONS\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", Cncurses.COLOR_PAIR(3)) )

        for contrib in resume.openSourceContributions {
            attributedContent.append( ("  \(contrib.name)\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
            if let technologies = contrib.technologies, !technologies.isEmpty {
                 attributedContent.append( ("    Technologies: \(technologies.joined(separator: ", "))\n", Cncurses.COLOR_PAIR(3)) )
            }
            if let description = contrib.description {
                attributedContent.append( (wrapText(description, indent: 4, width: contentWidth) + "\n", Cncurses.COLOR_PAIR(3)) )
            }

            if let link = contrib.links?.first { // Get the first link's URL
                let url = link.url
                attributedContent.append( ("    URL: ", Cncurses.COLOR_PAIR(3)) )
                attributedContent.append( ("\(url)\n", Cncurses.COLOR_PAIR(4) | ResumeTUI.A_UNDERLINE) )
            }
            attributedContent.append( ("\n  " + String(repeating: "·", count: contentWidth - 4) + "\n\n", Cncurses.COLOR_PAIR(3)) )
        }
        return attributedContent
    }
}
