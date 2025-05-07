// Joseph Mattiello Resume CLI Application
// A terminal-based resume viewer using Cncurses (raw C ncurses)

import Foundation
import Cncurses
import Darwin // For setlocale, LC_ALL

// Ncurses attributes not directly imported as Swift constants due to C macro definitions
// A_BOLD is typically (1U << (13 + 8)) = 1U << 21 = 2097152
let A_BOLD: Int32 = 0x200000 // Or 2097152
// You might need to define other A_* attributes (A_NORMAL, A_REVERSE, etc.) if used
// let A_NORMAL: Int32 = 0

// Function to initialize color pairs
func initPairs() {
    // Pair 1: Header/Footer text on blue background (or other distinctive scheme)
    init_pair(1, Int16(COLOR_WHITE), Int16(COLOR_BLUE))
    // Pair 2: Selected tab (black text on white background for high contrast)
    init_pair(2, Int16(COLOR_BLACK), Int16(COLOR_WHITE))
    // Pair 3: Unselected tab / Default content text (white text on black background)
    init_pair(3, Int16(COLOR_WHITE), Int16(COLOR_BLACK))
    // Pair 4: Section headers in content (e.g., yellow or cyan on black)
    init_pair(4, Int16(COLOR_YELLOW), Int16(COLOR_BLACK))
    // Pair 5: Green on black for hacker boot screen trail
    init_pair(5, Int16(COLOR_GREEN), Int16(COLOR_BLACK))
    // Pair 6: List items, skill names, or secondary info (e.g., cyan on black)
    init_pair(6, Int16(COLOR_CYAN), Int16(COLOR_BLACK))
    // Pair 7: White on black for Matrix rain head
    init_pair(7, Int16(COLOR_WHITE), Int16(COLOR_BLACK))
}

