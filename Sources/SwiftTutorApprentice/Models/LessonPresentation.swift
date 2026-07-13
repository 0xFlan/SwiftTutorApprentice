import Foundation

enum PresentationVisualKind: String, Codable, Hashable {
    case codeExecution
    case valueBinding
    case outputFlow
    case branchChoice
    case collectionChange
    case webRender
    case packetJourney
    case securityTimeline
    case labeledDiagram
}

struct PresentationValue: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let value: String
}

struct PresentationCodeToken: Codable, Hashable, Identifiable {
    let id: String
    let text: String
}

enum PresentationFocusKind: String, Codable, Hashable {
    case codeToken
    case value
    case output
}

struct PresentationFocusTarget: Codable, Hashable {
    let kind: PresentationFocusKind
    let id: String
}

struct PresentationVisualState: Codable, Hashable {
    let code: String?
    let codeTokens: [PresentationCodeToken]
    let values: [PresentationValue]
    let output: String?
    let outputTargetID: String?
    let description: String
}

struct PresentationScene: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let caption: String
    let narration: String
    let staticDescription: String
    let visualKind: PresentationVisualKind
    let focusTargets: [PresentationFocusTarget]
    let before: PresentationVisualState
    let after: PresentationVisualState
}

struct AICodeClaim: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    let isCorrect: Bool
    let explanation: String
}

struct AICodeReviewExercise: Codable, Hashable, Identifiable {
    let id: String
    let prompt: String
    let generatedCode: String
    let claims: [AICodeClaim]
    let conceptIDs: [ConceptID]
}

enum LessonPresentationProvenanceSource: String, Codable, Hashable {
    case bundled
}

struct LessonPresentationProvenance: Codable, Hashable {
    let source: LessonPresentationProvenanceSource
    let revision: Int
}

struct LessonPresentation: Codable, Hashable, Identifiable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: String
    let title: String
    let posterDescription: String
    let posterState: PresentationVisualState
    let scenes: [PresentationScene]
    let transcript: String
    let narrationLocale: String
    let finalRecallQuestionID: String
    let aiCodeExercise: AICodeReviewExercise?
    let conceptIDs: [ConceptID]
    let objectiveMappings: [ObjectiveMapping]
    let provenance: LessonPresentationProvenance

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        id: String,
        title: String,
        posterDescription: String,
        posterState: PresentationVisualState,
        scenes: [PresentationScene],
        transcript: String,
        narrationLocale: String,
        finalRecallQuestionID: String,
        aiCodeExercise: AICodeReviewExercise?,
        conceptIDs: [ConceptID],
        objectiveMappings: [ObjectiveMapping],
        provenance: LessonPresentationProvenance
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.posterDescription = posterDescription
        self.posterState = posterState
        self.scenes = scenes
        self.transcript = transcript
        self.narrationLocale = narrationLocale
        self.finalRecallQuestionID = finalRecallQuestionID
        self.aiCodeExercise = aiCodeExercise
        self.conceptIDs = conceptIDs
        self.objectiveMappings = objectiveMappings
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case title
        case posterDescription
        case posterState
        case scenes
        case transcript
        case narrationLocale
        case finalRecallQuestionID
        case aiCodeExercise
        case conceptIDs
        case objectiveMappings
        case provenance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported lesson presentation schema version \(schemaVersion)"
            )
        }

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        posterDescription = try container.decode(String.self, forKey: .posterDescription)
        posterState = try container.decode(PresentationVisualState.self, forKey: .posterState)
        scenes = try container.decode([PresentationScene].self, forKey: .scenes)
        transcript = try container.decode(String.self, forKey: .transcript)
        narrationLocale = try container.decode(String.self, forKey: .narrationLocale)
        finalRecallQuestionID = try container.decode(String.self, forKey: .finalRecallQuestionID)
        aiCodeExercise = try container.decodeIfPresent(
            AICodeReviewExercise.self,
            forKey: .aiCodeExercise
        )
        conceptIDs = try container.decode([ConceptID].self, forKey: .conceptIDs)
        objectiveMappings = try container.decode(
            [ObjectiveMapping].self,
            forKey: .objectiveMappings
        )
        provenance = try container.decode(
            LessonPresentationProvenance.self,
            forKey: .provenance
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(posterDescription, forKey: .posterDescription)
        try container.encode(posterState, forKey: .posterState)
        try container.encode(scenes, forKey: .scenes)
        try container.encode(transcript, forKey: .transcript)
        try container.encode(narrationLocale, forKey: .narrationLocale)
        try container.encode(finalRecallQuestionID, forKey: .finalRecallQuestionID)
        try container.encodeIfPresent(aiCodeExercise, forKey: .aiCodeExercise)
        try container.encode(conceptIDs, forKey: .conceptIDs)
        try container.encode(objectiveMappings, forKey: .objectiveMappings)
        try container.encode(provenance, forKey: .provenance)
    }
}
