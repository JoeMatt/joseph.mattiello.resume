#!/bin/bash

# Joseph Mattiello's Resume CLI Installer
# This script installs and runs the resume CLI application
# Usage: curl -fsSL https://raw.githubusercontent.com/JoeMatt/joseph.mattiello.resume/master/install.sh | bash

set -e

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Print banner
echo -e "${BLUE}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                           ║"
echo "  ║             Joseph Mattiello's Resume Installer           ║"
echo "  ║                                                           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for --uninstall flag
if [ "$1" == "--uninstall" ]; then
    CONFIG_DIR_BASE="$HOME/.config/joseph.mattiello.resume"
    INSTALL_INFO_FILE_BASE="$CONFIG_DIR_BASE/install_info.txt"

    uninstall_application() {
        echo -e "${YELLOW}Attempting to uninstall Joseph Mattiello's Resume...${NC}"

        if [ ! -f "$INSTALL_INFO_FILE_BASE" ]; then
            echo -e "${RED}Error: Installation information not found at $INSTALL_INFO_FILE_BASE.${NC}"
            echo -e "${YELLOW}The application might not have been installed with the permanent option, or the info file was removed.${NC}"
            echo -e "${YELLOW}Please locate and remove the binary manually if needed.${NC}"
            exit 1
        fi

        INSTALLED_EXECUTABLE_PATH=$(cat "$INSTALL_INFO_FILE_BASE")

        if [ -z "$INSTALLED_EXECUTABLE_PATH" ]; then
            echo -e "${RED}Error: Installation path in $INSTALL_INFO_FILE_BASE is empty.${NC}"
            rm -f "$INSTALL_INFO_FILE_BASE"
            echo -e "${YELLOW}Removed corrupted info file. Please locate and remove the binary manually if needed.${NC}"
            exit 1
        fi

        if [ ! -f "$INSTALLED_EXECUTABLE_PATH" ]; then
            echo -e "${RED}Error: The installed executable at $INSTALLED_EXECUTABLE_PATH was not found.${NC}"
            echo -e "${YELLOW}It might have been moved or deleted already.${NC}"
            read -p "Do you want to remove the installation info file ($INSTALL_INFO_FILE_BASE) anyway? (y/N): " REMOVE_INFO_CHOICE
            if [[ "$REMOVE_INFO_CHOICE" =~ ^[Yy]$ ]]; then
                rm -f "$INSTALL_INFO_FILE_BASE"
                echo -e "${GREEN}Removed $INSTALL_INFO_FILE_BASE.${NC}"
            fi
            exit 1
        fi

        echo -e "${YELLOW}Found installed application at: ${GREEN}$INSTALLED_EXECUTABLE_PATH${NC}"
        read -p "Are you sure you want to remove it? (y/N): " CONFIRM_UNINSTALL

        if [[ "$CONFIRM_UNINSTALL" =~ ^[Yy]$ ]]; then
            rm -f "$INSTALLED_EXECUTABLE_PATH" && \
            rm -f "$INSTALL_INFO_FILE_BASE" && \
            echo -e "${GREEN}Successfully uninstalled Joseph Mattiello's Resume from $INSTALLED_EXECUTABLE_PATH.${NC}"
            echo -e "${GREEN}Removed installation info file $INSTALL_INFO_FILE_BASE.${NC}"
            echo -e "${YELLOW}Please remember to manually remove any shell alias you might have created (e.g., in ~/.bashrc or ~/.zshrc).${NC}"
            echo -e "${YELLOW}You may also remove the configuration directory ${GREEN}$CONFIG_DIR_BASE${YELLOW} if you wish.${NC}"
        else
            echo -e "${YELLOW}Uninstallation cancelled.${NC}"
        fi
        exit 0
    }

    uninstall_application
