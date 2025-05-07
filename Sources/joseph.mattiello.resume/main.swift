import Foundation
import Cncurses
import Yams
import Darwin // For setlocale, LC_ALL

@MainActor
struct ResumeTUI {
    // MARK: - Nested TUIState
    @MainActor
    class TUIState {
        var screen: OpaquePointer?
        var headerWin: OpaquePointer?
        var contentWin: OpaquePointer?
        var footerWin: OpaquePointer?
        var currentTabIndex = 0
        var scrollPosition = 0
        var resume: Resume! // Make sure Resume struct is accessible from here
        var lastError: String?
        var debugLog: [String] = [] // Added for debug logging

        func appendToDebugLog(_ message: String) {
            debugLog.append(message)
        }
    }

    // MARK: - Ncurses Constants & Helpers
    static let A_BOLD: Int32 = 0x00200000
    static let A_UNDERLINE: Int32 = 0x00000040
    static let A_REVERSE: Int32 = 0x00040000 // Remains for potential other uses
    // static let A_REVERSE_CHTYPE: chtype = chtype(ResumeTUI.A_REVERSE) // No longer needed for boot screen static text

    // MARK: - TUI State (Static Properties)
    @MainActor static var tuiState = TUIState()
    static let TAB_NAMES = ["Overview", "Experience", "Skills", "Projects", "Contributions"]

