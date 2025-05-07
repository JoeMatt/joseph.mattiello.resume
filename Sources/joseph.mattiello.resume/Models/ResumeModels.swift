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
    var id = UUID()
    let name: String
    let rating: Int
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
