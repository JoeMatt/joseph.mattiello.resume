// Joseph Mattiello Resume CLI Application
// A terminal-based resume viewer using Cncurses (raw C ncurses)

import Foundation
import Cncurses

// Main entry point for the application
func runResumeTUI(resume: Resume) throws { // Keeping throws for now, as later parts of the function might still use it
    // Ncurses attributes not directly imported as Swift constants due to C macro definitions
    // A_BOLD is typically (1U << (13 + 8)) = 1U << 21 = 2097152
    let A_BOLD: Int32 = 0x200000 // Or 2097152
    // You might need to define other A_* attributes (A_NORMAL, A_REVERSE, etc.) if used
    // let A_NORMAL: Int32 = 0 

    guard let mainScreen = initscr() else {
        // Or throw a custom error if the function signature remains 'throws'
        print("Error: Could not initialize ncurses screen (initscr failed).")
        return
    }
    defer { endwin() } // Ensures ncurses environment is closed properly

    if !has_colors() {
        // endwin() is handled by defer
        print("Error: Terminal does not support colors.")
        // Or throw a custom error
        return
    }
    start_color()        // Enable color manipulation
    noecho()             // Don't echo user key presses
    cbreak()             // Disable line buffering, characters are immediately available
    keypad(mainScreen, true) // Enable function keys (F1, arrow keys, etc.) for the main screen
    timeout(0)           // Set non-blocking input mode (getch() returns ERR if no input immediately)

    // Get screen dimensions
    var maxY: Int32 = 0 // ncurses functions use Int32 for coordinates and dimensions
    var maxX: Int32 = 0
    maxY = getmaxy(mainScreen) // Get Y dimension
    maxX = getmaxx(mainScreen) // Get X dimension

    // Define color pairs using C ncurses API
    // init_pair(pair_number, foreground_color_id, background_color_id)
    // COLOR_* constants are typically short, which is Int16 in Swift when imported from C
    init_pair(1, Int16(COLOR_WHITE), Int16(COLOR_BLUE))    // Header
    init_pair(2, Int16(COLOR_BLACK), Int16(COLOR_WHITE))   // Selected tab
    init_pair(3, Int16(COLOR_WHITE), Int16(COLOR_BLACK))   // Unselected tab
    init_pair(4, Int16(COLOR_YELLOW), Int16(COLOR_BLACK))  // Highlights
    init_pair(5, Int16(COLOR_GREEN), Int16(COLOR_BLACK))   // Success/positive
    init_pair(6, Int16(COLOR_CYAN), Int16(COLOR_BLACK))    // Info

    // Create tabs for different sections
    let tabs = [
        "Overview",
        "Experience",
        "Skills",
        "Projects",
        "Open Source"
    ]

    // Window variables (ncurses C API: WINDOW* is represented as OpaquePointer in Swift)
    // Standard ncurses windows are created with newwin(nlines, ncols, begin_y, begin_x)
    let headerWin: OpaquePointer? = newwin(3, maxX, 0, 0)

    let contentWin: OpaquePointer? = newwin(maxY - 4, maxX, 3, 0)
    // if let win = contentWin { scrollok(win, true) } // Example: If scrolling is needed for contentWin

    let footerWin: OpaquePointer? = newwin(1, maxX, maxY - 1, 0)
        
    // Ensure windows are not nil
    guard headerWin != nil, contentWin != nil, footerWin != nil else {
        print("Error: Could not initialize windows.")
        return
    }

    // Track current tab and scroll position
    var currentTabIndex = 0
    var scrollPosition = 0

    // Function to draw the header with tabs
    func drawHeader() {
        guard let headerWin = headerWin else { return }
        wclear(headerWin)
        wattron(headerWin, COLOR_PAIR(1) | A_BOLD)
        mvwaddstr(headerWin, 0, 0, "Joseph Mattiello's Resume")
        wattroff(headerWin, COLOR_PAIR(1) | A_BOLD)
        
        // Draw tabs
        var xPos: Int32 = 0
        for (index, tab) in tabs.enumerated() {
            let tabWidth = Int32(tab.count + 4)
            let selected = index == currentTabIndex
            let colorPairID = Int32(selected ? 2 : 3)
            
            wattron(headerWin, COLOR_PAIR(colorPairID))
            mvwaddstr(headerWin, 2, xPos, " \(tab) ")
            wattroff(headerWin, COLOR_PAIR(colorPairID))
            
            xPos += tabWidth
        }
        
        wrefresh(headerWin)
    }
    
    // Function to draw the footer
    func drawFooter() {
        guard let footerWin = footerWin else { return }
        wclear(footerWin)
        wattron(footerWin, COLOR_PAIR(1))
        mvwaddstr(footerWin, 0, 0, "TAB: Switch tabs | UP/DOWN: Scroll | Q: Quit")
        wattroff(footerWin, COLOR_PAIR(1))
        wrefresh(footerWin)
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
                    mvwaddstr(contentWin, i32, 0, line)
                    wattroff(contentWin, COLOR_PAIR(4) | A_BOLD)
                } else if line.contains("at ") && line.contains("Present") {
                    // Job titles
                    wattron(contentWin, COLOR_PAIR(5))
                    mvwaddstr(contentWin, i32, 0, line)
                    wattroff(contentWin, COLOR_PAIR(5))
                } else if line.contains("•") {
                    // List items
                    wattron(contentWin, COLOR_PAIR(6))
                    mvwaddstr(contentWin, i32, 0, line)
                    wattroff(contentWin, COLOR_PAIR(6))
                } else if line.contains("[█") {
                    // Skill bars
                    wattron(contentWin, A_BOLD)
                    mvwaddstr(contentWin, i32, 0, line)
                    wattroff(contentWin, A_BOLD)
                } else {
                    mvwaddstr(contentWin, i32, 0, line)
                }
            }
        }
        
        wrefresh(contentWin)
    }
    
    // Main loop
    var running = true
    drawHeader()
    drawFooter()
    displayContent()
    
    while running {
        let keyPress = getch()
        
        switch keyPress {
        case 113, 81: // 'q' or 'Q'
            running = false
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
    content += "  " + String(repeating: "─", count: 30) + "\n\n"
    
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
