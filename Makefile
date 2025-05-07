# Makefile for resume generation
# Targets:
#   make html    - Generate HTML resume
#   make latex   - Generate LaTeX resume (placeholder)
#   make md      - Generate Markdown README
#   make all     - Generate all formats (default)

.PHONY: all html latex md markdown clean

# Default target
all: html latex md

# Generate HTML resume
html:
	@echo "Generating HTML resume..."
	python generate_html_resume.py
	@echo "HTML resume generated successfully!"

# Generate LaTeX resume (placeholder)
latex:
	@echo "Generating LaTeX resume..."
	# Add LaTeX generation command here when available
	@echo "LaTeX resume generation is not yet implemented."

# Generate Markdown README
md: markdown

markdown:
	@echo "Generating Markdown README..."
	python generate_readme.py
	@echo "Markdown README generated successfully!"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -f output/resume.html output/resume.pdf README.md
	@echo "Cleaned generated files."

# Help target
help:
	@echo "Available targets:"
	@echo "  make          - Generate all resume formats (HTML, LaTeX, Markdown)"
	@echo "  make html     - Generate HTML resume"
	@echo "  make latex    - Generate LaTeX resume (not yet implemented)"
	@echo "  make md       - Generate Markdown README"
	@echo "  make markdown - Same as 'make md'"
	@echo "  make clean    - Remove all generated files"
	@echo "  make help     - Display this help message"
