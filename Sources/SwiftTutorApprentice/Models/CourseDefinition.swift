import Foundation

enum CourseAvailability: String, Codable {
    case available
    case comingNext
    case contentUnavailable
}

enum CourseReleaseLevel: String, Codable {
    case pilot
    case inDevelopment
    case certificationReady
}

enum CourseRuntimeKind: String, Codable {
    case swiftConsole
    case webPreview
    case securitySimulation
    case networkSimulation
}

struct CertificationTargetSummary: Hashable, Codable, Identifiable {
    let id: String
    let provider: String
    let credentialName: String
    let examCode: String?
    let sourceURL: URL
}

struct CourseDefinition: Identifiable, Hashable {
    let id: CourseID
    let title: String
    let summary: String
    let symbolName: String
    let accentName: String
    let availability: CourseAvailability
    let releaseLevel: CourseReleaseLevel
    let runtimeKind: CourseRuntimeKind
    let certificationTargets: [CertificationTargetSummary]
    let activeObjectiveSetID: ObjectiveSetID?
}
