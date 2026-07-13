import XCTest
@testable import SwiftTutorApprentice

final class CourseCatalogTests: XCTestCase {
    func testDefaultCatalogUsesFourStableOrderedCourseIDs() {
        XCTAssertEqual(
            CourseCatalog.default.definitions.map(\.id.rawValue),
            ["swift-development", "web-development", "cybersecurity", "networking"]
        )
    }

    func testOnlySwiftIsAvailableAndItIsStillAPilot() throws {
        let swift = try XCTUnwrap(CourseCatalog.default[.swiftDevelopment])
        XCTAssertEqual(swift.availability, .available)
        XCTAssertEqual(swift.releaseLevel, .pilot)
        XCTAssertEqual(swift.runtimeKind, .swiftConsole)
        XCTAssertNil(swift.activeObjectiveSetID)
        for id in [CourseID.webDevelopment, .cybersecurity, .networking] {
            XCTAssertEqual(CourseCatalog.default[id]?.availability, .comingNext)
            XCTAssertNil(CourseCatalog.default[id]?.activeObjectiveSetID)
        }
    }

    func testEveryCourseUsesExactApprovedCertificationTargetMetadata() {
        let actual = Dictionary(uniqueKeysWithValues:
            CourseCatalog.default.definitions.map { definition in
                (definition.id, definition.certificationTargets.map {
                    "\($0.provider)|\($0.credentialName)|\($0.sourceURL.absoluteString)"
                })
            }
        )
        XCTAssertEqual(actual[.swiftDevelopment], [
            "Certiport|App Development with Swift Associate|https://certiport.pearsonvue.com/Educator-resources/Exam-details/Objective-domains/App-Development-with-Swift-Objective-Domain-Crossw.pdf"
        ])
        XCTAssertEqual(actual[.webDevelopment], [
            "Pearson|IT Specialist HTML and CSS|https://www.pearsonvue.com/us/en/it-exam-resources/it-specialist.html",
            "Pearson|IT Specialist JavaScript|https://www.pearsonvue.com/us/en/it-exam-resources/it-specialist.html",
            "Pearson|IT Specialist HTML5 Application Development|https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-306-html-app-develop-pearson.pdf"
        ])
        XCTAssertEqual(actual[.cybersecurity], [
            "ISC2|Certified in Cybersecurity (CC)|https://www.isc2.org/Certifications/CC",
            "Pearson|IT Specialist Cybersecurity|https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-105-cybersecurity-pearson.pdf"
        ])
        XCTAssertEqual(actual[.networking], [
            "Cisco|Cisco Certified Support Technician (CCST) Networking|https://www-cloud.cisco.com/site/us/en/learn/training-certifications/exams/ccst-networking.html",
            "Pearson|IT Specialist Networking|https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-101-networking-pearson.pdf"
        ])
    }
}
