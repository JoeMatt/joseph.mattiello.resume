// Joseph Mattiello Resume CLI Application
// A terminal-based resume viewer using TermKit

import Foundation
import TermKit

// Main application entry point
@main
struct ResumeApp {
    static func main() {
        do {
            // Load resume data from YAML file
            let resume = try YAMLParser.loadResume()
            
            // Configure and run the TermKit application
            let app = Application()
            app.contentView = MainView(resume: resume)
            app.title = "Joseph Mattiello's Resume"
            app.run()
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
    }
}
