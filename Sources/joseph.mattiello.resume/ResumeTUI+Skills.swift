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

        // Column settings
        let minWidthForTwoColumns = 80 // Minimum terminal width to attempt two columns
        let gutter = "    |    " // 4 spaces, pipe, 4 spaces
        let progressBarWidth = 15 // Width for the progress bar itself
        let ratingTextWidth = 7 // For " (x/5)"

        // Title
        attributedContent.append((leftPadding + "TECHNICAL SKILLS\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)))
        attributedContent.append((leftPadding + String(repeating: "─", count: contentWidth - (leftPadding.count * 2)) + "\n", Cncurses.COLOR_PAIR(3)))

        if contentWidth >= minWidthForTwoColumns {
            // Two-column layout
            let availableWidth = contentWidth - leftPadding.count // Width available after initial padding
            let columnWidth = (availableWidth - gutter.count - (leftPadding.count * 2)) / 2 // Adjusted for padding around gutter
            let maxNameWidth = columnWidth - progressBarWidth - ratingTextWidth - 1 // -1 for a space

            // Titles with adjusted padding for centering within columns
            let langTitle = "PROGRAMMING LANGUAGES"
            let sdkTitle = "SDKS & APIS"
            let langTitlePadding = max(0, (columnWidth - langTitle.count) / 2)
            let sdkTitlePadding = max(0, (columnWidth - sdkTitle.count) / 2)

            attributedContent.append((leftPadding +
                                       String(repeating: " ", count: langTitlePadding) + langTitle +
                                       String(repeating: " ", count: columnWidth - langTitle.count - langTitlePadding) +
                                       gutter +
                                       String(repeating: " ", count: sdkTitlePadding) + sdkTitle +
                                       // String(repeating: " ", count: columnWidth - sdkTitle.count - sdkTitlePadding) + // No end padding needed for last item
                                       "\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)))

            // Underlines for titles
            attributedContent.append((leftPadding +
                                       String(repeating: " ", count: langTitlePadding) + String(repeating: "─", count: langTitle.count) +
                                       String(repeating: " ", count: columnWidth - langTitle.count - langTitlePadding) +
                                       gutter +
                                       String(repeating: " ", count: sdkTitlePadding) + String(repeating: "─", count: sdkTitle.count) +
                                       "\n\n", Cncurses.COLOR_PAIR(3))) // Added \n for spacing


            let maxRows = max(sortedLanguages.count, sortedSDKs.count)

            for i in 0..<maxRows {
                var langAttr: [(String, Int32)] = []
                var sdkAttr: [(String, Int32)] = []

                // Left column (Languages)
                if i < sortedLanguages.count {
                    let lang = sortedLanguages[i]
                    let bar = drawProgressBar(current: lang.rating, maxVal: 5, width: progressBarWidth)
                    let namePart = lang.name.padding(toLength: maxNameWidth, withPad: " ", startingAt: 0)
                    langAttr.append( ("\(namePart) ", Cncurses.COLOR_PAIR(3)) )
                    langAttr.append( ("\(bar) ", Cncurses.COLOR_PAIR(5)) )
                    langAttr.append( ("(\(lang.rating)/5)".padding(toLength: ratingTextWidth, withPad: " ", startingAt: 0), Cncurses.COLOR_PAIR(3)) )
                } else {
                    // Pad empty rows in the left column if languages list is shorter
                    langAttr.append( (String(repeating: " ", count: columnWidth), Cncurses.COLOR_PAIR(3)) )
                }

                // Right column (SDKs)
                if i < sortedSDKs.count {
                    let sdk = sortedSDKs[i]
                    let bar = drawProgressBar(current: sdk.rating, maxVal: 5, width: progressBarWidth)
                    let namePart = sdk.name.padding(toLength: maxNameWidth, withPad: " ", startingAt: 0)
                    sdkAttr.append( ("\(namePart) ", Cncurses.COLOR_PAIR(3)) )
                    sdkAttr.append( ("\(bar) ", Cncurses.COLOR_PAIR(5)) )
                    sdkAttr.append( ("(\(sdk.rating)/5)".padding(toLength: ratingTextWidth, withPad: " ", startingAt: 0), Cncurses.COLOR_PAIR(3)) )
                } else {
                     // Pad empty rows in the right column if SDKs list is shorter
                    sdkAttr.append( (String(repeating: " ", count: columnWidth), Cncurses.COLOR_PAIR(3)) )
                }

                // Combine attributed strings for the line
                attributedContent.append((leftPadding, Cncurses.COLOR_PAIR(3))) // Initial padding for the line
                attributedContent.append(contentsOf: langAttr)
                attributedContent.append((gutter, Cncurses.COLOR_PAIR(3)))
                attributedContent.append(contentsOf: sdkAttr)
                attributedContent.append( ("\n", Cncurses.COLOR_PAIR(3)) ) // Newline at the end of the row
            }

        } else {
            // Single-column layout (fallback if terminal is too narrow)
            let singleColumnNameWidth = contentWidth - progressBarWidth - ratingTextWidth - leftPadding.count - 4 // Adjusted for padding and rating

            attributedContent.append((leftPadding + "PROGRAMMING LANGUAGES\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)))
            attributedContent.append((leftPadding + String(repeating: "─", count: "PROGRAMMING LANGUAGES".count) + "\n\n", Cncurses.COLOR_PAIR(3)))
            for lang in sortedLanguages {
                let bar = drawProgressBar(current: lang.rating, maxVal: 5, width: progressBarWidth)
                attributedContent.append((leftPadding + "  \(lang.name.padding(toLength: singleColumnNameWidth, withPad: " ", startingAt: 0)) ", Cncurses.COLOR_PAIR(3)))
                attributedContent.append( ("\(bar) ", Cncurses.COLOR_PAIR(5)) )
                attributedContent.append( ("(\(lang.rating)/5)\n", Cncurses.COLOR_PAIR(3)) )
            }
            attributedContent.append( ("\n", Cncurses.COLOR_PAIR(3)) )

            attributedContent.append((leftPadding + "SDKS & APIS\n", ResumeTUI.A_BOLD | Cncurses.COLOR_PAIR(3)))
            attributedContent.append((leftPadding + String(repeating: "─", count: "SDKS & APIS".count) + "\n\n", Cncurses.COLOR_PAIR(3)))
            for sdk in sortedSDKs {
                let bar = drawProgressBar(current: sdk.rating, maxVal: 5, width: progressBarWidth)
                attributedContent.append((leftPadding + "  \(sdk.name.padding(toLength: singleColumnNameWidth, withPad: " ", startingAt: 0)) ", Cncurses.COLOR_PAIR(3)))
                attributedContent.append( ("\(bar) ", Cncurses.COLOR_PAIR(5)) )
                attributedContent.append( ("(\(sdk.rating)/5)\n", Cncurses.COLOR_PAIR(3)) )
            }
        }
        attributedContent.append( ("\n", Cncurses.COLOR_PAIR(3)) )
        return attributedContent
    }
}
