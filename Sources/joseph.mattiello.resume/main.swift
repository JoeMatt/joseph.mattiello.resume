import Foundation
import Cncurses
import Yams
import Darwin // For setlocale, LC_ALL

@MainActor
struct ResumeTUI {
    // MARK: - Nested Structs
    struct SearchMatch {
        let tabIndex: Int
        let originalLineIndex: Int // Index of the line in the *unformatted* content of the tab
        let rangeInLine: Range<String.Index> // Range of the match within that original line
        let matchedLineText: String // The original line text where the match was found
    }

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

        // Search State
        var isSearching: Bool = false
        var currentSearchTerm: String = ""
        var activeSearchTerm: String = "" // The term actually being searched for
        // For later: storing search results
        var searchMatches: [SearchMatch] = []
        var currentSearchMatchIndex: Int = -1 // -1 means no match selected/active
        var totalContentLines: Int = 1 // Add this line

        func appendToDebugLog(_ message: String) {
            debugLog.append(message)
        }
    }

    // MARK: - Ncurses Constants & Helpers
    static let A_BOLD: Int32 = 0x00200000
    static let A_UNDERLINE: Int32 = 0x00000040
    static let A_REVERSE: Int32 = 0x00040000 // Remains for potential other uses
    static let A_HIGHLIGHT: Int32 = 0x00040000 // Or define a specific color pair if preferred
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
        tuiState.appendToDebugLog("--- NCurses Setup Initializing ---")

        // Log isatty status for standard file descriptors
        tuiState.appendToDebugLog("isatty(STDIN_FILENO): \(isatty(STDIN_FILENO)) ('\(String(cString: strerror(errno)))')")
        errno = 0 // Reset errno after checking
        tuiState.appendToDebugLog("isatty(STDOUT_FILENO): \(isatty(STDOUT_FILENO)) ('\(String(cString: strerror(errno)))')")
        errno = 0
        tuiState.appendToDebugLog("isatty(STDERR_FILENO): \(isatty(STDERR_FILENO)) ('\(String(cString: strerror(errno))))") // Corrected typo
        errno = 0

        // Log relevant environment variables
        let envVars = ["TERM", "LC_ALL", "LC_CTYPE", "LANG"]
        for ev in envVars {
            if let value = getenv(ev) {
                tuiState.appendToDebugLog("ENV \(ev): \(String(cString: value))")
            } else {
                tuiState.appendToDebugLog("ENV \(ev): not set")
            }
        }

        // Set the locale to the user's environment settings. This is crucial
        // for ncurses to correctly handle multi-byte characters (UTF-8).
        // It MUST be called before initscr().
        _ = setlocale(LC_ALL, "")
        if let currentLocale = setlocale(LC_ALL, nil) {
            tuiState.appendToDebugLog("Locale set to: \(String(cString: currentLocale))")
        } else {
            tuiState.appendToDebugLog("Locale could not be determined after attempting to set it.")
        }

        tuiState.screen = initscr()
        if let screen = tuiState.screen {
            tuiState.appendToDebugLog("initscr() called successfully.")
            tuiState.appendToDebugLog("Terminal dimensions (post-initscr): \(getmaxy(screen)) rows, \(getmaxx(screen)) cols")
        } else {
            tuiState.appendToDebugLog("initscr() FAILED. Screen pointer is nil.")
            // If initscr fails, ncurses operations are not possible. Print debug log and exit.
            printDebugLogAndShutdownNcurses(withMessage: "initscr() failed")
            exit(1)
        }

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
        // This check is after initscr(), so getmaxy/getmaxx should be valid if screen is not nil.
        if getmaxy(tuiState.screen) < 10 || getmaxx(tuiState.screen) < 40 { // Original minimums: 40 cols, 10 lines
            // endwin() is handled by printDebugLogAndShutdownNcurses
            printDebugLogAndShutdownNcurses(withMessage: "Terminal too small. Detected: \(getmaxx(tuiState.screen)) cols, \(getmaxy(tuiState.screen)) rows.")
            exit(1) // Explicitly exit
        }
        tuiState.appendToDebugLog("Ncurses setup completed successfully.")
    }

    // MARK: - Debug Log Printing and Shutdown
    @MainActor
    static func printDebugLogAndShutdownNcurses(withMessage message: String = "Exiting") {
        let wasScreenNil = (tuiState.screen == nil)
        if !wasScreenNil {
            endwin() // Gracefully shut down ncurses if it was initialized
        }

        // Print to stderr to avoid issues if stdout is redirected or in an odd state
        let stderr = FileHandle.standardError
        if let data = "\n--- DEBUG LOG (\(message)) ---\n".data(using: .utf8) { stderr.write(data) }
        tuiState.debugLog.forEach { if let data = "\($0)\n".data(using: .utf8) { stderr.write(data) } }
        if let data = "--- END DEBUG LOG ---\n".data(using: .utf8) { stderr.write(data) }

        if wasScreenNil && message == "Exiting" { // If called before ncurses setup, print a note
             if let data = "Note: Ncurses screen was not initialized or initscr() failed.\n".data(using: .utf8) { stderr.write(data) }
        }
    }

    // MARK: - Ncurses UI Setup and Drawing (Static Methods)
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

    @MainActor
    static func drawFooter(window: OpaquePointer?) {
        guard let window = window else { return }
        wclear(window)
        box(window, 0, 0)

        let footerText: String
        if tuiState.isSearching {
            // Display search input prompt with a pseudo-cursor
            footerText = "Search: \(tuiState.currentSearchTerm)_"
        } else {
            footerText = "Navigate: ← → Tabs | ↑ ↓ Scroll | / Search | 1-5 Tabs | Q: Quit"
        }

        _ = footerText.withCString { mvwaddstr(window, 1, (getmaxx(window) - Int32(footerText.count)) / 2, $0) }
        wrefresh(window)
    }

    // Function to display content based on current tab
    @MainActor
    static func displayContent() { // Removed parameters, will use tuiState directly
        guard let contentWin = tuiState.contentWin else { return }
        werase(contentWin)

        var ncursesY: Int32 = 0
        var ncursesX: Int32 = 0 // Keep track of X for potential future use, though not strictly needed now
        wmove(contentWin, ncursesY, ncursesX) // Start at (0,0) of the content window

        let attributedSegmentedContent: [(String, Int32)]
        switch tuiState.currentTabIndex {
            case 0: attributedSegmentedContent = formatOverviewTab(resume: tuiState.resume)
            case 1: attributedSegmentedContent = formatExperienceTab(resume: tuiState.resume)
            case 2: attributedSegmentedContent = formatSkillsTab(resume: tuiState.resume)
            case 3: attributedSegmentedContent = formatProjectsTab(resume: tuiState.resume)
            case 4: attributedSegmentedContent = formatContributionsTab(resume: tuiState.resume)
            default:
                attributedSegmentedContent = [("Unknown tab", Cncurses.COLOR_PAIR(1))]
        }

        // Calculate total logical lines for scrolling (approximation based on newlines)
        // This might need refinement if a single segment can be exceptionally long and wraps without a newline.
        var logicalLineCount = 0
        for (text, _) in attributedSegmentedContent {
            logicalLineCount += text.components(separatedBy: "\n").count - (text.hasSuffix("\n") ? 0 : 1)
            if text.isEmpty && attributedSegmentedContent.count == 1 { // Handle case of single empty segment
                 logicalLineCount = 1
            }
        }
        if attributedSegmentedContent.last?.0.hasSuffix("\n") == true && logicalLineCount > 0 {
            // If the very last segment ends with a newline, it forms its own line or ends one.
            // The previous logic might undercount by one in some edge cases with trailing newlines.
            // A simple fix for now, might need more robust line counting if scrolling issues persist.
        } else if !attributedSegmentedContent.isEmpty && logicalLineCount == 0 {
             logicalLineCount = 1 // Ensure at least one line if there's content but no newlines
        }

        tuiState.totalContentLines = logicalLineCount > 0 ? logicalLineCount : 1

        let contentWinHeight = getmaxy(contentWin) // Max Y of the window (number of rows)

        // Iterate through the attributed segments, starting from the scroll position
        // Note: tuiState.scrollPosition here refers to an *index* in the attributedSegmentedContent array,
        // not necessarily a logical line number. This will be refined for smoother scrolling later.
        for i in tuiState.scrollPosition..<attributedSegmentedContent.count {
            if ncursesY >= contentWinHeight { // Stop if we've filled the visible part of the window
                break
            }

            let (textSegment, attr) = attributedSegmentedContent[i]

            wattron(contentWin, attr)
            waddstr(contentWin, textSegment) // ncurses handles newlines within textSegment
            wattroff(contentWin, attr)

            ncursesY = getcury(contentWin) // New line
            ncursesX = getcurx(contentWin) // New line
        }

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
                drawHeader(window: tuiState.headerWin)
                displayContent() // This will draw content in tuiState.contentWin
                drawFooter(window: tuiState.footerWin)
                // No global refresh() here, individual window refreshes are enough
                needsRedraw = false
            }

            let input = getch()

            if tuiState.isSearching {
                switch input {
                    case 10, 13, KEY_ENTER: // Enter key (10 for LF, 13 for CR)
                        tuiState.activeSearchTerm = tuiState.currentSearchTerm
                        tuiState.isSearching = false
                        performSearch() // Perform the search
                        needsRedraw = true
                        tuiState.appendToDebugLog("Search submitted: \(tuiState.activeSearchTerm)")
                        // Future: Trigger actual search logic here and update displayContent
                    case 27: // Escape key
                        tuiState.isSearching = false
                        tuiState.currentSearchTerm = ""
                        tuiState.activeSearchTerm = ""
                        needsRedraw = true
                    case KEY_BACKSPACE, 127, 8: // Backspace (127 for some terminals, 8 for others)
                        if !tuiState.currentSearchTerm.isEmpty {
                            tuiState.currentSearchTerm.removeLast()
                            needsRedraw = true
                        }
                    default:
                        // Check for printable ASCII characters
                        if (input >= 32 && input <= 126) { // Printable ASCII range
                            let char = UnicodeScalar(UInt8(input))
                            tuiState.currentSearchTerm.append(String(char))
                            needsRedraw = true
                        }
                }
            } else { // Not searching, handle normal navigation
                switch input {
                    case Int32(Character("q").asciiValue!), Int32(Character("Q").asciiValue!):
                        return // Exit the main loop (and thus the application)
                    case KEY_LEFT:
                        tuiState.currentTabIndex = (tuiState.currentTabIndex - 1 + TAB_NAMES.count) % TAB_NAMES.count
                        tuiState.scrollPosition = 0 // Reset scroll on tab change
                        needsRedraw = true
                    case KEY_RIGHT:
                        tuiState.currentTabIndex = (tuiState.currentTabIndex + 1) % TAB_NAMES.count
                        tuiState.scrollPosition = 0 // Reset scroll on tab change
                        needsRedraw = true
                    case KEY_UP:
                        tuiState.scrollPosition = max(0, tuiState.scrollPosition - 1)
                        needsRedraw = true
                    case KEY_DOWN:
                        // We don't know max scroll here easily, so allow scrolling down
                        // displayContent will clamp it if it goes too far.
                        tuiState.scrollPosition += 1
                        needsRedraw = true
                    case Int32(Character("1").asciiValue!)...Int32(Character("\(TAB_NAMES.count)").asciiValue!):
                        let digit = input - Int32(Character("0").asciiValue!)
                        if digit >= 1 && digit <= TAB_NAMES.count {
                            tuiState.currentTabIndex = Int(digit - 1)
                            tuiState.scrollPosition = 0 // Reset scroll on tab change
                            needsRedraw = true
                        }
                    case Int32(Character("/").asciiValue!):
                        tuiState.isSearching = true
                        tuiState.currentSearchTerm = ""
                        tuiState.activeSearchTerm = ""
                        // Clear previous search results if any (when implemented)
                        // tuiState.searchMatches = []
                        // tuiState.currentSearchMatchIndex = 0
                        needsRedraw = true
                    default:
                        break // Ignore other keys
                }
            }
        }
    }

    @MainActor
    static func displayBootScreen() {
        // Use the new matrix boot screen implementation
        displayMatrixBootScreen()
    }

    // MARK: - Search Logic
    @MainActor
    static func performSearch() {
        tuiState.searchMatches.removeAll()
        tuiState.currentSearchMatchIndex = -1

        guard !tuiState.activeSearchTerm.isEmpty, let resume = tuiState.resume else {
            return
        }

        let searchTerm = tuiState.activeSearchTerm
        let searchTermLowercased = searchTerm.lowercased()

        for tabIndex in 0..<TAB_NAMES.count {
            var rawContentLines: [String] = []

            switch tabIndex {
                case 0: // Overview
                    rawContentLines = ResumeTUI.getRawOverviewLines(resume: resume)
                case 1: // Experience
                    rawContentLines = ResumeTUI.getRawExperienceLines(resume: resume)
                case 2: // Skills
                    rawContentLines = ResumeTUI.getRawSkillsLines(resume: resume)
                case 3: // Projects
                    rawContentLines = ResumeTUI.getRawProjectsLines(resume: resume)
                case 4: // Contributions
                    rawContentLines = ResumeTUI.getRawContributionsLines(resume: resume)
                default:
                    break
            }

            // ... (the rest of the function for finding matches remains the same) ...
            for (lineIndex, originalLine) in rawContentLines.enumerated() {
                var searchStartIndex = originalLine.startIndex
                let originalLineLowercased = originalLine.lowercased()

                while searchStartIndex < originalLine.endIndex,
                      let rangeInLowercasedLine = originalLineLowercased.range(of: searchTermLowercased, options: .caseInsensitive, range: searchStartIndex..<originalLine.endIndex) {

                    guard let actualRangeInOriginalLine = originalLine.range(of: searchTerm, options: .caseInsensitive, range: rangeInLowercasedLine) else {
                        let nsRange = NSRange(rangeInLowercasedLine, in: originalLineLowercased)
                        if let swiftRange = Range(nsRange, in: originalLine) {
                             let match = SearchMatch(tabIndex: tabIndex,
                                                    originalLineIndex: lineIndex,
                                                    rangeInLine: swiftRange,
                                                    matchedLineText: originalLine)
                            tuiState.searchMatches.append(match)
                        }
                        searchStartIndex = rangeInLowercasedLine.upperBound
                        continue
                    }

                    let match = SearchMatch(tabIndex: tabIndex,
                                            originalLineIndex: lineIndex,
                                            rangeInLine: actualRangeInOriginalLine,
                                            matchedLineText: originalLine)
                    tuiState.searchMatches.append(match)
                    searchStartIndex = actualRangeInOriginalLine.upperBound
                }
            }
        }

        if !tuiState.searchMatches.isEmpty {
            tuiState.currentSearchMatchIndex = 0
            tuiState.appendToDebugLog("Found \(tuiState.searchMatches.count) matches for '\(searchTerm)'. First match selected.")
        } else {
            tuiState.appendToDebugLog("No matches found for '\(searchTerm)'.")
        }
    }

    // MARK: - Text Highlighting Helper
    @MainActor
    static func highlightOccurrences(of searchTerm: String, in text: String, baseAttribute: Int32, highlightAttribute: Int32) -> [(String, Int32)] {
        guard !searchTerm.isEmpty, !text.isEmpty else {
            return [(text, baseAttribute)]
        }

        var result: [(String, Int32)] = []
        var currentIndex = text.startIndex
        let searchTermLowercased = searchTerm.lowercased()
        let textLowercased = text.lowercased() // For case-insensitive search ranges

        while currentIndex < text.endIndex {
            if let rangeInLowercased = textLowercased.range(of: searchTermLowercased, range: currentIndex..<text.endIndex) {
                // Convert range from lowercased string to original string for accurate substringing
                // This assumes that the length of the match is the same in both original and lowercased text,
                // which is true for most common cases but might need adjustment for complex Unicode scenarios.
                let distanceToStart = textLowercased.distance(from: textLowercased.startIndex, to: rangeInLowercased.lowerBound)
                let distanceToEnd = textLowercased.distance(from: textLowercased.startIndex, to: rangeInLowercased.upperBound)

                let originalMatchStartIndex = text.index(text.startIndex, offsetBy: distanceToStart)
                let originalMatchEndIndex = text.index(text.startIndex, offsetBy: distanceToEnd)
                let actualMatchRangeInOriginal = originalMatchStartIndex..<originalMatchEndIndex

                if actualMatchRangeInOriginal.lowerBound > currentIndex {
                    // Add the part before the match
                    let preMatchText = String(text[currentIndex..<actualMatchRangeInOriginal.lowerBound])
                    result.append((preMatchText, baseAttribute))
                }
                // Add the matched part with highlight
                let matchText = String(text[actualMatchRangeInOriginal])
                result.append((matchText, highlightAttribute))
                currentIndex = actualMatchRangeInOriginal.upperBound
            } else {
                // No more matches, add the rest of the text
                let remainingText = String(text[currentIndex..<text.endIndex])
                result.append((remainingText, baseAttribute))
                break
            }
        }
        return result
    }

    // MARK: - Main Entry Point
    @MainActor
    static func main() {
        setupNcurses()
        displayBootScreen() // Display boot screen after ncurses setup
        createWindows()
        if let resume = loadResumeData() {
            tuiState.resume = resume
            tuiState.appendToDebugLog("Before runMainLoop - currentTabIndex: \(tuiState.currentTabIndex), scrollPosition: \(tuiState.scrollPosition)")
            runMainLoop()
            // This is reached when runMainLoop returns (e.g., user quits)
            printDebugLogAndShutdownNcurses(withMessage: "Normal application exit")
        } else {
            // Error loading resume data, tuiState.lastError should be set by loadResumeData
            // loadResumeData itself also appends to debugLog
            if let errorMsg = tuiState.lastError {
                 let stderr = FileHandle.standardError
                 if let data = "Critical Error: Failed to load resume data - \(errorMsg)\n".data(using: .utf8) { stderr.write(data) }
            }
            printDebugLogAndShutdownNcurses(withMessage: "Failed to load resume data")
            exit(1)
        }
        // Note: If runMainLoop() could throw or have other exit paths not returning,
        // more complex exit handling (like signal trapping) might be needed for those.
    }
}

// Explicitly call the main function to start the application
ResumeTUI.main()
