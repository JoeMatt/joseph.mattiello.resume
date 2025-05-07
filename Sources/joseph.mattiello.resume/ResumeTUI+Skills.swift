import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatSkillsTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }

        let contentWidth = Int(getmaxx(cw))
        let leftPadding = "  " // Two spaces for overall left padding

        // Get sorted skills
        let sortedLanguages = resume.skills.programmingLanguages
            .sorted { ($0.rating, $1.name) > ($1.rating, $0.name) }
        let sortedSDKs = resume.skills.sdksApis
            .sorted { ($0.rating, $1.name) > ($1.rating, $0.name) }

        // Rating settings
        let starWidth = 10 // Width for the stars (★★★★★)
        let ratingTextWidth = 5 // For " (x/5)"
        let nameWidth = contentWidth - starWidth - ratingTextWidth - leftPadding.count - 4 // Adjusted for padding

        // Main title
        attributedContent.append((leftPadding + "TECHNICAL SKILLS\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)))
        attributedContent.append((leftPadding + String(repeating: "─", count: contentWidth - (leftPadding.count * 2)) + "\n\n", Cncurses.COLOR_PAIR(3)))

        // Programming Languages section
        attributedContent.append((leftPadding + "PROGRAMMING LANGUAGES\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)))
        attributedContent.append((leftPadding + String(repeating: "─", count: "PROGRAMMING LANGUAGES".count) + "\n\n", Cncurses.COLOR_PAIR(3)))

        // Create a grid for Programming Languages
        for lang in sortedLanguages {
            let namePart = lang.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            attributedContent.append((leftPadding + namePart + " ", Cncurses.COLOR_PAIR(3)))

            // Draw star rating
            let stars = String(repeating: "★", count: lang.rating) +
                        String(repeating: "☆", count: 5 - lang.rating)
            attributedContent.append((stars + " ", Cncurses.COLOR_PAIR(5)))

            // Rating text
            attributedContent.append(("(\(lang.rating)/5)\n", Cncurses.COLOR_PAIR(3)))
        }

        // Spacing between sections
        attributedContent.append(("\n", Cncurses.COLOR_PAIR(3)))

        // SDKs & APIs section
        attributedContent.append((leftPadding + "SDKS & APIS\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)))
        attributedContent.append((leftPadding + String(repeating: "─", count: "SDKS & APIS".count) + "\n\n", Cncurses.COLOR_PAIR(3)))

        // Create a grid for SDKs & APIs
        for sdk in sortedSDKs {
            let namePart = sdk.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            attributedContent.append((leftPadding + namePart + " ", Cncurses.COLOR_PAIR(3)))

            // Draw star rating
            let stars = String(repeating: "★", count: sdk.rating) +
                        String(repeating: "☆", count: 5 - sdk.rating)
            attributedContent.append((stars + " ", Cncurses.COLOR_PAIR(5)))

            // Rating text
            attributedContent.append(("(\(sdk.rating)/5)\n", Cncurses.COLOR_PAIR(3)))
        }

        attributedContent.append(("\n", Cncurses.COLOR_PAIR(3)))
        return attributedContent
    }
}