// Main entry point for the application
func runResumeTUI(resume: Resume) throws { // Keeping throws for now, as later parts of the function might still use it
    // Set locale for UTF-8 character support, crucial for ncursesw
    // This should be one of the first things called in a ncurses application.
    _ = setlocale(LC_ALL, "")

    // Helper function to convert Swift String to null-terminated wchar_t array
    func swiftStringToWcharTArray(_ str: String) -> [wchar_t] {
        return str.unicodeScalars.map { wchar_t($0.value) } + [0] // Null-terminate
    }

    // Global window variables
    var mainScreen: OpaquePointer? // Changed from OpaquePointer!
    var headerWin: OpaquePointer?
    var contentWin: OpaquePointer?
    var footerWin: OpaquePointer?

    guard let screen = initscr() else {
        print("Error: Could not initialize ncurses screen (initscr failed).")
        return
    }
    mainScreen = screen // Assign to global
    defer { endwin() } // Ensures ncurses environment is closed properly on exit from this scope

    // The guard above ensures screen is not nil, so mainScreen is not nil here.
    // The following explicit nil check for mainScreen is technically redundant but harmless.
    guard mainScreen != nil else {
        endwin() // Clean up ncurses
        print("Error: mainScreen is nil after initscr() and assignment.")
        return
    }

    start_color()
    use_default_colors() // Use terminal's default background, allows transparency
    initPairs()          // Initialize color pairs

    noecho()             // Don't echo typed characters
    cbreak()             // Disable line buffering, make chars available immediately
    keypad(mainScreen!, true) // Enable function keys (arrows, F1, etc.) - mainScreen! is safe here
    curs_set(0)          // Hide the cursor

    // Display boot screen first
    displayBootScreen(window: mainScreen) // mainScreen is OpaquePointer?, which matches func signature

    // Setup windows after boot screen
    let appMaxY = getmaxy(mainScreen!) // Total available height for stdscr
    let appMaxX = getmaxx(mainScreen!) // Total available width for stdscr

    // Define tabs for different sections
    let tabs = ["Overview", "Experience", "Skills", "Projects", "Open Source"]

    // Calculate effective usable area *inside* the main border
    let innerY: Int32 = 1             // Start 1 line down
    let innerX: Int32 = 1             // Start 1 column in
    let innerHeight = appMaxY > 2 ? appMaxY - 2 : 1 // Subtract 2 for top/bottom border lines, ensure at least 1
    let innerWidth = appMaxX > 2 ? appMaxX - 2 : 1   // Subtract 2 for left/right border lines, ensure at least 1

    // Calculate window dimensions for header, content, footer to fit *inside* the border
    let headerHeight: Int32 = 3
    // Ensure headerHeight doesn't exceed innerHeight
    let actualHeaderHeight = min(headerHeight, innerHeight)
    headerWin = newwin(actualHeaderHeight, innerWidth, innerY, innerX)

    let footerHeight: Int32 = 1
    // Ensure footerHeight doesn't exceed what's left of innerHeight
    let actualFooterHeight = min(footerHeight, innerHeight - actualHeaderHeight > 0 ? innerHeight - actualHeaderHeight : 0)

    // Content window takes the remaining space
    // Ensure contentHeight is not negative
    let potentialContentHeight = innerHeight - actualHeaderHeight - actualFooterHeight
    let actualContentHeight = potentialContentHeight > 0 ? potentialContentHeight : 0

    contentWin = newwin(actualContentHeight, innerWidth, innerY + actualHeaderHeight, innerX)
    if let win = contentWin {
        scrollok(win, true) // Enable scrolling for contentWin
        // Explicitly set the background for contentWin to ensure it fills correctly
        // COLOR_PAIR(3) is typically White_Text on Black_Background, so background is Black.
        wbkgd(win, chtype(COLOR_PAIR(3)))
    }

    footerWin = newwin(actualFooterHeight, innerWidth, innerY + actualHeaderHeight + actualContentHeight, innerX)

    // Ensure windows are not nil (especially important if innerHeight/Width were too small)
    guard headerWin != nil, contentWin != nil, footerWin != nil else {
        print("Error: Could not initialize windows. Screen might be too small.")
        return
    }
    guard actualHeaderHeight > 0, actualContentHeight >= 0, actualFooterHeight > 0 else {
        // This check is a bit redundant if newwin handles zero dimensions gracefully by returning nil,
        // but good for explicit safety if screen is extremely small.
        print("Error: Calculated window dimensions are invalid (too small). Screen might be too small.")
        return
    }

    // Track current tab and scroll position
    var currentTabIndex = 0
    var scrollPosition = 0

    // Function to draw the header with tabs
    func drawHeader() {
        guard let headerWin = headerWin else { return }
        wclear(headerWin)
        wattron(headerWin, COLOR_PAIR(1) | A_BOLD) // Set attributes for the window

        mvwaddwstr(headerWin, 0, 0, swiftStringToWcharTArray("Joseph Mattiello's Resume"))
        wattroff(headerWin, COLOR_PAIR(1) | A_BOLD)

        // Draw tabs
        var xPos: Int32 = 0
        for (index, tab) in tabs.enumerated() {
            let tabWidth = Int32(tab.count + 4)
            let selected = index == currentTabIndex
            let colorPairID = Int32(selected ? 2 : 3)

            wattron(headerWin, COLOR_PAIR(colorPairID))
            mvwaddwstr(headerWin, 2, xPos, swiftStringToWcharTArray(" \(tab) "))
            wattroff(headerWin, COLOR_PAIR(colorPairID))

            xPos += tabWidth
        }

        wrefresh(headerWin)
    }

    // Function to draw the footer
    func drawFooter() {
        guard let footerWin = footerWin else { return }
        wclear(footerWin)
        let footerText = "TAB: Switch | ↑↓: Scroll | Q: Quit"
        // Center text within footerWin itself
        let footerWinMaxX = getmaxx(footerWin) // Get the actual width of footerWin
        let textX = (footerWinMaxX - Int32(footerText.count)) / 2

        wattron(footerWin, COLOR_PAIR(1))
        // Ensure textX is not negative if footerText is too long for the window
        mvwaddwstr(footerWin, 0, max(0, textX), swiftStringToWcharTArray(footerText))
        wattroff(footerWin, COLOR_PAIR(1))
        // No wrefresh(footerWin) here, refreshAll handles it with doupdate
    }

    // Function to display content based on current tab
    func displayContent() {
        guard let contentWin = contentWin else { return }
        wclear(contentWin)

        var content = ""
        switch currentTabIndex {
        case 0: // Overview
            content = formatOverviewTab(resume: resume)
        case 1: // Experience
            content = formatExperienceTab(resume: resume)
        case 2: // Skills
            content = formatSkillsTab(resume: resume)
        case 3: // Projects
            content = formatProjectsTab(resume: resume)
        case 4: // Open Source
            content = formatContributionsTab(resume: resume)
        default:
            content = ""
        }

        // Split content into lines and display with scrolling
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let contentMaxY = getmaxy(contentWin)
        let visibleLines = min(Int(contentMaxY), lines.count - scrollPosition)

        for i in 0..<visibleLines {
            let lineIndex = i + scrollPosition
            if lineIndex < lines.count {
                let line = lines[lineIndex]
                let i32 = Int32(i)

                // Apply color to special sections
                if line.contains("CONTACT INFORMATION") ||
                   line.contains("PROFESSIONAL SUMMARY") ||
                   line.contains("EDUCATION") ||
                   line.contains("WORK EXPERIENCE") ||
                   line.contains("TECHNICAL SKILLS") ||
                   line.contains("PROGRAMMING LANGUAGES") ||
                   line.contains("SDKs & APIs") ||
                   line.contains("PERSONAL PROJECTS") ||
                   line.contains("OPEN SOURCE CONTRIBUTIONS") {
                    wattron(contentWin, COLOR_PAIR(4) | A_BOLD)
                    mvwaddwstr(contentWin, i32, 0, swiftStringToWcharTArray(line))
                    wattroff(contentWin, COLOR_PAIR(4) | A_BOLD)
                } else if line.contains("at ") && line.contains("Present") {
                    // Job titles
                    wattron(contentWin, COLOR_PAIR(5))
                    mvwaddwstr(contentWin, i32, 0, swiftStringToWcharTArray(line))
                    wattroff(contentWin, COLOR_PAIR(5))
                } else if line.contains("•") {
                    // List items
                    wattron(contentWin, COLOR_PAIR(6))
                    mvwaddwstr(contentWin, i32, 0, swiftStringToWcharTArray(line))
                    wattroff(contentWin, COLOR_PAIR(6))
                } else if line.contains("[█") {
                    // Skill bars
                    wattron(contentWin, A_BOLD)
                    mvwaddwstr(contentWin, i32, 0, swiftStringToWcharTArray(line))
                    wattroff(contentWin, A_BOLD)
                } else {
                    mvwaddwstr(contentWin, i32, 0, swiftStringToWcharTArray(line))
                }
            }
        }

        wrefresh(contentWin)
    }

    // Function to refresh all windows
    func refreshAll() {
        // Global border for the entire screen
        if let screen = mainScreen { // Ensure mainScreen is not nil
            box(screen, 0, 0)
        }

        if let win = headerWin { wclear(win) }
        if let win = contentWin {
            wclear(win)
            box(win, 0, 0)
        }
        if let win = footerWin { wclear(win) }

        drawHeader()
        displayContent()
        drawFooter()

        wnoutrefresh(mainScreen!) // Prepare stdscr for refresh (if it has its own direct drawing beyond sub-windows)
        if let win = headerWin { wnoutrefresh(win) }
        if let win = contentWin { wnoutrefresh(win) }
        if let win = footerWin { wnoutrefresh(win) }
        doupdate() // Perform actual refresh of all prepared windows simultaneously
    }

    // Boot screen function
    func displayBootScreen(window: OpaquePointer?) {
        guard let screen = window else { return }

        let maxY = getmaxy(screen)
        let maxX = getmaxx(screen)

        curs_set(0) // Hide cursor
        nodelay(screen, true) // Non-blocking getch

        // Matrix rain setup
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()[]{};':\",./<>?~"
        var columns = [Int32](repeating: -1, count: Int(maxX)) // Stores Y-coordinate of the head
        var columnHeadChars = [Character?](repeating: nil, count: Int(maxX)) // Stores the char for the head
        let trailLength: Int32 = 7 // Length of the trail
        let animationDurationSeconds = 8 // Run animation a bit longer
        let startTime = Date()

        // Initial clear of the screen before animation starts
        wclear(screen)
        wrefresh(screen)

        while Date().timeIntervalSince(startTime) < Double(animationDurationSeconds) {
            if getch() != ERR { break } // Exit on key press

            // No wclear(screen) inside the main animation loop for trails

            for x in 0..<Int(maxX) {
                let currentHeadY = columns[x]

                if currentHeadY != -1 { // If drop is active in this column
                    // 1. Clear the character at the very end of the trail
                    let trailEndY = currentHeadY - trailLength
                    if trailEndY >= 0 {
                        mvwaddch(screen, trailEndY, Int32(x), UInt32(UInt8(ascii: " ")))
                    }

                    // 2. Change the old head position to a trail character (green)
                    if let headChar = columnHeadChars[x] {
                        wattron(screen, COLOR_PAIR(5)) // Green for trail
                        mvwaddwstr(screen, currentHeadY, Int32(x), swiftStringToWcharTArray(String(headChar)))
                        wattroff(screen, COLOR_PAIR(5))
                    }

                    // 3. Advance head
                    let newHeadY = currentHeadY + 1
                    if newHeadY < maxY {
                        columns[x] = newHeadY
                        // Draw new head (white, bold)
                        let headCharIndex = characters.index(characters.startIndex, offsetBy: Int.random(in: 0..<characters.count))
                        let newHeadRandomChar = characters[headCharIndex]
                        columnHeadChars[x] = newHeadRandomChar // Store for next frame's trail
                        
                        wattron(screen, COLOR_PAIR(7) | A_BOLD) // White & Bold for new head
                        mvwaddwstr(screen, newHeadY, Int32(x), swiftStringToWcharTArray(String(newHeadRandomChar)))
                        wattroff(screen, COLOR_PAIR(7) | A_BOLD)
                    } else {
                        // Drop has gone off screen (head reached bottom)
                        // To ensure the full trail clears, continue moving 'head' conceptually
                        // until trailEndY also goes off screen.
                        // For simplicity now, we'll just make it inactive.
                        // A more advanced approach would handle this gracefully.
                        if trailEndY < maxY { // If trail is still on screen, keep 'active' to clear it
                             columns[x] = newHeadY // let it go off screen
                        } else {
                             columns[x] = -1 // Fully off screen, make inactive
                             columnHeadChars[x] = nil
                        }
                    }
                } else { // Drop is inactive, try to start a new one
                    if Int.random(in: 0...100) < 3 { // Lowered probability for sparser rain
                        columns[x] = 0 // Start at top
                        let headCharIndex = characters.index(characters.startIndex, offsetBy: Int.random(in: 0..<characters.count))
                        let newHeadRandomChar = characters[headCharIndex]
                        columnHeadChars[x] = newHeadRandomChar

                        wattron(screen, COLOR_PAIR(7) | A_BOLD) // White & Bold for new head
                        mvwaddwstr(screen, 0, Int32(x), swiftStringToWcharTArray(String(newHeadRandomChar)))
                        wattroff(screen, COLOR_PAIR(7) | A_BOLD)
                    }
                }
            }

            wrefresh(screen)
            usleep(80000) // 80ms delay, adjust for desired speed
        }

        nodelay(screen, false) // Blocking getch again
        wclear(screen) // CRUCIAL: Clear screen before returning to ensure main UI has a clean slate
    }

    // Display boot screen first
    displayBootScreen(window: mainScreen)

    // Initial display
    refreshAll()

    // Main input loop
    while true {
        let ch = getch()

        switch ch {
        case 113, 81: // 'q' or 'Q'
            return
        case 9: // '\t'
            // Switch to next tab
            currentTabIndex = (currentTabIndex + 1) % tabs.count
            scrollPosition = 0
            drawHeader()
            displayContent()
        case 259: // KEY_UP
            // Scroll up
            if scrollPosition > 0 {
                scrollPosition -= 1
                displayContent()
            }
        case 258: // KEY_DOWN
            // Scroll down
            let currentContent = getCurrentTabContent(resume: resume, tabIndex: currentTabIndex)
            let linesCount = currentContent.split(separator: "\n").count
            let contentMaxYscroll = getmaxy(contentWin)
            if scrollPosition < linesCount - Int(contentMaxYscroll) && linesCount > Int(contentMaxYscroll) {
                scrollPosition += 1
                displayContent()
            }
        case 260: // KEY_LEFT
            // Switch to previous tab
            currentTabIndex = (currentTabIndex - 1 + tabs.count) % tabs.count
            scrollPosition = 0
            drawHeader()
            displayContent()
        case 261: // KEY_RIGHT
            // Switch to next tab
            currentTabIndex = (currentTabIndex + 1) % tabs.count
            scrollPosition = 0
            drawHeader()
            displayContent()
        default:
            break
        }
    }
}

