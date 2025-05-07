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
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}

# Register the cleanup function to be called on exit
trap cleanup EXIT

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

# Build the application
echo -e "${YELLOW}Building the resume application...${NC}"
if ! swift build; then
    echo -e "${RED}Failed to build the resume application.${NC}"
    exit 1
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
