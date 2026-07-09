import Foundation

enum ModifyTaskResult: Equatable {
    case passed
    case codeDoesNotMatch
    case predictionDoesNotMatch
    case bothDoNotMatch
}

enum ModifyTaskEvaluator {
    static func evaluate(
        code: String,
        prediction: String,
        task: ModifyTask
    ) -> ModifyTaskResult {
        let codeMatches = normalizeCode(code) == normalizeCode(task.expectedCode)
        let predictionMatches = prediction.trimmingCharacters(in: .whitespacesAndNewlines)
            == task.expectedOutput

        switch (codeMatches, predictionMatches) {
        case (true, true):
            return .passed
        case (false, true):
            return .codeDoesNotMatch
        case (true, false):
            return .predictionDoesNotMatch
        case (false, false):
            return .bothDoNotMatch
        }
    }

    private static func normalizeCode(_ code: String) -> String {
        var normalized = code
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        while normalized.last == "\n" {
            normalized.removeLast()
        }

        return normalized
    }
}
