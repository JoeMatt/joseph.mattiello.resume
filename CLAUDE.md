# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Joseph Mattiello's interactive resume — a Swift-based TUI (Terminal User Interface) application that renders resume data from a YAML file using ncurses. It also includes Python scripts to generate HTML/PDF and Markdown versions.

## Build & Run Commands

### Swift TUI App
```bash
swift build                    # Debug build
swift build -c release         # Release build
swift run                      # Build and run the TUI app
swift test                     # Run tests
```

### Resume Generation (Python)
```bash
pip install -r requirements.txt   # Install Python deps (PyYAML, PyLaTeX, Jinja2, WeasyPrint)
make html                         # Generate HTML/PDF resume (output/resume.pdf)
make md                           # Generate Markdown README from resume.yaml
make all                          # Generate all formats
make clean                        # Remove generated files
```

### Prerequisites
- Swift 6.0+ toolchain
- ncurses (`brew install ncurses` on macOS)
- Python 3 with dependencies in `requirements.txt` (for HTML/PDF/Markdown generation)

## Architecture

### Data Flow
`resume.yaml` (single source of truth) -> parsed by either Swift (Yams) or Python (PyYAML) -> rendered as TUI, HTML/PDF, or Markdown.

### Swift TUI App
- **`Sources/joseph.mattiello.resume/main.swift`** — `ResumeTUI` struct: ncurses setup, input loop, tab/scroll/search handling, all TUI state management
- **`Sources/joseph.mattiello.resume/ResumeTUI+*.swift`** — Tab rendering extensions: Overview, Experience, Skills, Projects, Contributions, MatrixBootScreen
- **`Sources/joseph.mattiello.resume/Models/ResumeModels.swift`** — Codable structs (`Resume`, `Contact`, `Experience`, `Project`, `Skills`, `Education`) mapping to `resume.yaml`
- **`Sources/joseph.mattiello.resume/Utilities/YAMLParser.swift`** — YAML loading via Yams
- **`Sources/Cncurses/`** — C shim bridging ncurses for Swift (expects Homebrew ncurses at `/opt/homebrew/opt/ncurses/`)

### Python Scripts
- **`generate_html_resume.py`** — Generates HTML resume from `resume.yaml` using Jinja2 template (`templates/resume_template.html`) and converts to PDF via WeasyPrint -> `output/resume.pdf`
- **`generate_readme.py`** — Generates `README.md` from `resume.yaml`
- **`generate_resume.py`** — LaTeX resume generation (extended script)

### Key Files
- **`resume.yaml`** — All resume content lives here; also bundled as a Swift resource via `Resources/resume.yaml`
- **`install.sh`** — One-liner installer that clones, builds, and runs the TUI app
- **`.github/workflows/release.yml`** — CI: builds arm64 binary + PDF, auto-creates GitHub releases with patch version bumps on push to master

## CI/CD

Pushes to `master` trigger the release workflow which builds the Swift app (arm64), generates the PDF resume, and creates a GitHub release with both artifacts. Uses Swift 6.1 toolchain installed via PKG in CI.