// Helper function to get content for the current tab
func getCurrentTabContent(resume: Resume, tabIndex: Int) -> String {
    switch tabIndex {
    case 0: return formatOverviewTab(resume: resume)
    case 1: return formatExperienceTab(resume: resume)
    case 2: return formatSkillsTab(resume: resume)
    case 3: return formatProjectsTab(resume: resume)
    case 4: return formatContributionsTab(resume: resume)
    default: return ""
    }
}

// MARK: - Tab Formatting Functions

// Formats the overview tab content
func formatOverviewTab(resume: Resume) -> String {
    var content = "\n  \(resume.name)\n\n"

    // Contact information
    content += "  CONTACT INFORMATION\n"
    content += "  " + String(repeating: "─", count: 30) + "\n\n"

    if let email = resume.contact.email {
        content += "  📧 Email: \(email)\n"
    }
    if let phone = resume.contact.phone {
        content += "  📱 Phone: \(phone)\n"
    }
    if let website = resume.contact.website {
        content += "  🌐 Website: \(website)\n"
    }
    if let linkedin = resume.contact.linkedin {
        content += "  👔 LinkedIn: \(linkedin)\n"
    }
    if let github = resume.contact.github {
        content += "  💻 GitHub: \(github)\n"
    }

    // Profile/Summary
    content += "\n  PROFESSIONAL SUMMARY\n"
    content += "  " + String(repeating: "─", count: 30) + "\n\n"
    content += wrapText(resume.profile, indent: 2, width: 80)

    // Education
    content += "\n\n  EDUCATION\n"
    content += "  " + String(repeating: "─", count: 30) + "\n\n"

    for edu in resume.education {
        content += "  \(edu.degree)\n"
        var institutionText = "  \(edu.institution)"
        if let year = edu.graduationYear {
            institutionText += " (\(year))"
        }
        content += institutionText + "\n"

        if let details = edu.details {
            content += "  \(details)\n"
        }
        content += "\n"
    }

    return content
}

