import Foundation
import Cncurses

extension ResumeTUI {
    @MainActor
    static func formatSkillsTab(resume: Resume) -> [(String, Int32)] {
        var attributedContent: [(String, Int32)] = []
        guard let cw = tuiState.contentWin else { return [] }
        let searchTerm = tuiState.activeSearchTerm
        let defaultColor = Cncurses.COLOR_PAIR(3)
        let headerColor = ResumeTUI.A_BOLD | defaultColor
        let starColor = Cncurses.COLOR_PAIR(5)

        // Helper to add text, highlighting if a search term is active
        let addHighlightedLine = { (text: String, attribute: Int32) in
            if !searchTerm.isEmpty {
                attributedContent.append(contentsOf: highlightOccurrences(of: searchTerm, in: text, baseAttribute: attribute, highlightAttribute: A_HIGHLIGHT | attribute))
            } else {
                attributedContent.append((text, attribute))
            }
        }

        let contentWidth = Int(getmaxx(cw))
        let leftPadding = "  " // Two spaces for overall left padding

        let sortedLanguages = resume.skills.programmingLanguages
            .sorted { ($0.rating, $1.name) > ($1.rating, $0.name) }
        let sortedSDKs = resume.skills.sdksApis
            .sorted { ($0.rating, $1.name) > ($1.rating, $0.name) }

        let starWidth = 10
        let ratingTextWidth = 5
        let nameWidth = contentWidth - starWidth - ratingTextWidth - leftPadding.count - 4

        addHighlightedLine(leftPadding + "TECHNICAL SKILLS\n", headerColor)
        attributedContent.append((leftPadding + String(repeating: "─", count: contentWidth - (leftPadding.count * 2)) + "\n\n", defaultColor))

        addHighlightedLine(leftPadding + "PROGRAMMING LANGUAGES\n", headerColor)
        attributedContent.append((leftPadding + String(repeating: "─", count: "PROGRAMMING LANGUAGES".count) + "\n\n", defaultColor))

        for lang in sortedLanguages {
            let namePart = lang.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            addHighlightedLine(leftPadding + namePart + " ", defaultColor)

            let stars = String(repeating: "★", count: lang.rating) +
                        String(repeating: "☆", count: 5 - lang.rating)
            attributedContent.append((stars + " ", starColor))
            attributedContent.append(("(\(lang.rating)/5)\n", defaultColor))
        }

        attributedContent.append(("\n", defaultColor))

        addHighlightedLine(leftPadding + "SDKS & APIS\n", headerColor)
        attributedContent.append((leftPadding + String(repeating: "─", count: "SDKS & APIS".count) + "\n\n", defaultColor))

        for sdk in sortedSDKs {
            let namePart = sdk.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            addHighlightedLine(leftPadding + namePart + " ", defaultColor)

            let stars = String(repeating: "★", count: sdk.rating) +
                        String(repeating: "☆", count: 5 - sdk.rating)
            attributedContent.append((stars + " ", starColor))
            attributedContent.append(("(\(sdk.rating)/5)\n", defaultColor))
        }

        attributedContent.append(("\n", defaultColor))
        return attributedContent
    }

    @MainActor
    static func getRawSkillsLines(resume: Resume) -> [String] {
        var lines: [String] = []

        // Programming Languages
        for lang in resume.skills.programmingLanguages {
            lines.append(lang.name)
        }

        // SDKs & APIs
        for sdk in resume.skills.sdksApis {
            lines.append(sdk.name)
        }
        
        // Tools & Technologies (if you add this to your Resume model and want to search it)
        // for tool in resume.skills.toolsAndTechnologies {
        //     lines.append(tool.name)
        // }

        // Filter out any empty lines that might have been added and remove duplicates
        return Array(Set(lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }
}
