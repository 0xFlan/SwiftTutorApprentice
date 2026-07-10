// LessonDeepContent.swift
// ------------------------------------------------------------
// Optional concept-first teaching content for lessons that need
// a deeper explanation before the existing coding workspace.
// ------------------------------------------------------------

import Foundation

struct ConceptID: RawRepresentable, Hashable, Codable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

enum SyntaxRequirement: String, Codable, Hashable {
    case required
    case convention
    case contextual
}

struct LessonDeepContentProvenance: Codable, Hashable {
    enum Source: String, Codable, Hashable {
        case bundled
    }

    let source: Source
    let revision: Int
}

struct LessonDeepContent: Codable, Hashable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let title: String
    let introduction: String
    let segments: [DeepLessonSegment]
    let microscopeTokens: [SyntaxMicroscopeToken]
    let modifyTask: ModifyTask
    let recallQuestions: [RecallQuestion]
    let provenance: LessonDeepContentProvenance?

    init(
        title: String,
        introduction: String,
        segments: [DeepLessonSegment],
        microscopeTokens: [SyntaxMicroscopeToken],
        modifyTask: ModifyTask,
        recallQuestions: [RecallQuestion],
        provenance: LessonDeepContentProvenance? = nil,
        schemaVersion: Int = LessonDeepContent.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.title = title
        self.introduction = introduction
        self.segments = segments
        self.microscopeTokens = microscopeTokens
        self.modifyTask = modifyTask
        self.recallQuestions = recallQuestions
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, title, introduction, segments, microscopeTokens,
             modifyTask, recallQuestions, provenance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.schemaVersion) {
            schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        } else {
            schemaVersion = Self.currentSchemaVersion
        }
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: c,
                debugDescription: "Unsupported Deep Lesson schema version \(schemaVersion)"
            )
        }

        title = try c.decode(String.self, forKey: .title)
        introduction = try c.decode(String.self, forKey: .introduction)
        segments = try c.decode([DeepLessonSegment].self, forKey: .segments)
        microscopeTokens = try c.decode(
            [SyntaxMicroscopeToken].self,
            forKey: .microscopeTokens
        )
        modifyTask = try c.decode(ModifyTask.self, forKey: .modifyTask)
        recallQuestions = try c.decode([RecallQuestion].self, forKey: .recallQuestions)
        provenance = try c.decodeIfPresent(
            LessonDeepContentProvenance.self,
            forKey: .provenance
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try c.encode(title, forKey: .title)
        try c.encode(introduction, forKey: .introduction)
        try c.encode(segments, forKey: .segments)
        try c.encode(microscopeTokens, forKey: .microscopeTokens)
        try c.encode(modifyTask, forKey: .modifyTask)
        try c.encode(recallQuestions, forKey: .recallQuestions)
        try c.encodeIfPresent(provenance, forKey: .provenance)
    }
}

struct DeepLessonSegment: Codable, Hashable {
    let id: String
    let title: String
    let explanation: String
    let correctCode: String?
    let wrongCode: String?
    let wrongExplanation: String?
}

struct SyntaxMicroscopeToken: Codable, Hashable {
    let id: String
    let display: String
    let role: String
    let requirement: SyntaxRequirement
    let explanation: String
    let ifChanged: String
}

struct ModifyTask: Codable, Hashable {
    let id: String
    let prompt: String
    let starterCode: String
    let expectedCode: String
    let predictionPrompt: String
    let expectedOutput: String
    let successExplanation: String
    let conceptIDs: [ConceptID]
}

struct RecallQuestion: Codable, Hashable {
    let id: String
    let prompt: String
    let choices: [String]
    let correctChoiceIndex: Int
    let explanation: String
    let conceptIDs: [ConceptID]
}