// Formats the experience tab content
func formatExperienceTab(resume: Resume) -> String {
    var content = "\n  WORK EXPERIENCE\n"
    content += "  " + String(repeating: "─", count: 30) + "\n\n"

    for job in resume.experience {
        content += "  \(job.title) at \(job.company)\n"
        content += "  📅 \(job.startDate) - \(job.endDate ?? "Present") | 📍 \(job.location)\n\n"

        // App Store link if available
        if let appStoreUrl = job.appStoreUrl, !appStoreUrl.isEmpty {
            content += "  🔗 App Store: \(appStoreUrl)\n"
        }

        // Media URLs if available
        if let mediaUrls = job.mediaUrls, !mediaUrls.isEmpty {
            content += "  🔗 Media Links:\n"
            for url in mediaUrls {
                content += "    • \(url)\n"
            }
            content += "\n"
        }

        // Responsibilities
        content += "  Key Responsibilities:\n"
        for responsibility in job.responsibilities {
            content += wrapText("    • \(responsibility)", indent: 6, width: 80)
            content += "\n"
        }

        content += "\n  " + String(repeating: "─", count: 50) + "\n\n"
    }

    return content
}

// Formats the skills tab content
func formatSkillsTab(resume: Resume) -> String {
    var content = "\n  TECHNICAL SKILLS\n"
    content += "  " + String(repeating: "─", count: 30) + "\n\n"

    // Programming Languages section
    content += "  PROGRAMMING LANGUAGES\n"
    content += "  " + String(repeating: "─", count: 30) + "\n\n"

    // Sort languages by rating (descending) and then alphabetically
    let sortedLanguages = resume.skills.programmingLanguages
        .sorted {
            if $0.rating != $1.rating {
                return $0.rating > $1.rating
            }
            return $0.name < $1.name
        }

    for language in sortedLanguages {
        content += createSkillBar(skill: language, maxWidth: 30)
        content += "\n"
    }

    content += "\n"

    // SDKs & APIs section
    content += "  SDKs & APIs\n"
    content += "  " + String(repeating: "─", count: 30) + "\n"

    // Sort SDKs/APIs by rating (descending) and then alphabetically
    let sortedSDKs = resume.skills.sdksApis
        .sorted {
            if $0.rating != $1.rating {
                return $0.rating > $1.rating
            }
            return $0.name < $1.name
        }

    for sdk in sortedSDKs {
        content += createSkillBar(skill: sdk, maxWidth: 30)
        content += "\n"
    }

    return content
}