fi

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo -e "${RED}Error: Swift is not installed on your system.${NC}"
    OS_TYPE=$(uname -s)
    if [ "$OS_TYPE" == "Darwin" ]; then
        echo -e "${YELLOW}On macOS, you can install Swift by installing the Xcode Command Line Tools.${NC}"
        echo -e "${YELLOW}Try running: ${GREEN}xcode-select --install${NC}"
        echo -e "${YELLOW}Alternatively, check for updates in System Settings > Software Update, which might prompt for Command Line Tools installation.${NC}"
    elif [ "$OS_TYPE" == "Linux" ]; then
        echo -e "${YELLOW}On Linux, you can install Swift using your distribution's package manager.${NC}"
        echo -e "${YELLOW}For Debian/Ubuntu, try: ${GREEN}sudo apt update && sudo apt install swiftlang${NC}"
        echo -e "${YELLOW}For Fedora, try: ${GREEN}sudo dnf install swift-lang${NC}"
        echo -e "${YELLOW}For other distributions, please refer to ${GREEN}https://www.swift.org/download/${NC} for instructions.${NC}"
    else
        echo -e "${YELLOW}Swift installation instructions for your OS (${OS_TYPE}) are not available here.${NC}"
        echo -e "${YELLOW}Please visit ${GREEN}https://www.swift.org/download/${NC} for instructions.${NC}"
    fi
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Creating temporary directory at ${TEMP_DIR}${NC}"

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up temporary files and script...${NC}"
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then # Check if TEMP_DIR is set and is a directory
        rm -rf "$TEMP_DIR"
    fi
    # $0 is the path to the script.
    # Ensure it's a regular file and not something like '-' or '/dev/stdin' from a pipe.
    # The check also avoids paths like /proc/self/fd/NN which can occur with process substitution.
    if [ -f "$0" ] && [[ "$0" != "-" && "$0" != "/dev/stdin" && ! "$0" =~ ^/proc/self/fd/ ]]; then
        echo -e "${YELLOW}Removing installer script: $0${NC}"
        rm -- "$0"
    else
        # This case should ideally not be hit with 'bash install.sh' usage.
        echo -e "${YELLOW}Installer script ('$0') is not a regular file or standard path, not removing.${NC}"
    fi
}

# Register the cleanup function to be called on exit, also trapping common interrupt signals
trap cleanup EXIT HUP INT QUIT TERM

# Check for git
HAS_GIT=0
if command -v git &> /dev/null; then
    HAS_GIT=1
fi

# Clone the repository or download zip
echo -e "${YELLOW}Getting the resume repository...${NC}"
if [ $HAS_GIT -eq 1 ]; then
    # Try to clone with git first
    if git clone https://github.com/JoeMatt/joseph.mattiello.resume.git "$TEMP_DIR/resume" 2>/dev/null; then
        echo -e "${GREEN}Successfully cloned the repository.${NC}"
    else
        echo -e "${YELLOW}Git clone failed, falling back to zip download.${NC}"
        HAS_GIT=0
    fi
fi

# If git failed or not available, try downloading zip
if [ $HAS_GIT -eq 0 ]; then
    echo -e "${YELLOW}Attempting to download as a zip file...${NC}"
    if command -v curl &> /dev/null; then
        echo -e "${YELLOW}Downloading with curl...${NC}"
        if ! curl -fsSL https://github.com/JoeMatt/joseph.mattiello.resume/archive/main.zip -o "$TEMP_DIR/resume.zip"; then
            echo -e "${RED}Curl download failed.${NC}"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        echo -e "${YELLOW}Downloading with wget...${NC}"
        if ! wget -q https://github.com/JoeMatt/joseph.mattiello.resume/archive/main.zip -O "$TEMP_DIR/resume.zip"; then
            echo -e "${RED}Wget download failed.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Error: Neither git, curl, nor wget is installed.${NC}"
        echo -e "Please install one of these tools and try again."
        exit 1
    fi
    
    # Check if unzip is available
    if ! command -v unzip &> /dev/null; then
        echo -e "${RED}Error: unzip is not installed.${NC}"
        echo -e "Please install unzip and try again."
        exit 1
    fi
    
    # Extract the zip file
    echo -e "${YELLOW}Extracting zip file...${NC}"
    if ! unzip -q "$TEMP_DIR/resume.zip" -d "$TEMP_DIR"; then
        echo -e "${RED}Failed to extract the zip file.${NC}"
        exit 1
    fi
    
    # Move extracted directory to expected location
    if [ -d "$TEMP_DIR/joseph.mattiello.resume-main" ]; then
        mv "$TEMP_DIR/joseph.mattiello.resume-main" "$TEMP_DIR/resume"
    else
        echo -e "${RED}Error: Expected directory 'joseph.mattiello.resume-main' not found in zip file.${NC}"
        echo -e "${YELLOW}Contents of $TEMP_DIR after unzip:${NC}"
        ls -la "$TEMP_DIR"
        exit 1
    fi
