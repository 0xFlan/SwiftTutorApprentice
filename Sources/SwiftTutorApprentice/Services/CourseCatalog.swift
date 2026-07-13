import Foundation

struct CourseCatalog {
    let definitions: [CourseDefinition]

    subscript(courseID: CourseID) -> CourseDefinition? {
        definitions.first { $0.id == courseID }
    }

    static let `default` = CourseCatalog(definitions: [
        CourseDefinition(
            id: .swiftDevelopment,
            title: "Swift Development",
            summary: "Learn Swift fundamentals and build native Apple platform apps.",
            symbolName: "swift",
            accentName: "swiftOrange",
            availability: .available,
            releaseLevel: .pilot,
            runtimeKind: .swiftConsole,
            certificationTargets: [
                CertificationTargetSummary(
                    id: "certiport-app-development-with-swift-associate",
                    provider: "Certiport",
                    credentialName: "App Development with Swift Associate",
                    examCode: nil,
                    sourceURL: URL(string: "https://certiport.pearsonvue.com/Educator-resources/Exam-details/Objective-domains/App-Development-with-Swift-Objective-Domain-Crossw.pdf")!
                )
            ],
            activeObjectiveSetID: nil
        ),
        CourseDefinition(
            id: .webDevelopment,
            title: "Web Development",
            summary: "Build accessible web experiences with HTML, CSS, and JavaScript.",
            symbolName: "globe",
            accentName: "webBlue",
            availability: .comingNext,
            releaseLevel: .inDevelopment,
            runtimeKind: .webPreview,
            certificationTargets: [
                CertificationTargetSummary(
                    id: "pearson-it-specialist-html-css",
                    provider: "Pearson",
                    credentialName: "IT Specialist HTML and CSS",
                    examCode: nil,
                    sourceURL: URL(string: "https://www.pearsonvue.com/us/en/it-exam-resources/it-specialist.html")!
                ),
                CertificationTargetSummary(
                    id: "pearson-it-specialist-javascript",
                    provider: "Pearson",
                    credentialName: "IT Specialist JavaScript",
                    examCode: nil,
                    sourceURL: URL(string: "https://www.pearsonvue.com/us/en/it-exam-resources/it-specialist.html")!
                ),
                CertificationTargetSummary(
                    id: "pearson-it-specialist-html5-application-development",
                    provider: "Pearson",
                    credentialName: "IT Specialist HTML5 Application Development",
                    examCode: nil,
                    sourceURL: URL(string: "https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-306-html-app-develop-pearson.pdf")!
                )
            ],
            activeObjectiveSetID: nil
        ),
        CourseDefinition(
            id: .cybersecurity,
            title: "Cybersecurity",
            summary: "Practice defensive security concepts through contained simulations.",
            symbolName: "lock.shield",
            accentName: "securityGreen",
            availability: .comingNext,
            releaseLevel: .inDevelopment,
            runtimeKind: .securitySimulation,
            certificationTargets: [
                CertificationTargetSummary(
                    id: "isc2-certified-in-cybersecurity",
                    provider: "ISC2",
                    credentialName: "Certified in Cybersecurity (CC)",
                    examCode: nil,
                    sourceURL: URL(string: "https://www.isc2.org/Certifications/CC")!
                ),
                CertificationTargetSummary(
                    id: "pearson-it-specialist-cybersecurity",
                    provider: "Pearson",
                    credentialName: "IT Specialist Cybersecurity",
                    examCode: nil,
                    sourceURL: URL(string: "https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-105-cybersecurity-pearson.pdf")!
                )
            ],
            activeObjectiveSetID: nil
        ),
        CourseDefinition(
            id: .networking,
            title: "Networking",
            summary: "Learn how networks operate through visual, offline simulations.",
            symbolName: "network",
            accentName: "networkPurple",
            availability: .comingNext,
            releaseLevel: .inDevelopment,
            runtimeKind: .networkSimulation,
            certificationTargets: [
                CertificationTargetSummary(
                    id: "cisco-ccst-networking",
                    provider: "Cisco",
                    credentialName: "Cisco Certified Support Technician (CCST) Networking",
                    examCode: nil,
                    sourceURL: URL(string: "https://www-cloud.cisco.com/site/us/en/learn/training-certifications/exams/ccst-networking.html")!
                ),
                CertificationTargetSummary(
                    id: "pearson-it-specialist-networking",
                    provider: "Pearson",
                    credentialName: "IT Specialist Networking",
                    examCode: nil,
                    sourceURL: URL(string: "https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-101-networking-pearson.pdf")!
                )
            ],
            activeObjectiveSetID: nil
        )
    ])
}
