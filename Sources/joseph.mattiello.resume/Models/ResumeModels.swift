// ResumeModels.swift
// Models for resume data

import Foundation

/// Main resume data structure
struct Resume: Codable {
    let name: String
    let contact: Contact
    let profile: String
    let experience: [Experience]
    let personalProjects: [Project]
    let openSourceContributions: [Project]
    let skills: Skills
    let education: [Education]
    
    enum CodingKeys: String, CodingKey {
        case name
        case contact
        case profile
        case experience
        case personalProjects = "personal_projects"
        case openSourceContributions = "open_source_contributions"
        case skills
        case education
    }
}

/// Contact information
struct Contact: Codable {
    let website: String?
    let phone: String?
    let linkedin: String?
    let github: String?
    let email: String?
}

/// Work experience
struct Experience: Codable, Identifiable {
    let id = UUID()
    let company: String
    let location: String
    let title: String
    let startDate: String
    let endDate: String?
    let responsibilities: [String]
    let appStoreUrl: String?
    let mediaUrls: [String]?
    
    enum CodingKeys: String, CodingKey {
        case company
        case location
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case responsibilities
        case appStoreUrl = "app_store_url"
        case mediaUrls = "media_urls"
    }
}

/// Project (used for both personal projects and open source contributions)
struct Project: Codable, Identifiable {
    let id = UUID()
    let name: String
    let description: String?
    let appStoreLink: String?
    let links: [Link]?
    let technologies: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case appStoreLink = "app_store_link"
        case links
        case technologies
    }
}

/// Link for projects
struct Link: Codable {
    let title: String
    let url: String
}

/// Skills section
struct Skills: Codable {
    let programmingLanguages: [Skill]
    let sdksApis: [Skill]
    
    enum CodingKeys: String, CodingKey {
        case programmingLanguages = "programming_languages"
        case sdksApis = "sdks_apis"
    }
}

/// Individual skill with rating
struct Skill: Codable, Identifiable {
    let id: UUID // Keep as let for Identifiable, will be set in init
    let name: String
    let rating: Int

    // Define CodingKeys to only include properties from YAML
    enum CodingKeys: String, CodingKey {
        case name
        case rating
        // 'id' is omitted, so it won't be looked for in YAML during decoding
    }

    // Custom initializer for creating Skill instances programmatically
    // Allows providing an id or letting it default to a new UUID
    init(id: UUID = UUID(), name: String, rating: Int) {
        self.id = id
        self.name = name
        self.rating = rating
    }

    // Custom Decodable initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.rating = try container.decode(Int.self, forKey: .rating)
        self.id = UUID() // Always generate a new UUID when decoding from YAML
    }
    
    // If encoding is needed and 'id' should be included, a custom encode(to:) would be required.
    // For now, focusing on successful decoding.
}

/// Education information
struct Education: Codable {
    let institution: String
    let degree: String
    let graduationYear: String?
    let details: String?
    
    enum CodingKeys: String, CodingKey {
        case institution
        case degree
        case graduationYear = "date"
        case details
    }
}

/// State for collapsible sections
struct CollapsibleState: Codable {
    var experienceStates: [String: Bool] = [:]
    var projectStates: [String: Bool] = [:]
    var contributionStates: [String: Bool] = [:]
}
