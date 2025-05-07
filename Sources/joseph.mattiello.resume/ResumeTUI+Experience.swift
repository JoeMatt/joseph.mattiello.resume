import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatExperienceTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }
        let contentWidth = Int(getmaxx(cw) - 10) // dynamically get width, less more padding for items

        attributedContent.append( ("\n  WORK EXPERIENCE\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", Cncurses.COLOR_PAIR(3)) )

        for job in resume.experience {
            attributedContent.append( ("  \(job.title) at \(job.company)\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
            let period = "\(job.startDate) - \(job.endDate ?? "Present")"
            attributedContent.append( ("    \(period) | \(job.location)\n", Cncurses.COLOR_PAIR(3)) ) // Removed ?? "" as job.location is not optional
            // if !job.description.isEmpty { // 'description' field doesn't exist in Experience model
            //     attributedContent.append( ("    \(wrapText(job.description, indent: 4, width: contentWidth))\n", Cncurses.COLOR_PAIR(3)) )
            // }
            if !job.responsibilities.isEmpty {
                attributedContent.append( ("    Key Responsibilities:\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
                for resp in job.responsibilities {
                    attributedContent.append( (wrapText("- " + resp, indent: 6, width: contentWidth) + "\n", Cncurses.COLOR_PAIR(3)) )
                }
                attributedContent.append( ("\n", Cncurses.COLOR_PAIR(3)) ) // Space after responsibilities
            }

            attributedContent.append( ("\n  " + String(repeating: "·", count: contentWidth - 4) + "\n\n", Cncurses.COLOR_PAIR(3)) )
        }

        return attributedContent
    }
}