// Formats the projects tab content
func formatProjectsTab(resume: Resume) -> String {
    var content = "\n  PERSONAL PROJECTS\n"
    content += "  " + String(repeating: "─", count: 30) + "\n\n"

    for project in resume.personalProjects {
        content += "  \(project.name)\n"

        // Project description
        if let description = project.description {
            content += wrapText(description, indent: 2, width: 80)
            content += "\n"
        }

        // Technologies used
        if let technologies = project.technologies, !technologies.isEmpty {
            content += "  🔧 Technologies:\n"
            content += "    \(technologies.joined(separator: ", "))\n"
        }

        // App Store link
        if let appStoreLink = project.appStoreLink, !appStoreLink.isEmpty {
            content += "  📱 App Store: \(appStoreLink)\n"
        }

        // Other links
        if let links = project.links, !links.isEmpty {
            content += "  🔗 Links:\n"
            for link in links {
                content += "    • \(link.title): \(link.url)\n"
            }
        }

        content += "\n  " + String(repeating: "─", count: 50) + "\n\n"
    }

    return content
}

// Formats the open source contributions tab content
func formatContributionsTab(resume: Resume) -> String {
    var content = "\n  OPEN SOURCE CONTRIBUTIONS\n"
    content += "  " + String(repeating: "─", count: 30) + "\n\n"

    for contribution in resume.openSourceContributions {
        content += "  \(contribution.name)\n"

        // Contribution description
        if let description = contribution.description {
            content += wrapText(description, indent: 2, width: 80)
            content += "\n"
        }

        // Links (including PRs)
        if let links = contribution.links, !links.isEmpty {
            content += "  🔗 Links:\n"
            for link in links {
                // Check if it's a PR link
                let isPR = link.title.contains("PR") || link.url.contains("/pull/")
                content += "    • \(isPR ? "🔀" : "🔗") \(link.title): \(link.url)\n"
            }
        }

        content += "\n  " + String(repeating: "─", count: 50) + "\n\n"
    }

    return content
}

