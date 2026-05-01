# VHS tape file for recording the resume TUI demo
# Run: vhs demo.tape

Output demo.gif
Output demo.webm

Set Shell "zsh"
Set FontSize 14
Set FontFamily "JetBrainsMono Nerd Font"
Set Width 1200
Set Height 700
Set Padding 20
Set Theme { "name": "Terminal Luxe", "black": "#06070b", "red": "#ff4088", "green": "#00e599", "yellow": "#f0a030", "blue": "#00c2ff", "magenta": "#c678dd", "cyan": "#56b6c2", "white": "#e4e6ea", "brightBlack": "#555960", "brightRed": "#ff4088", "brightGreen": "#00e599", "brightYellow": "#f0a030", "brightBlue": "#00c2ff", "brightMagenta": "#c678dd", "brightCyan": "#56b6c2", "brightWhite": "#ffffff", "background": "#06070b", "foreground": "#e4e6ea", "selection": "#1c2029", "cursor": "#00e599" }

# Build and run
Type "swift run --package-path ~/Workspace/resume/joseph.mattiello.resume"
Enter
Sleep 8s

# The TUI launches with the Matrix boot screen, then Overview tab
Sleep 4s

# Tab to Experience
Type "	"
Sleep 3s

# Tab to Skills
Type "	"
Sleep 3s

# Tab to Projects
Type "	"
Sleep 3s

# Tab to Contributions
Type "	"
Sleep 3s

# Scroll down a bit
Down 5
Sleep 2s

# Go back to Overview
Type "	"
Sleep 2s

# Search for something
Type "/"
Sleep 0.5s
Type "Swift"
Sleep 2s
Enter
Sleep 2s

# Quit
Type "q"
Sleep 1s
