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
        var searchMatchSegmentIndices: [Int] = [] // NEW: Indices of segments matching activeSearchTerm
        var currentSearchMatchSegmentIndex: Int = -1 // NEW: Index into searchMatchSegmentIndices
        var totalContentLines: Int = 1

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
        guard let footerWin = tuiState.footerWin else { return }
        werase(footerWin)
        let footerHeight = getmaxy(footerWin)
        let footerWidth = getmaxx(footerWin)

        var footerText: String
        if tuiState.isSearching {
            footerText = "Search: \(tuiState.currentSearchTerm)_"
        } else if !tuiState.activeSearchTerm.isEmpty {
            if !tuiState.searchMatchSegmentIndices.isEmpty {
                let currentMatchNumber = tuiState.currentSearchMatchSegmentIndex + 1
                let totalMatches = tuiState.searchMatchSegmentIndices.count
                footerText = "Searched: \(tuiState.activeSearchTerm) [Match \(currentMatchNumber) of \(totalMatches)]"
            } else {
                footerText = "Searched: \(tuiState.activeSearchTerm) [No matches]"
            }
        } else {
            footerText = "Navigate: ← → Tabs | ↑ ↓ Scroll | / Search | 1-5 Tabs | Q: Quit"
        }

        // Basic footer text
        // let baseNavText = "Navigate: ← → Tabs | ↑ ↓ Scroll | / Search | 1-5 Tabs | Q: Quit"
        // let fullFooterText = footerText + String(repeating: " ", count: max(0, Int(footerWidth) - footerText.count - baseNavText.count - 1)) + baseNavText
        // Center the main footer text, and right-align the navigation help for now if space allows
        // This is a simple approach, might need refinement for perfect alignment

        let navHelpText = "| ← → Tabs | ↑ ↓ Scroll | / Search | 1-5 Tabs | Q: Quit"
        let availableWidthForMainText = Int(footerWidth) - navHelpText.count - 1 // -1 for a space separator
        
        var fullFooterText = footerText
        if footerText.count < availableWidthForMainText {
            fullFooterText += String(repeating: " ", count: availableWidthForMainText - footerText.count)
        }
        fullFooterText += navHelpText

        mvwaddstr(footerWin, footerHeight / 2, 1, fullFooterText)
        wrefresh(footerWin)
    }

    @MainActor
    static func displayContent() { // Removed parameters, will use tuiState directly
        guard let contentWin = tuiState.contentWin else { return }
        werase(contentWin)

        var ncursesY: Int32 = 0
        var _: Int32 = 0 // Keep track of X for potential future use, though not strictly needed now
        // wmove(contentWin, ncursesY, ncursesX) // Start at (0,0) of the content window - waddstr starts at current cursor pos

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

        // Clamp scrollPosition to prevent out-of-bounds access
        if attributedSegmentedContent.isEmpty {
            tuiState.scrollPosition = 0
        } else {
            // Ensure scrollPosition is not less than 0
            tuiState.scrollPosition = max(0, tuiState.scrollPosition)
            // Ensure scrollPosition does not exceed the last valid index
            tuiState.scrollPosition = min(tuiState.scrollPosition, attributedSegmentedContent.count - 1)
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
        
        // Reset cursor to top-left of content window before drawing lines for the current scroll position
        wmove(contentWin, 0, 0) // Move to top-left (y=0, x=0) *inside* the content window border if applicable
                                // If box() is used, drawing should start at (1,1) relative to window origin.
                                // For now, assuming waddstr handles newlines correctly from (0,0)
                                // and we are manually tracking lines within the window height.
        ncursesY = 0 // Reset logical line counter for the window

        for i in tuiState.scrollPosition..<attributedSegmentedContent.count {
            if ncursesY >= contentWinHeight { // Stop if we've filled the visible part of the window
                break
            }

            let (textSegment, attr) = attributedSegmentedContent[i]

            wattron(contentWin, attr)
            // If textSegment contains newlines, waddstr will handle them and move cursor.
            // We need to ensure we don't try to write past the bottom of the window MANUALLY if waddstr doesn't clip perfectly.
            // The check `ncursesY >= contentWinHeight` should ideally be more fine-grained if a single textSegment can span multiple lines
            // and exceed the window height by itself.
            // For simplicity, assuming each segment primarily fits or we check after each segment.
            
            // If starting position for text is important (e.g., after box border), use mvwaddstr or wmove then waddstr.
            // With wmove(contentWin, 0,0) before loop, first waddstr starts at top-left.
            // Subsequent waddstr continue from where last one left off.
            waddstr(contentWin, textSegment) 
            wattroff(contentWin, attr)

            ncursesY = getcury(contentWin) // Update ncursesY based on where cursor is now
            // ncursesX = getcurx(contentWin) // X position might be useful for very complex layouts
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
                        // Populate searchMatchSegmentIndices based on the activeSearchTerm and current tab content
                        tuiState.searchMatchSegmentIndices = []
                        if !tuiState.activeSearchTerm.isEmpty {
                            let contentForTab: [(String, Int32)]
                            switch tuiState.currentTabIndex {
                                case 0: contentForTab = formatOverviewTab(resume: tuiState.resume)
                                case 1: contentForTab = formatExperienceTab(resume: tuiState.resume)
                                case 2: contentForTab = formatSkillsTab(resume: tuiState.resume)
                                case 3: contentForTab = formatProjectsTab(resume: tuiState.resume)
                                case 4: contentForTab = formatContributionsTab(resume: tuiState.resume)
                                default: contentForTab = []
                            }

                            for (index, segment) in contentForTab.enumerated() {
                                if segment.0.localizedCaseInsensitiveContains(tuiState.activeSearchTerm) {
                                    tuiState.searchMatchSegmentIndices.append(index)
                                }
                            }
                        }

                        if !tuiState.searchMatchSegmentIndices.isEmpty {
                            tuiState.currentSearchMatchSegmentIndex = 0
                            let targetSegmentIndex = tuiState.searchMatchSegmentIndices[0]
                            let desiredContextSegments = 2 // Show 2 segments before the match if possible
                            tuiState.scrollPosition = max(0, targetSegmentIndex - desiredContextSegments)
                            tuiState.appendToDebugLog("Found \(tuiState.searchMatchSegmentIndices.count) matches for '\(tuiState.activeSearchTerm)'. First match at segment \(targetSegmentIndex), scrolling to \(tuiState.scrollPosition).")
                        } else {
                            tuiState.currentSearchMatchSegmentIndex = -1
                            tuiState.appendToDebugLog("No matches found for '\(tuiState.activeSearchTerm)'.")
                        }
                        needsRedraw = true
                    case 27: // Escape key
                        tuiState.isSearching = false
                        tuiState.currentSearchTerm = ""
                        tuiState.activeSearchTerm = ""
                        tuiState.searchMatchSegmentIndices = []
                        tuiState.currentSearchMatchSegmentIndex = -1
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
                        // scrollPosition is an index into segments.
                        // Max scroll will be handled by clamping in displayContent.
                        tuiState.scrollPosition += 1
                        needsRedraw = true
                    case KEY_PPAGE: // Page Up
                        if let cw = tuiState.contentWin {
                            let visibleHeight = getmaxy(cw)
                            let pageScrollAmount = max(1, Int(visibleHeight - 2)) // -2 for top/bottom border of the box
                            tuiState.scrollPosition = max(0, tuiState.scrollPosition - pageScrollAmount)
                            needsRedraw = true
                        }
                    case KEY_NPAGE: // Page Down
                        if let cw = tuiState.contentWin {
                            let visibleHeight = getmaxy(cw)
                            let pageScrollAmount = max(1, Int(visibleHeight - 2)) // -2 for top/bottom border of the box
                            tuiState.scrollPosition += pageScrollAmount
                            // Clamping to max will be handled in displayContent's logic
                            needsRedraw = true
                        }
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
                        // tuiState.searchMatchSegmentIndices = []
                        // tuiState.currentSearchMatchSegmentIndex = 0
                        needsRedraw = true
                    case Int32(Character("n").asciiValue!): // Next search result
                        if !tuiState.activeSearchTerm.isEmpty && !tuiState.searchMatchSegmentIndices.isEmpty {
                            tuiState.currentSearchMatchSegmentIndex += 1
                            if tuiState.currentSearchMatchSegmentIndex >= tuiState.searchMatchSegmentIndices.count {
                                tuiState.currentSearchMatchSegmentIndex = 0 // Wrap around
                            }
                            let targetSegmentIndex = tuiState.searchMatchSegmentIndices[tuiState.currentSearchMatchSegmentIndex]
                            let desiredContextSegments = 2
                            tuiState.scrollPosition = max(0, targetSegmentIndex - desiredContextSegments)
                            tuiState.appendToDebugLog("Next match: index \(tuiState.currentSearchMatchSegmentIndex), target segment \(targetSegmentIndex), scrolling to \(tuiState.scrollPosition)")
                            needsRedraw = true
                        }
                    case Int32(Character("N").asciiValue!), Int32(Character("p").asciiValue!): // Previous search result
                        if !tuiState.activeSearchTerm.isEmpty && !tuiState.searchMatchSegmentIndices.isEmpty {
                            tuiState.currentSearchMatchSegmentIndex -= 1
                            if tuiState.currentSearchMatchSegmentIndex < 0 {
                                tuiState.currentSearchMatchSegmentIndex = tuiState.searchMatchSegmentIndices.count - 1 // Wrap around
                            }
                            let targetSegmentIndex = tuiState.searchMatchSegmentIndices[tuiState.currentSearchMatchSegmentIndex]
                            let desiredContextSegments = 2
                            tuiState.scrollPosition = max(0, targetSegmentIndex - desiredContextSegments)
                            tuiState.appendToDebugLog("Previous match: index \(tuiState.currentSearchMatchSegmentIndex), target segment \(targetSegmentIndex), scrolling to \(tuiState.scrollPosition)")
                            needsRedraw = true
                        }
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
        // This function is currently not used, but it's kept for potential future use
        // with more complex search logic.
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
