enum CourseActionLabel: String, Equatable {
    case start = "Start"
    case `continue` = "Continue"
    case review = "Review"
}

struct CourseDestination: Equatable {
    let label: CourseActionLabel
    let lessonKey: LessonKey
}

enum CourseDestinationResolver {
    static func resolve(
        orderedLessons: [LessonKey],
        completed: Set<LessonKey>,
        lastLesson: LessonKey?,
        hasMeaningfulActivity: Bool
    ) -> CourseDestination? {
        guard let first = orderedLessons.first else { return nil }
        guard hasMeaningfulActivity else {
            return CourseDestination(label: .start, lessonKey: first)
        }
        let incomplete = orderedLessons.filter { !completed.contains($0) }
        guard !incomplete.isEmpty else {
            let validLast = lastLesson.flatMap { orderedLessons.contains($0) ? $0 : nil }
            return CourseDestination(label: .review, lessonKey: validLast ?? first)
        }
        guard let last = lastLesson,
              let lastIndex = orderedLessons.firstIndex(of: last)
        else {
            return CourseDestination(label: .continue, lessonKey: incomplete[0])
        }
        if !completed.contains(last) {
            return CourseDestination(label: .continue, lessonKey: last)
        }
        let rotated = Array(orderedLessons[(lastIndex + 1)...]) + Array(orderedLessons[..<lastIndex])
        return CourseDestination(
            label: .continue,
            lessonKey: rotated.first(where: { !completed.contains($0) }) ?? incomplete[0]
        )
    }
}
