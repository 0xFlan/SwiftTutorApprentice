import Foundation

/// Display-only projection for Course Home. It reports released lesson
/// completion, but deliberately does not infer mastery or credential readiness.
struct CourseHomeCardModel: Identifiable, Equatable {
    let id: CourseID
    let title: String
    let purpose: String
    let symbolName: String
    let accentName: String
    let availabilityText: String
    let targetCredentialText: String
    let progressText: String?
    let primaryActionLabel: String
    let isPrimaryActionEnabled: Bool
    let destination: LessonKey?

    init(
        course: CourseDefinition,
        provider: (any CourseContentProvider)?,
        progress: CourseProgressDocument,
        destination: CourseDestination?
    ) {
        id = course.id
        title = course.title
        purpose = course.summary
        symbolName = course.symbolName
        accentName = course.accentName
        targetCredentialText = course.certificationTargets
            .map { "\($0.provider): \($0.credentialName)" }
            .joined(separator: " • ")

        switch course.availability {
        case .available:
            availabilityText = "Available"
            let releasedLessonIDs = Set(
                provider?.modules.flatMap(\.orderedLessonLocalIDs) ?? []
            )
            let completedCount = progress.completedLessonLocalIDs
                .intersection(releasedLessonIDs)
                .count
            progressText = "\(completedCount) of \(releasedLessonIDs.count) lessons complete"
            primaryActionLabel = destination?.label.rawValue ?? "Unavailable"
            isPrimaryActionEnabled = destination != nil
            self.destination = destination?.lessonKey
        case .comingNext:
            availabilityText = "Coming next"
            progressText = nil
            primaryActionLabel = "Coming next"
            isPrimaryActionEnabled = false
            self.destination = nil
        case .contentUnavailable:
            availabilityText = "Content unavailable"
            progressText = nil
            primaryActionLabel = "Unavailable"
            isPrimaryActionEnabled = false
            self.destination = nil
        }
    }

    var displayText: [String] {
        [
            title,
            purpose,
            availabilityText,
            targetCredentialText,
            progressText,
            primaryActionLabel
        ].compactMap { $0 }
    }
}
