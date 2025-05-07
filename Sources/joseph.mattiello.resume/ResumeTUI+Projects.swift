import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatProjectsTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }
        let contentWidth = Int(getmaxx(cw) - 10)

        attributedContent.append( ("\n  PERSONAL PROJECTS\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", Cncurses.COLOR_PAIR(3)) )

        for project in resume.personalProjects {
            attributedContent.append( ("  \(project.name)\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
            // if let period = project.period {
            //     attributedContent.append( ("    Period: \(period)\n", Cncurses.COLOR_PAIR(3)) )
            // }
            if let technologies = project.technologies, !technologies.isEmpty {
                attributedContent.append( ("    Technologies: \(technologies.joined(separator: ", "))\n", Cncurses.COLOR_PAIR(3)) )
            }
            if let description = project.description {
                attributedContent.append( (wrapText(description, indent: 4, width: contentWidth) + "\n", Cncurses.COLOR_PAIR(3)) )
            }

            if let link = project.links?.first { // Get the first link's URL
                let url = link.url
                attributedContent.append( ("    URL: ", Cncurses.COLOR_PAIR(3)) )
                attributedContent.append( ("\(url)\n", Cncurses.COLOR_PAIR(4) | ResumeTUI.A_UNDERLINE) )
            }
            attributedContent.append( ("\n  " + String(repeating: "·", count: contentWidth - 4) + "\n\n", Cncurses.COLOR_PAIR(3)) )
        }
        return attributedContent
    }
}
