import Foundation
import Cncurses

// Matrix Boot Screen implementation inspired by cmatrix
extension ResumeTUI {
    
    // MARK: - Matrix Character Structure
    private struct MatrixChar {
        var char: Character
        var brightness: Int // 3 = bold new, 2 = normal, 1 = dim, 0 = very dim
        
        init(char: Character = " ", brightness: Int = 0) {
            self.char = char
            self.brightness = brightness
        }
    }
    
    // MARK: - Static Text Position
    private struct StaticTextPosition {
        let text: String
        let y: Int32
        let x: Int32
        let bold: Bool
    }
    
    // MARK: - Matrix Boot Screen
    @MainActor
    static func displayMatrixBootScreen() {
        guard let screen = tuiState.screen else { return }
        let maxY = getmaxy(screen)
        let maxX = getmaxx(screen)
        
        // Static text content
        let titleText = "Joseph Mattiello's Resume"
        let promptText = "Press any key to continue..."
        let spinnerChars = ["|", "/", "-", "\\"]
        var spinnerIndex = 0
        
        // Colors
        let matrixColorPair = Cncurses.COLOR_PAIR(4) // Green on Black
        let overlayColorPair = Cncurses.COLOR_PAIR(8) // Black on Green for static text
        let defaultColorPair = Cncurses.COLOR_PAIR(0) // Default colors
        
        // Calculate positions for static text
        let titleY = maxY / 2 - 2
        let titleX = (maxX - Int32(titleText.count)) / 2
        let promptY = maxY / 2
        let promptX = (maxX - Int32(promptText.count)) / 2
        let spinnerY = maxY / 2 + 2
        let spinnerX = maxX / 2
        
        // Matrix rain data structure - 2D array of (character, brightness)
        var matrixChars = Array(repeating: Array(repeating: MatrixChar(), count: Int(maxX)), count: Int(maxY))
        
        // Setup screen
        curs_set(0) // Hide cursor
        clear()
        wbkgd(screen, chtype(matrixColorPair))
        refresh()
        
        // Non-blocking input for animation
        nodelay(screen, true)
        
        // Character set for matrix rain
        let matrixCharSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:*+=%#@!?^~$<>()[]{}/\\"
        
        var keyPressed = false
        while !keyPressed {
            // 1. Update matrix rain - shift everything down one row
            for y in (1..<Int(maxY)).reversed() {
                for x in 0..<Int(maxX) {
                    matrixChars[y][x] = matrixChars[y-1][x]
                    // Dim the character as it moves down
                    if matrixChars[y][x].brightness > 0 {
                        matrixChars[y][x].brightness -= 1
                    }
                }
            }
            
            // 2. Generate new characters for top row
            for x in 0..<Int(maxX) {
                if Int.random(in: 0..<4) == 0 { // 25% chance of new character
                    let randomChar = matrixCharSet.randomElement()!
                    matrixChars[0][x] = MatrixChar(char: randomChar, brightness: 3) // New chars start at max brightness
                } else {
                    matrixChars[0][x] = MatrixChar() // Empty space
                }
            }
            
            // 3. Clear the screen for this frame
            clear()
            
            // 4. Draw the matrix rain
            for y in 0..<Int(maxY) {
                for x in 0..<Int(maxX) {
                    let matrixChar = matrixChars[y][x]
                    if matrixChar.char != " " {
                        var attr = matrixColorPair
                        if matrixChar.brightness == 3 {
                            attr |= ResumeTUI.A_BOLD
                        }
                        // Note: brightness 2 is normal, 1 and 0 would be dim if terminal supports it
                        wattron(screen, attr)
                        mvwaddch(screen, Int32(y), Int32(x), chtype(UInt32(String(matrixChar.char).unicodeScalars.first!.value)))
                        wattroff(screen, attr)
                    }
                }
            }
            
            // 5. Draw static text over the matrix rain (with reverse color for visibility)
            // Title
            attron(overlayColorPair | ResumeTUI.A_BOLD)
            _ = titleText.withCString { mvaddstr(titleY, titleX, $0) }
            attroff(overlayColorPair | ResumeTUI.A_BOLD)
            
            // Prompt
            attron(overlayColorPair | ResumeTUI.A_BOLD)
            _ = promptText.withCString { mvaddstr(promptY, promptX, $0) }
            attroff(overlayColorPair | ResumeTUI.A_BOLD)
            
            // Spinner
            spinnerIndex = (spinnerIndex + 1) % spinnerChars.count
            let spinnerChar = spinnerChars[spinnerIndex]
            attron(overlayColorPair | ResumeTUI.A_BOLD)
            _ = spinnerChar.withCString { mvaddstr(spinnerY, spinnerX, $0) }
            attroff(overlayColorPair | ResumeTUI.A_BOLD)
            
            // 6. Refresh screen
            refresh()
            
            // 7. Check for keypress
            if getch() != ERR {
                keyPressed = true
            }
            
            napms(90) // Animation speed
        }
        
        // Cleanup
        nodelay(screen, false)
        curs_set(1) // Restore cursor
        
        // Reset screen for main UI
        wbkgd(screen, chtype(defaultColorPair))
        clear()
        refresh()
    }
}