    // MARK: - Helper Functions (Static Methods)
    static func wrapText(_ text: String, indent: Int = 0, width: Int) -> String {
        guard width > 0 else { return text }
        let indentString = String(repeating: " ", count: indent)
        var wrappedText = ""
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            if line.isEmpty {
                wrappedText += indentString + "\n"
                continue
            }
            var currentLine = indentString
            let words = line.split(separator: " ")

            for word in words {
                if currentLine.count + word.count + 1 > width && currentLine != indentString { // +1 for space
                    wrappedText += currentLine.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                    currentLine = indentString
                }
                currentLine += word + " "
            }
            wrappedText += currentLine.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        }
        if wrappedText.hasSuffix("\n") {
            wrappedText = String(wrappedText.dropLast())
        }
        return wrappedText
    }

    static func drawProgressBar(current: Int, maxVal: Int, width: Int) -> String {
        guard width > 2 else { return "[]" }
        let actualWidth = width - 2 // Account for '[' and ']'
        let progress = min(max(0, current), maxVal) // Clamp progress to be within 0 and maxVal
        let filledCount = Int(round(Double(progress) / Double(maxVal) * Double(actualWidth)))
        let emptyCount = actualWidth - filledCount

        let filledChars = String(repeating: "█", count: filledCount)
        let emptyChars = String(repeating: "░", count: emptyCount)

        return "[" + filledChars + emptyChars + "]"
    }

    // MARK: - YAML Parsing (Static Methods)
    static func baseYAMLtoJSON(_ yamlString: String) -> [String: Any] {
        var dict = [String: Any]()
        let lines = yamlString.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty || trimmedLine.starts(with: "#") { continue }

            let parts = trimmedLine.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let key = parts[0]
                let value = parts[1]
                if let intValue = Int(value) {
                    dict[key] = intValue
                } else if let doubleValue = Double(value) {
                    dict[key] = doubleValue
                } else if value.lowercased() == "true" || value.lowercased() == "false" {
                    dict[key] = Bool(value.lowercased())
                } else if value.starts(with: "[") && value.hasSuffix("]") && !value.contains("{") {
                     let arrayContent = value.dropFirst().dropLast()
                        .components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "") }
                     dict[key] = arrayContent
                } else {
                    dict[key] = value
                }
            }
        }
        return dict
    }

    static func parseResume(from yamlString: String) throws -> Resume {
        let jsonCompatibleDict = baseYAMLtoJSON(yamlString)
        let jsonData = try JSONSerialization.data(withJSONObject: jsonCompatibleDict, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(Resume.self, from: jsonData)
    }

    // MARK: - Resume Data Handling
    @MainActor
    static func loadResumeData() -> Resume? {
        let fileName = "resume"
        let fileExtension = "yaml"
        let resourcesSubDir = "Resources"

        var urlsToTry: [URL?] = []

        // 1. Primary Bundle location (inside Resources subdirectory)
        urlsToTry.append(Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: resourcesSubDir))

        // 2. Bundle root
        urlsToTry.append(Bundle.main.url(forResource: fileName, withExtension: fileExtension))

        // 3. & 4. Next to the executable
        if let executableURL = Bundle.main.executableURL?.deletingLastPathComponent() {
            urlsToTry.append(executableURL.appendingPathComponent(resourcesSubDir).appendingPathComponent("\(fileName).\(fileExtension)"))
            urlsToTry.append(executableURL.appendingPathComponent("\(fileName).\(fileExtension)"))
        }

        // 5. & 6. Current Working Directory (PWD)
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urlsToTry.append(currentDirectoryURL.appendingPathComponent(resourcesSubDir).appendingPathComponent("\(fileName).\(fileExtension)"))
        urlsToTry.append(currentDirectoryURL.appendingPathComponent("\(fileName).\(fileExtension)"))

        for urlOptional in urlsToTry {
            guard let url = urlOptional else { continue }

            // Check if file exists at this URL before attempting to load
            if FileManager.default.fileExists(atPath: url.path) {
                tuiState.appendToDebugLog("Attempting to load resume from: \(url.path)")
                do {
                    let yamlString = try String(contentsOf: url)
                    let decoder = YAMLDecoder()
                    let resume = try decoder.decode(Resume.self, from: yamlString)
                    tuiState.appendToDebugLog("Successfully loaded and parsed resume.yaml from \(url.path)")
                    return resume
                } catch {
                    tuiState.appendToDebugLog("Error loading or parsing resume.yaml from \(url.path): \(error)")
                    // Continue to next URL if this one fails
                }
            }
        }

        tuiState.lastError = "Error: \(fileName).\(fileExtension) not found in expected locations or failed to parse."
        tuiState.appendToDebugLog(tuiState.lastError ?? "Unknown error in loadResumeData after trying all paths.")
        return nil
    }

    // MARK: - Formatting Helpers (Static Methods)

    static func getRatingEmoji(rating: Int, maxRating: Int = 5, filledSymbol: String = "⭐", emptySymbol: String = "☆") -> String {
        let filledCount = max(0, min(rating, maxRating))
        let emptyCount = max(0, maxRating - filledCount)
        return String(repeating: filledSymbol, count: filledCount) + String(repeating: emptySymbol, count: emptyCount)
    }

    // MARK: - Ncurses UI Setup and Drawing (Static Methods)
    @MainActor
    static func setupNcurses() {
        // Set the locale to the user's environment settings. This is crucial
        // for ncurses to correctly handle multi-byte characters (UTF-8).
        // It MUST be called before initscr().
        _ = setlocale(LC_ALL, "")

        tuiState.screen = initscr()
        noecho()
        keypad(tuiState.screen, true)
        start_color()
        curs_set(0)
        if has_colors() {
            init_pair(1, Int16(COLOR_WHITE), Int16(COLOR_BLACK))
            init_pair(2, Int16(COLOR_BLACK), Int16(COLOR_CYAN))
            init_pair(3, Int16(COLOR_CYAN), Int16(COLOR_BLACK))
            init_pair(4, Int16(COLOR_GREEN), Int16(COLOR_BLACK))
            init_pair(5, Int16(COLOR_YELLOW), Int16(COLOR_BLACK)) // Ensure this is Yellow/Black for skill stars
            init_pair(6, Int16(COLOR_RED), Int16(COLOR_BLACK))
            init_pair(7, Int16(COLOR_MAGENTA), Int16(COLOR_BLACK))
            init_pair(8, Int16(COLOR_BLACK), Int16(COLOR_GREEN)) // Black on Green for matrix overlay text
        }
        bkgd(chtype(Cncurses.COLOR_PAIR(1)))
        // Allow smaller terminals for testing
        if getmaxy(tuiState.screen) < 10 || getmaxx(tuiState.screen) < 40 {
            endwin()
            print("Terminal too small. Please resize to at least 40x10.")
            exit(1)
        }
        refresh()
    }

    @MainActor
    static func createWindows() {
        let _ = getmaxy(tuiState.screen) // Replaced maxY with _
        let maxX = getmaxx(tuiState.screen)

        tuiState.headerWin = newwin(3, maxX, 0, 0)
        tuiState.contentWin = newwin(getmaxy(tuiState.screen) - 6, maxX, 3, 0) // Adjusted for header and footer
        tuiState.footerWin = newwin(3, maxX, getmaxy(tuiState.screen) - 3, 0)

        box(tuiState.headerWin, 0, 0)
        box(tuiState.contentWin, 0, 0)
        box(tuiState.footerWin, 0, 0)

        refresh()
    }

    // Function to draw the header with tabs
    @MainActor
    static func drawHeader(window: OpaquePointer?) {
        guard let window = window else { return }
        wclear(window)
        box(window, 0, 0) // Draw a box around the window

        let _ = getmaxy(window) // Replaced maxY with _
        let maxX = getmaxx(window)
        let tabSpacing = (maxX - 2) / Int32(TAB_NAMES.count) // -2 for borders

        for (index, name) in TAB_NAMES.enumerated() {
            let startX = 1 + Int32(index) * tabSpacing
            var attr = Cncurses.COLOR_PAIR(1)
            if index == tuiState.currentTabIndex {
                attr = Cncurses.COLOR_PAIR(2) | ResumeTUI.A_BOLD // Highlight current tab
            }
            wattron(window, attr)
            _ = name.withCString { mvwaddstr(window, 1, startX, $0) }
            wattroff(window, attr)
        }
        wrefresh(window)
    }

    // Function to draw the footer with instructions
    @MainActor
    static func drawFooter(window: OpaquePointer?) {
        guard let window = window else { return }
        wclear(window)
        box(window, 0, 0)
        let footerText = "Navigate: ← → Tabs | ↑ ↓ Scroll | 1-5 Tabs | Q: Quit"
        _ = footerText.withCString { mvwaddstr(window, 1, (getmaxx(window) - Int32(footerText.count)) / 2, $0) }
        wrefresh(window)
    }

    // Function to display content based on current tab
    @MainActor
    static func displayContent() { // Removed parameters, will use tuiState directly
        guard let contentWin = tuiState.contentWin else { return }
        wclear(contentWin)

        let attributedFormattedContent: [(String, Int32)]
        switch tuiState.currentTabIndex {
            case 0:
                attributedFormattedContent = ResumeTUI.formatOverviewTab(resume: tuiState.resume)
            case 1:
                attributedFormattedContent = ResumeTUI.formatExperienceTab(resume: tuiState.resume)
            case 2:
                attributedFormattedContent = ResumeTUI.formatSkillsTab(resume: tuiState.resume)
            case 3:
                attributedFormattedContent = ResumeTUI.formatProjectsTab(resume: tuiState.resume)
            case 4:
                attributedFormattedContent = ResumeTUI.formatContributionsTab(resume: tuiState.resume)
            default:
                attributedFormattedContent = [("Unknown tab", Cncurses.COLOR_PAIR(1))]
        }

        var currentY = 1 // Start drawing from the second line, leaving space for top border/padding
        // let contentWidth = getmaxx(contentWin) - 2 // -2 for side borders or padding -> This was unused

        // Calculate total lines in content to determine max scroll
        var totalContentLines = 0
        for (text, _) in attributedFormattedContent {
            // This is a simplification. A more accurate line count would consider text wrapping.
            // For now, counting newlines in the pre-formatted string segments.
            totalContentLines += text.components(separatedBy: "\n").count - 1
        }
        // Ensure totalContentLines is at least 1 if there's any content, to avoid division by zero or negative maxScroll
        totalContentLines = max(1, totalContentLines)

        // Content window height, adjusted for border/padding
        let contentWinHeight = getmaxy(contentWin) - 2

        // Adjust scrollPosition if it's out of bounds
        let maxScroll = max(0, totalContentLines - Int(contentWinHeight))
        if tuiState.scrollPosition > maxScroll {
            tuiState.scrollPosition = maxScroll
        }
        if tuiState.scrollPosition < 0 {
            tuiState.scrollPosition = 0
        }

        // Apply scrolling: Skip lines based on scrollPosition
        let linesToSkip = tuiState.scrollPosition // Changed to let as it's not mutated
        var linesSkipped = 0

        for (text, attr) in attributedFormattedContent {
            let lines = text.components(separatedBy: "\n")
            for (idx, lineContent) in lines.enumerated() {
                if linesSkipped < linesToSkip {
                    linesSkipped += 1
                    continue // Skip this line
                }

                if currentY >= contentWinHeight { // Stop if we've filled the visible part of the window
                    break
                }

                wattron(contentWin, attr)
                _ = lineContent.withCString { mvwaddstr(contentWin, Int32(currentY), 1, $0) } // Start from X=1 for padding
                wattroff(contentWin, attr)
                currentY += 1

                if idx < lines.count - 1 { // If it's not the last segment of a multi-line string from one (text,attr) pair
                     // This ensures that if a single `text` has newlines, currentY is incremented for each actual line displayed
                }
            }
            if currentY >= contentWinHeight {
                break
            }
        }

        box(contentWin, 0, 0) // Redraw box after clearing and writing content
        wrefresh(contentWin)
    }

    @MainActor
    static func refreshAllUI() {
        // Clear and redraw all windows
        // Clear the main screen as well to avoid artifacts if windows are resized or moved
        // clear() // Clears the entire physical screen. Use with caution or if needed.
        // wnoutrefresh(stdscr) // Marks stdscr for refresh, to be updated with doupdate()

        drawHeader(window: tuiState.headerWin)
        displayContent() // displayContent now internally handles tuiState.contentWin and refreshes it
        drawFooter(window: tuiState.footerWin)

        // doupdate() // Atomically updates the physical screen with all pending refreshes
        // For individual window refreshes (wrefresh), doupdate might not be strictly necessary
        // unless wnoutrefresh was used.
        // However, if experiencing flickering or partial updates, using wnoutrefresh for each window
        // followed by a single doupdate() at the end can help.
        // For simplicity, direct wrefresh in drawHeader/Footer/displayContent is often sufficient.
    }

    @MainActor
    static func runMainLoop() {
        var needsRedraw = true // Initially, draw everything

        while true {
            if needsRedraw {
                refreshAllUI()
                needsRedraw = false
            }

            let ch = getch() // Get character input (blocking)

            switch ch {
            case KEY_LEFT, Int32(Character("h").asciiValue!):
                if tuiState.currentTabIndex > 0 {
                    tuiState.currentTabIndex -= 1
                    tuiState.scrollPosition = 0 // Reset scroll on tab change
                    needsRedraw = true
                }
            case KEY_RIGHT, Int32(Character("l").asciiValue!):
                if tuiState.currentTabIndex < TAB_NAMES.count - 1 {
                    tuiState.currentTabIndex += 1
                    tuiState.scrollPosition = 0 // Reset scroll on tab change
                    needsRedraw = true
                }
            case KEY_UP, Int32(Character("k").asciiValue!):
                if tuiState.scrollPosition > 0 {
                    tuiState.scrollPosition -= 1
                    needsRedraw = true
                }
            case KEY_DOWN, Int32(Character("j").asciiValue!):
                // Max scroll limit handled by displayContent by adjusting scrollPosition
                // Simply increment scrollPosition; displayContent will clamp it.
                tuiState.scrollPosition += 1
                needsRedraw = true
            case KEY_PPAGE: // Page Up
                if tuiState.scrollPosition > 0 {
                    // Scroll up by the height of the content window (minus a line for context)
                    // or a fixed amount, e.g., 10 lines.
                    let pageScrollAmount = max(1, getmaxy(tuiState.contentWin) - 1)
                    tuiState.scrollPosition = max(0, tuiState.scrollPosition - Int(pageScrollAmount))
                    needsRedraw = true
                }
            case KEY_NPAGE: // Page Down
                // displayContent will handle clamping if scrollPosition goes too far
                let pageScrollAmount = max(1, getmaxy(tuiState.contentWin) - 1)
                tuiState.scrollPosition += Int(pageScrollAmount)
                needsRedraw = true
            case Int32(Character("1").asciiValue!):
                if tuiState.currentTabIndex != 0 {
                    tuiState.currentTabIndex = 0
                    tuiState.scrollPosition = 0
                    needsRedraw = true
                }
            case Int32(Character("2").asciiValue!):
                if tuiState.currentTabIndex != 1 {
                    tuiState.currentTabIndex = 1
                    tuiState.scrollPosition = 0
                    needsRedraw = true
                }
            case Int32(Character("3").asciiValue!):
                if tuiState.currentTabIndex != 2 {
                    tuiState.currentTabIndex = 2
                    tuiState.scrollPosition = 0
                    needsRedraw = true
                }
            case Int32(Character("4").asciiValue!):
                if tuiState.currentTabIndex != 3 {
                    tuiState.currentTabIndex = 3
                    tuiState.scrollPosition = 0
                    needsRedraw = true
                }
            case Int32(Character("5").asciiValue!):
                if tuiState.currentTabIndex != 4 {
                    tuiState.currentTabIndex = 4
                    tuiState.scrollPosition = 0
                    needsRedraw = true
                }
            case Int32(Character("q").asciiValue!):
                return // Exit loop
            case KEY_RESIZE: // Handle terminal resize
                // Recreate windows with new dimensions
                // Potentially more sophisticated handling for resizing is possible
                // For now, just clear and redraw everything
                endwin() // Temporarily end ncurses mode
                setupNcurses() // Re-initialize with new terminal size
                createWindows()
                needsRedraw = true // Mark for full redraw
            default:
                break // Ignore other keys
            }
        }
    }

    @MainActor
    static func displayBootScreen() {
        // Use the new matrix boot screen implementation
        displayMatrixBootScreen()
    }

    // MARK: - Main Entry Point
    @MainActor
    static func main() {
        setupNcurses()
        displayBootScreen() // Display boot screen after ncurses setup
        createWindows()
        if let resume = loadResumeData() {
            tuiState.resume = resume
        } else {
            endwin()
            let finalMessage = tuiState.lastError ?? "Failed to load resume data (unknown error)."
            fputs("\n--- Resume Loading Error ---\n", stderr)
            fputs("\(finalMessage)\n", stderr)
            fputs("\n--- Debug Log ---\n", stderr)
            for logEntry in tuiState.debugLog {
                fputs("\(logEntry)\n", stderr)
            }
            fputs("--- End Debug Log ---\n", stderr)
            exit(1)
        }
        runMainLoop()
        endwin() // Clean up ncurses before exiting
    }
}

// Explicitly call the main function to start the application
ResumeTUI.main()
