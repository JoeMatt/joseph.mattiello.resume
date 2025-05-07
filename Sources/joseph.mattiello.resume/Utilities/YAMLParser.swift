// YAMLParser.swift
// Utility for loading and parsing YAML data

import Foundation
import Yams

enum YAMLError: Error {
    case fileNotFound
    case parsingError(String)
}

class YAMLParser {
    static func loadResume() throws -> Resume {
        var yamlPathSource = "Unknown"
        var successfullyLoadedYamlString: String? = nil
        let fileManager = FileManager.default
        let currentDirectoryPath = fileManager.currentDirectoryPath

        // 1. Try PWD/Resources/resume.yaml
        let pwdResourcesPath = "\(currentDirectoryPath)/Resources/resume.yaml"
        print("Attempting to load YAML from: PWD/Resources/resume.yaml at \(pwdResourcesPath)")
        if fileManager.fileExists(atPath: pwdResourcesPath) {
            do {
                successfullyLoadedYamlString = try String(contentsOfFile: pwdResourcesPath, encoding: .utf8)
                yamlPathSource = "PWD/Resources: \(pwdResourcesPath)"
                print("Successfully read from PWD/Resources/resume.yaml")
            } catch {
                print("Error reading from PWD/Resources/resume.yaml: \(error.localizedDescription)")
                // Continue to next try
            }
        }

        // 2. If not loaded, try PWD/resume.yaml
        if successfullyLoadedYamlString == nil {
            let pwdPath = "\(currentDirectoryPath)/resume.yaml"
            print("Attempting to load YAML from: PWD/resume.yaml at \(pwdPath)")
            if fileManager.fileExists(atPath: pwdPath) {
                do {
                    successfullyLoadedYamlString = try String(contentsOfFile: pwdPath, encoding: .utf8)
                    yamlPathSource = "PWD: \(pwdPath)"
                    print("Successfully read from PWD/resume.yaml")
                } catch {
                    print("Error reading from PWD/resume.yaml: \(error.localizedDescription)")
                    // Continue to next try
                }
            }
        }

        // 3. If not loaded, try Bundle.module.path
        if successfullyLoadedYamlString == nil {
            print("Attempting to load YAML from Bundle.module")
            if let bundlePath = Bundle.module.path(forResource: "resume", ofType: "yaml") {
                yamlPathSource = "Bundle.module: \(bundlePath)"
                print("Found bundle path: \(bundlePath)")
                if fileManager.fileExists(atPath: bundlePath) {
                    do {
                        successfullyLoadedYamlString = try String(contentsOfFile: bundlePath, encoding: .utf8)
                        print("Successfully read from Bundle.module path")
                    } catch {
                        print("Error reading from Bundle.module path \(bundlePath): \(error.localizedDescription)")
                        // Continue to error throwing
                    }
                } else {
                    print("File does NOT exist at bundle path: \(bundlePath)")
                }
            } else {
                print("resume.yaml not found in Bundle.module")
            }
        }
        
        guard let yamlString = successfullyLoadedYamlString else {
            print("YAML file could not be loaded from PWD/Resources, PWD, or Bundle.module.")
            throw YAMLError.fileNotFound
        }

        print("\nDEBUG: YAML loaded from: \(yamlPathSource)")
        print("DEBUG: ---BEGIN YAML CONTENT SNIPPET---")
        // Attempt to find and print the relevant section
        let targetCompany = "Sense Networks, Inc."
        if let companyRange = yamlString.range(of: targetCompany) {
            let searchStartIndex = yamlString.index(companyRange.lowerBound, offsetBy: -300, limitedBy: yamlString.startIndex) ?? yamlString.startIndex
            let searchEndIndex = yamlString.index(companyRange.upperBound, offsetBy: 500, limitedBy: yamlString.endIndex) ?? yamlString.endIndex
            print(String(yamlString[searchStartIndex..<searchEndIndex]))
        } else {
            print("Target company '\(targetCompany)' not found in YAML. Printing first 1000 characters:")
            print(String(yamlString.prefix(1000)))
        }
        print("DEBUG: ---END YAML CONTENT SNIPPET---\n")
        
        return try parseYAML(yamlString)
    }
    
    private static func parseYAML(_ yamlString: String) throws -> Resume {
        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(Resume.self, from: yamlString)
        } catch let error as DecodingError {
            print("Detailed YAML Decoding Error:")
            switch error {
            case .typeMismatch(let type, let context):
                print("  Type Mismatch: Expected type '\(type)' was not found.")
                print("  Coding Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("  Debug Description: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("  Value Not Found: No value was found for expected type '\(type)'.")
                print("  Coding Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("  Debug Description: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("  Key Not Found: Key '\(key.stringValue)' was not found.")
                print("  Coding Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("  Debug Description: \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("  Data Corrupted: The data appears to be corrupted.")
                print("  Coding Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("  Debug Description: \(context.debugDescription)")
            @unknown default:
                print("  An unknown decoding error occurred: \(error)")
            }
            // It's often useful to re-throw the original error or a custom one after logging
            throw YAMLError.parsingError("Decoding failed. See console for details. Path: \(error.localizedDescription)")
        } catch {
            // Catch any other errors that might occur and print them
            print("An unexpected error occurred during YAML parsing: \(error.localizedDescription)")
            throw YAMLError.parsingError(error.localizedDescription)
        }
    }
}

// Extension to load and save collapsible state
extension YAMLParser {
    static func loadCollapsibleState() -> CollapsibleState {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: "resumeCollapsibleState") {
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(CollapsibleState.self, from: data)
            } catch {
                print("Error loading collapsible state: \(error.localizedDescription)")
                return CollapsibleState()
            }
        }
        return CollapsibleState()
    }
    
    static func saveCollapsibleState(_ state: CollapsibleState) {
        let userDefaults = UserDefaults.standard
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)
            userDefaults.set(data, forKey: "resumeCollapsibleState")
        } catch {
            print("Error saving collapsible state: \(error.localizedDescription)")
        }
    }
}