fi

# Change to the repository directory
if [ ! -d "$TEMP_DIR/resume" ]; then
    echo -e "${RED}Error: Resume directory '$TEMP_DIR/resume' not found after clone/download.${NC}"
    exit 1
fi
cd "$TEMP_DIR/resume"

# Function to ensure ncurses (or equivalent) is installed
ensure_ncurses_installed() {
    echo -e "${YELLOW}Checking for ncurses (required for TUI)...${NC}"
    OS_TYPE=$(uname -s)

    if [ "$OS_TYPE" == "Darwin" ]; then # macOS
        if command -v brew &> /dev/null; then
            if brew list ncurses &> /dev/null; then
                echo -e "${GREEN}ncurses already installed via Homebrew.${NC}"
            else
                echo -e "${YELLOW}ncurses not found. Attempting to install with Homebrew...${NC}"
                if brew install ncurses; then
                    echo -e "${GREEN}ncurses installed successfully via Homebrew.${NC}"
                else
                    echo -e "${RED}Failed to install ncurses with Homebrew.${NC}"
                    echo -e "${YELLOW}Please try installing it manually or ensure Homebrew is correctly configured.${NC}"
                    exit 1
                fi
            fi
        else
            echo -e "${RED}Homebrew not found.${NC}"
            echo -e "${YELLOW}ncurses is required. Please install Homebrew (https://brew.sh/) and then run 'brew install ncurses', or install ncurses manually.${NC}"
            exit 1
        fi
    elif [ "$OS_TYPE" == "Linux" ]; then
        # Try common package managers for ncurses development libraries
        if command -v apt-get &> /dev/null; then
            if dpkg -s libncursesw5-dev &> /dev/null || dpkg -s libncurses-dev &> /dev/null; then
                 echo -e "${GREEN}ncurses development libraries already installed (apt).${NC}"
            else
                echo -e "${YELLOW}Attempting to install ncurses development libraries with apt...${NC}"
                sudo apt-get update
                if sudo apt-get install -y libncursesw5-dev || sudo apt-get install -y libncurses-dev; then # Try wide char first
                    echo -e "${GREEN}ncurses development libraries installed successfully (apt).${NC}"
                else
                    echo -e "${RED}Failed to install ncurses development libraries with apt.${NC}"
                    exit 1
                fi
            fi
        elif command -v dnf &> /dev/null; then
            if dnf list installed ncurses-devel &> /dev/null; then
                echo -e "${GREEN}ncurses-devel already installed (dnf).${NC}"
            else
                echo -e "${YELLOW}Attempting to install ncurses-devel with dnf...${NC}"
                if sudo dnf install -y ncurses-devel; then
                    echo -e "${GREEN}ncurses-devel installed successfully (dnf).${NC}"
                else
                    echo -e "${RED}Failed to install ncurses-devel with dnf.${NC}"
                    exit 1
                fi
            fi
        elif command -v yum &> /dev/null; then # For older systems like CentOS 7
             if yum list installed ncurses-devel &> /dev/null; then
                echo -e "${GREEN}ncurses-devel already installed (yum).${NC}"
            else
                echo -e "${YELLOW}Attempting to install ncurses-devel with yum...${NC}"
                if sudo yum install -y ncurses-devel; then
                    echo -e "${GREEN}ncurses-devel installed successfully (yum).${NC}"
                else
                    echo -e "${RED}Failed to install ncurses-devel with yum.${NC}"
                    exit 1
                fi
            fi
        else
            echo -e "${RED}Could not find a known package manager (apt, dnf, yum) to install ncurses development libraries.${NC}"
            echo -e "${YELLOW}Please install them manually (e.g., libncursesw5-dev, ncurses-devel).${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Unsupported OS ($OS_TYPE) for automatic ncurses installation.${NC}"
        echo -e "${YELLOW}Please ensure ncurses (and its development headers) are installed manually.${NC}"
        # Optionally, you could choose to proceed with a warning or exit here
        # For now, let's proceed with a warning, the build will fail if it's truly missing.
        read -p "Proceed with build anyway? (y/N): " PROCEED_NCURSES
        if [[ ! "$PROCEED_NCURSES" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Ensure ncurses is installed before building
ensure_ncurses_installed

# Build the application
echo -e "${YELLOW}Building the resume application...${NC}"
if ! swift build; then
    echo -e "${RED}Failed to build the resume application.${NC}"
    exit 1
fi

# Offer to install the binary
echo -e "${YELLOW}Installation (Optional):${NC}"
read -p "Do you want to install 'joseph.mattiello.resume' to a permanent location? (y/N): " INSTALL_CHOICE

INSTALLED_PATH=""

if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
    DEFAULT_INSTALL_DIR="$HOME/.local/bin"
    echo -e "Suggested installation directory: ${GREEN}$DEFAULT_INSTALL_DIR${NC}"
    read -p "Enter installation directory (or press Enter for default): " CUSTOM_INSTALL_DIR
    
    INSTALL_DIR="${CUSTOM_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
    
    # Expand tilde
    INSTALL_DIR_EXPANDED="$(eval echo "$INSTALL_DIR")"
    
    if [ ! -d "$INSTALL_DIR_EXPANDED" ]; then
        echo -e "${YELLOW}Directory $INSTALL_DIR_EXPANDED does not exist. Creating it...${NC}"
        mkdir -p "$INSTALL_DIR_EXPANDED" || {
            echo -e "${RED}Failed to create directory $INSTALL_DIR_EXPANDED. Installation aborted.${NC}"
            INSTALL_CHOICE="N" # Proceed without installation
        }
    fi
    
    if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then # Check again in case directory creation failed
        SOURCE_EXECUTABLE=".build/debug/joseph.mattiello.resume"
        TARGET_EXECUTABLE="$INSTALL_DIR_EXPANDED/joseph.mattiello.resume"
        
        echo -e "${YELLOW}Installing to $TARGET_EXECUTABLE...${NC}"
        cp "$SOURCE_EXECUTABLE" "$TARGET_EXECUTABLE" && chmod +x "$TARGET_EXECUTABLE" || {
            echo -e "${RED}Failed to copy or set permissions on $TARGET_EXECUTABLE. Installation aborted.${NC}"
            INSTALL_CHOICE="N" # Proceed without installation
        }
        
        if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
            INSTALLED_PATH="$TARGET_EXECUTABLE"
            echo -e "${GREEN}Successfully installed 'joseph.mattiello.resume' to $TARGET_EXECUTABLE${NC}"

            # Save installation info for uninstaller
            CONFIG_DIR="$HOME/.config/joseph.mattiello.resume"
            INSTALL_INFO_FILE="$CONFIG_DIR/install_info.txt"
            mkdir -p "$CONFIG_DIR"
            echo "$TARGET_EXECUTABLE" > "$INSTALL_INFO_FILE"
            
            # Check if the installation directory is in PATH
            if [[ ":$PATH:" != *":$INSTALL_DIR_EXPANDED:"* ]]; then
                echo -e "${YELLOW}Note: The directory $INSTALL_DIR_EXPANDED is not in your PATH.${NC}"
                echo -e "${YELLOW}You may need to add it to your shell configuration file (e.g., ~/.bashrc, ~/.zshrc):${NC}"
                echo -e "${GREEN}  export PATH=\"$INSTALL_DIR_EXPANDED:\$PATH\"${NC}"
                echo -e "${YELLOW}Or, you can run the resume using the full path: $TARGET_EXECUTABLE${NC}"
            fi
            echo -e "${YELLOW}You can now run it by typing: ${GREEN}joseph.mattiello.resume${NC} (if $INSTALL_DIR_EXPANDED is in your PATH) or ${GREEN}$TARGET_EXECUTABLE${NC}${NC}"
        fi
    fi
fi

# Offer to help create an alias if installation was successful
if [ -n "$INSTALLED_PATH" ] && [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Alias Creation (Optional):${NC}"
    read -p "Would you like instructions to create a shell alias for easy access (e.g., 'myresume')? (y/N): " ALIAS_CHOICE
    if [[ "$ALIAS_CHOICE" =~ ^[Yy]$ ]]; then
        DEFAULT_ALIAS_NAME="myresume"
        read -p "Enter desired alias name (or press Enter for '$DEFAULT_ALIAS_NAME'): " CUSTOM_ALIAS_NAME
        ALIAS_NAME="${CUSTOM_ALIAS_NAME:-$DEFAULT_ALIAS_NAME}"
        
        echo -e "${YELLOW}To create the alias, add the following line to your shell configuration file${NC}"
        echo -e "${YELLOW}(e.g., ${GREEN}~/.bashrc${YELLOW}, ${GREEN}~/.zshrc${YELLOW}, or ${GREEN}~/.config/fish/config.fish${YELLOW}):${NC}"
        echo -e "${GREEN}alias $ALIAS_NAME='$INSTALLED_PATH'${NC}"
        echo -e "${YELLOW}After adding it, you'll need to source your config file (e.g., 'source ~/.bashrc') or open a new terminal.${NC}"
    fi
fi

# Check terminal size before running the application
MIN_COLS=100
MIN_LINES=30
CURRENT_COLS=$(tput cols 2>/dev/null || echo 0)
CURRENT_LINES=$(tput lines 2>/dev/null || echo 0)

if [ "$CURRENT_COLS" -lt "$MIN_COLS" ] || [ "$CURRENT_LINES" -lt "$MIN_LINES" ]; then
    echo -e "${YELLOW}--------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}Warning: Your current terminal size is ${CURRENT_COLS}x${CURRENT_LINES}.${NC}"
    echo -e "${YELLOW}The resume application recommends a size of at least ${MIN_COLS}x${MIN_LINES} for optimal viewing.${NC}"
    echo -e "${YELLOW}You might experience display issues or errors.${NC}"
    echo -e "${YELLOW}Please consider resizing your terminal.${NC}"
    echo -e "${YELLOW}--------------------------------------------------------------------${NC}"
    # Optionally, you could pause here and ask the user if they want to continue
    # read -p "Press Enter to attempt to run anyway, or Ctrl+C to abort..." 
fi

# Run the application
echo -e "${GREEN}Running Joseph Mattiello's Resume...${NC}"
EXECUTABLE_PATH=".build/debug/joseph.mattiello.resume"
if [ -f "$EXECUTABLE_PATH" ]; then
    "$EXECUTABLE_PATH"
else
    echo -e "${RED}Error: Executable not found at $EXECUTABLE_PATH${NC}"
    exit 1
fi

# Store the exit status
EXIT_STATUS=$?

# Exit with the same status as the resume application
exit $EXIT_STATUS
