import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatOverviewTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }
        let contentWidth = Int(getmaxx(cw) - 6)
        let searchTerm = tuiState.activeSearchTerm
        let defaultColor = Cncurses.COLOR_PAIR(3)
        let valueColor = Cncurses.COLOR_PAIR(4)
        let headerColor = ResumeTUI.A_BOLD | defaultColor
        let skillRatingColor = Cncurses.COLOR_PAIR(5)

        // Helper to add text, highlighting if a search term is active
        let addHighlightedLine = { (text: String, attribute: Int32) in
            if !searchTerm.isEmpty {
                attributedContent.append(contentsOf: ResumeTUI.highlightOccurrences(of: searchTerm, in: text, baseAttribute: attribute, highlightAttribute: ResumeTUI.A_HIGHLIGHT | attribute))
            } else {
                attributedContent.append((text, attribute))
            }
        }

        // Name
        addHighlightedLine("\n  \(resume.name)\n\n", ResumeTUI.A_BOLD)

        attributedContent.append( ("  CONTACT INFORMATION\n", headerColor) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n", defaultColor) )
        if let email = resume.contact.email {
            attributedContent.append( ("  Email: ", defaultColor) )
            addHighlightedLine("\(email)\n", valueColor)
        }
        if let phone = resume.contact.phone {
            addHighlightedLine("  Phone: \(phone)\n", defaultColor)
        }
        if let website = resume.contact.website {
            attributedContent.append( ("  Website: ", defaultColor) )
            addHighlightedLine("\(website)\n", valueColor)
        }
        if let linkedin = resume.contact.linkedin {
            attributedContent.append( ("  LinkedIn: ", defaultColor) )
            addHighlightedLine("\(linkedin)\n", valueColor)
        }
        if let github = resume.contact.github {
            attributedContent.append( ("  GitHub: ", defaultColor) )
            addHighlightedLine("\(github)\n", valueColor)
        }
        attributedContent.append( ("\n", defaultColor) ) // Extra space

        // Profile/Summary
        attributedContent.append( ("  PROFESSIONAL SUMMARY\n", headerColor) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", defaultColor) )
        let profileText = ResumeTUI.wrapText(resume.profile, indent: 2, width: contentWidth) + "\n"
        addHighlightedLine(profileText, defaultColor)
        attributedContent.append( ("\n", defaultColor) ) // Extra space

        // Education
        attributedContent.append( ("  EDUCATION\n", headerColor) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", defaultColor) )

        for edu in resume.education {
            addHighlightedLine("  \(edu.degree)\n", ResumeTUI.A_BOLD | defaultColor)
            addHighlightedLine("    \(edu.institution)\n", defaultColor)
            addHighlightedLine("    \(edu.graduationYear ?? "N/A")\n\n", defaultColor)
        }

        // Skills Section (Summary - Top 5 Programming Languages and SDKs/APIs)
        attributedContent.append( ("\n  KEY SKILLS SUMMARY\n", headerColor) )
        attributedContent.append( ("  " + String(repeating: "─", count: 30) + "\n\n", defaultColor) )

        attributedContent.append( ("    Top Programming Languages:\n", ResumeTUI.A_BOLD | valueColor) )
        let sortedLanguages = resume.skills.programmingLanguages.sorted { $0.rating > $1.rating }.prefix(5)

        for language in sortedLanguages {
            let langText = "    \(language.name.padding(toLength: 25, withPad: " ", startingAt: 0)) "
            // Rating stars should not be highlighted by search term
            let ratingText = "\(String(repeating: "★", count: language.rating))\(String(repeating: "☆", count: 5 - language.rating))\n"
            addHighlightedLine(langText, defaultColor)
            attributedContent.append((ratingText, skillRatingColor))
        }

        attributedContent.append( ("\n    Top SDKs/APIs:\n", ResumeTUI.A_BOLD | valueColor) )
        let sortedSDKs = resume.skills.sdksApis.sorted { $0.rating > $1.rating }.prefix(5)

        for sdk in sortedSDKs {
            let sdkText = "    \(sdk.name.padding(toLength: 25, withPad: " ", startingAt: 0)) "
            // Rating stars should not be highlighted by search term
            let ratingText = "\(String(repeating: "★", count: sdk.rating))\(String(repeating: "☆", count: 5 - sdk.rating))\n"
            addHighlightedLine(sdkText, defaultColor)
            attributedContent.append((ratingText, skillRatingColor))
        }
        attributedContent.append( ("\n", defaultColor) ) // Extra space

        return attributedContent
    }

    @MainActor
    static func getRawOverviewLines(resume: Resume) -> [String] {
        var lines: [String] = []

        lines.append(resume.name)

        if let email = resume.contact.email {
            lines.append("Email: \(email)")
        }
        if let phone = resume.contact.phone {
            lines.append("Phone: \(phone)")
        }
        if let website = resume.contact.website {
            lines.append("Website: \(website)")
        }
        if let linkedin = resume.contact.linkedin {
            lines.append("LinkedIn: \(linkedin)")
        }
        if let github = resume.contact.github {
            lines.append("GitHub: \(github)")
        }

        // Add profile summary, splitting by newlines if it's multi-line
        lines.append(contentsOf: resume.profile.components(separatedBy: "\n"))

        for edu in resume.education {
            lines.append("\(edu.degree)")
            lines.append("\(edu.institution)")
            if let year = edu.graduationYear {
                lines.append("\(year)")
            }
        }

        // Key skills summary (just names)
        let topLanguages = resume.skills.programmingLanguages.sorted { $0.rating > $1.rating }.prefix(5)
        for lang in topLanguages {
            lines.append(lang.name)
        }

        let topSDKs = resume.skills.sdksApis.sorted { $0.rating > $1.rating }.prefix(5)
        for sdk in topSDKs {
            lines.append(sdk.name)
        }

        // Filter out any empty lines that might have been added
        return lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
