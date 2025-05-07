import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatOverviewTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }
        let contentWidth = Int(getmaxx(cw) - 6)

        attributedContent.append( ("\n  \(resume.name)\n\n", ResumeTUI.A_BOLD) )

        attributedContent.append( ("  CONTACT INFORMATION\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n", Cncurses.COLOR_PAIR(3)) )
        if let email = resume.contact.email {
            attributedContent.append( ("  Email: ", Cncurses.COLOR_PAIR(3)) )
            attributedContent.append( ("\(email)\n", Cncurses.COLOR_PAIR(4)) )
        }
        if let phone = resume.contact.phone {
            attributedContent.append( ("  Phone: \(phone)\n", Cncurses.COLOR_PAIR(3)) )
        }
        if let website = resume.contact.website {
            attributedContent.append( ("  Website: ", Cncurses.COLOR_PAIR(3)) )
            attributedContent.append( ("\(website)\n", Cncurses.COLOR_PAIR(4)) )
        }
        if let linkedin = resume.contact.linkedin {
            attributedContent.append( ("  LinkedIn: ", Cncurses.COLOR_PAIR(3)) )
            attributedContent.append( ("https://linkedin.com/in/\(linkedin)\n", Cncurses.COLOR_PAIR(4)) )
        }
        if let github = resume.contact.github {
            attributedContent.append( ("  GitHub: ", Cncurses.COLOR_PAIR(3)) )
            attributedContent.append( ("https://github.com/\(github)\n", Cncurses.COLOR_PAIR(4)) )
        }
        attributedContent.append( ("\n", Cncurses.COLOR_PAIR(3)) ) // Extra space

        // Profile/Summary
        attributedContent.append( ("  PROFESSIONAL SUMMARY\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( (wrapText(resume.profile, indent: 2, width: contentWidth) + "\n", Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( ("\n", Cncurses.COLOR_PAIR(3)) ) // Extra space

        // Education
        attributedContent.append( ("  EDUCATION\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", Cncurses.COLOR_PAIR(3)) )

        for edu in resume.education {
            attributedContent.append( ("  \(edu.degree)\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
            attributedContent.append( ("    \(edu.institution)\n", Cncurses.COLOR_PAIR(3)) ) // Removed edu.location
            attributedContent.append( ("    \(edu.graduationYear ?? "N/A")\n\n", Cncurses.COLOR_PAIR(3)) )
        }

        // Skills Section (Summary - Top 5 Programming Languages and SDKs/APIs)
        attributedContent.append( ("\n  KEY SKILLS SUMMARY\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", Cncurses.COLOR_PAIR(3)) )

        // Top 5 Programming Languages (example, adjust as needed)
        attributedContent.append( ("    Top Programming Languages:\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(4)) )
        let sortedLanguages = resume.skills.programmingLanguages.sorted { $0.rating > $1.rating }.prefix(5)

        for language in sortedLanguages {
            attributedContent.append( ("    \(language.name.padding(toLength: 25, withPad: " ", startingAt: 0)) ", Cncurses.COLOR_PAIR(3)) ) // Increased padding
            attributedContent.append( ("\(String(repeating: "★", count: language.rating))\(String(repeating: "☆", count: 5 - language.rating))\n", Cncurses.COLOR_PAIR(5)) )
        }

        // Top 5 SDKs/APIs (example, adjust as needed)
        attributedContent.append( ("\n    Top SDKs/APIs:\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(4)) )
        let sortedSDKs = resume.skills.sdksApis.sorted { $0.rating > $1.rating }.prefix(5)

        for (_, sdk) in sortedSDKs.enumerated() { // Replaced index with _
            attributedContent.append( ("    \(sdk.name.padding(toLength: 25, withPad: " ", startingAt: 0)) ", Cncurses.COLOR_PAIR(3)) ) // Increased padding
            attributedContent.append( ("\(String(repeating: "★", count: sdk.rating))\(String(repeating: "☆", count: 5 - sdk.rating))\n", Cncurses.COLOR_PAIR(5)) )
        }
        attributedContent.append( ("\n", Cncurses.COLOR_PAIR(3)) ) // Extra space

        return attributedContent
    }
}
