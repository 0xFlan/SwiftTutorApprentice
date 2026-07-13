import Foundation

struct ProgressEventID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct ActivityID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct ItemVariantID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct AttemptID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct ObjectiveID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct ReviewID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct MasteryPolicyVersion: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

enum CourseStageEventKind: String, Codable {
    case deepLessonViewed
    case modifyPassed
    case recallAnswered
}

struct CourseStageEvent: Codable, Equatable {
    let id: ProgressEventID
    let lessonLocalID: LessonLocalID
    let kind: CourseStageEventKind
    let timestamp: Date
    let questionID: String?
    let wasCorrect: Bool?
}

enum PresentationStatus: String, Codable {
    case notStarted
    case started
    case skipped
    case completed
}

struct LessonPresentationState: Codable, Equatable {
    var status: PresentationStatus
    var lastSceneID: String?
    var presentationRevision: Int
    var firstStartedAt: Date?
    var lastOpenedAt: Date?
    var replayCount: Int
    var presentationID: String? = nil
}

struct ObjectiveMapping: Codable, Equatable, Hashable {
    let conceptID: ConceptID
    let objectiveSetID: ObjectiveSetID
    let objectiveID: ObjectiveID
}

enum ScaffoldLevel: String, Codable {
    case none
    case prompt
    case conceptReminder
    case localizedClue
    case workedExplanation
}

enum AttemptResult: String, Codable {
    case passed
    case failed
}

struct AssessmentAttempt: Codable, Equatable {
    let id: AttemptID
    let lessonKey: LessonKey
    let activityID: ActivityID
    let itemVariantID: ItemVariantID
    let conceptIDs: [ConceptID]
    let objectiveMappings: [ObjectiveMapping]
    let scaffoldLevel: ScaffoldLevel
    let result: AttemptResult
    let contentRevision: Int
    let wasPreviouslySeen: Bool
    let submittedAt: Date
}

struct ReviewRecord: Codable, Equatable {
    let id: ReviewID
    let conceptID: ConceptID
    let createdAt: Date
    let dueAt: Date
    let policyVersion: MasteryPolicyVersion
    let sourceEvidenceAttemptIDs: [AttemptID]
    let satisfyingAttemptID: AttemptID?
}

struct ReadinessSnapshot: Codable, Equatable {
    let objectiveSetID: ObjectiveSetID
    let policyVersion: MasteryPolicyVersion
    let calculatedAt: Date
    let evidenceAttemptIDs: [AttemptID]
}
