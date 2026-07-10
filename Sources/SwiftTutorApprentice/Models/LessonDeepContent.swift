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
        provenance: LessonDeepContentProvenance? = nil
    ) {
        self.title = title
        self.introduction = introduction
        self.segments = segments
        self.microscopeTokens = microscopeTokens
        self.modifyTask = modifyTask
        self.recallQuestions = recallQuestions
        self.provenance = provenance
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