// MARK: - Helper Functions

// Creates a skill bar visualization
func createSkillBar(skill: Skill, maxWidth: Int) -> String {
    let barWidth = Int((Double(skill.rating) / 5.0) * Double(maxWidth))
    let emptyWidth = maxWidth - barWidth

    // Create the bar with filled and empty parts
    let filledBar = String(repeating: "█", count: barWidth)
    let emptyBar = String(repeating: "░", count: emptyWidth)

    // Return the formatted string
    return "  \(skill.name.padding(toLength: 20, withPad: " ", startingAt: 0)) [\(filledBar)\(emptyBar)] (\(skill.rating)/5)"
}

// Wraps text to fit within a specified width
func wrapText(_ text: String, indent: Int = 0, width: Int) -> String {
    var result = ""
    var currentLine = ""
    let indentStr = String(repeating: " ", count: indent)

    let words = text.split(separator: " ")

    for word in words {
        let wordStr = String(word)
        if currentLine.isEmpty {
            currentLine = indentStr + wordStr
        } else if currentLine.count + wordStr.count + 1 <= width {
            currentLine += " " + wordStr
        } else {
            result += currentLine + "\n"
            currentLine = indentStr + wordStr
        }
    }

    if !currentLine.isEmpty {
        result += currentLine
    }

    return result
}

// MARK: - Main Execution

do {
    // Load resume data from YAML file
    let resume = try YAMLParser.loadResume()

    // Run the resume TUI
    try runResumeTUI(resume: resume)
    exit(0) // Explicitly exit with success code after TUI finishes
} catch YAMLError.fileNotFound {
    print("Error: Resume YAML file not found.")
    print("Make sure 'resume.yaml' is in the current directory or properly included in the package resources.")
    exit(1)
} catch YAMLError.parsingError(let message) {
    print("Error parsing YAML file: \(message)")
    exit(1)
} catch {
    print("Unexpected error: \(error.localizedDescription)")
    exit(1)
}
