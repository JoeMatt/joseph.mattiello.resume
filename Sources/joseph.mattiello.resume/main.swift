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
    // Pair 4: Section headers like "TECHNICAL SKILLS" (e.g., yellow on black for emphasis)
    init_pair(4, Int16(COLOR_YELLOW), Int16(COLOR_BLACK))
    // Pair 5: Job titles or other important highlights (e.g., green on black)
    init_pair(5, Int16(COLOR_GREEN), Int16(COLOR_BLACK))
    // Pair 6: List items, skill names, or secondary info (e.g., cyan on black)
    init_pair(6, Int16(COLOR_CYAN), Int16(COLOR_BLACK))
    // Pair 7: For skill bars (example: white on a slightly darker shade, or just bolded default)
    // init_pair(7, Int16(COLOR_WHITE), Int16(COLOR_DARKGRAY)) // COLOR_DARKGRAY might not be standard
    // Or simply use A_BOLD with default colors for skill bars if Pair 3 is black background.
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

        wclear(screen) // Clear the screen for the boot display
        
        // "L33t" style name
        let nameArt = [
            "   J0$3Ph M47713LL0'S R3$UM3   "
        ]

        // Calculate starting Y position to center the art vertically
        let artHeight = Int32(nameArt.count)
        let textStartY = (maxY - artHeight - 5) / 2 // -5 for the box below

        // Display ASCII art name
        wattron(screen, A_BOLD)
        for (i, line) in nameArt.enumerated() {
            let lineY = textStartY + Int32(i)
            let lineX = (maxX - Int32(line.count)) / 2
            mvwaddwstr(screen, lineY, lineX, swiftStringToWcharTArray(line))
        }
        wattroff(screen, A_BOLD)
        wrefresh(screen) // Refresh the main screen to show the ASCII art before drawing the prompt box

        // "Press any key to continue" box
        let prompt = " Press any key to continue... "
        let promptWidth = Int32(prompt.count)
        let boxHeight: Int32 = 3 // For a box with 1 line of text inside
        let boxWidth = promptWidth + 2 // +2 for side borders of the box() function

        let boxY = textStartY + artHeight + 2 // 2 lines below the art
        let boxX = (maxX - boxWidth) / 2

        // Create a new window for the prompt box
        let promptWin = newwin(boxHeight, boxWidth, boxY, boxX)
        guard let promptWin = promptWin else {
            // Fallback if window creation fails, though unlikely here
            mvwaddwstr(screen, boxY + 1, boxX + 1, swiftStringToWcharTArray(prompt))
            wrefresh(screen)
            getch()
            return
        }

        box(promptWin, 0, 0) // Draw a box around the new window
        mvwaddwstr(promptWin, 1, 1, swiftStringToWcharTArray(prompt)) // Text inside the box (y=1, x=1 relative to promptWin)
        
        wrefresh(promptWin) // Refresh the prompt window to display it
        // wrefresh(screen) // Refresh the main screen if there were other changes (not strictly needed here as promptWin is on top)

        getch()          // Wait for key press

        delwin(promptWin) // Delete the prompt window after use
        // Need to touch and refresh the area on stdscr that was covered by promptWin
        // or clear and refresh the whole screen if we want to ensure no artifacts.
        // For simplicity now, a full refresh of the main screen will happen when the main UI loads.
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
    var content = "  TECHNICAL SKILLS\n"
    content += "  " + String(repeating: "─", count: 30) + "\n"
    
    // Programming Languages section
    content += "  PROGRAMMING LANGUAGES\n"
    content += "  " + String(repeating: "─", count: 30) + "\n"
    
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
