import Combine

enum SidebarVisibilityAlignment: Equatable {
    case center
    case nearest
}

struct SidebarVisibilityRequest: Equatable, Identifiable {
    let id: UInt64
    let lessonKey: LessonKey
    let alignment: SidebarVisibilityAlignment
}

@MainActor
final class LessonScrollCoordinator: ObservableObject {
    @Published private(set) var sidebarVisibilityRequest: SidebarVisibilityRequest?
    @Published private(set) var detailTopGeneration: UInt64 = 0

    private var selectedLessonKey: LessonKey?
    private var requestGeneration: UInt64 = 0

    func select(_ key: LessonKey, origin: LessonSelectionOrigin) {
        guard key != selectedLessonKey else { return }

        selectedLessonKey = key
        detailTopGeneration &+= 1

        requestGeneration &+= 1
        sidebarVisibilityRequest = SidebarVisibilityRequest(
            id: requestGeneration,
            lessonKey: key,
            alignment: origin == .direct ? .nearest : .center
        )
    }

    @discardableResult
    func consumeSidebarVisibilityRequest(id: UInt64?) -> Bool {
        guard let id,
              let request = sidebarVisibilityRequest,
              request.id == id
        else { return false }
        return fulfillSidebarVisibilityRequest(request)
    }

    @discardableResult
    func fulfillSidebarVisibilityRequest(
        _ request: SidebarVisibilityRequest
    ) -> Bool {
        guard sidebarVisibilityRequest == request else { return false }
        sidebarVisibilityRequest = nil
        return true
    }
}
