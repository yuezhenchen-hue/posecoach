import XCTest
@testable import PoseCoach

final class PoseCoachTests: XCTestCase {

    func testSceneTypeMapping() {
        XCTAssertEqual(SceneType.from(classificationIdentifier: "beach_sand"), .beach)
        XCTAssertEqual(SceneType.from(classificationIdentifier: "ocean_coast"), .beach)
        XCTAssertEqual(SceneType.from(classificationIdentifier: "sunset_sky"), .sunset)
        XCTAssertEqual(SceneType.from(classificationIdentifier: "city_street"), .cityStreet)
        XCTAssertEqual(SceneType.from(classificationIdentifier: "coffee_shop"), .cafe)
        XCTAssertEqual(SceneType.from(classificationIdentifier: "random_thing"), .unknown)
    }

    func testPoseTemplateRecommendations() {
        let beachPoses = PoseTemplate.recommendations(for: .beach)
        XCTAssertFalse(beachPoses.isEmpty, "Beach should have pose recommendations")

        let cafePoses = PoseTemplate.recommendations(for: .cafe)
        XCTAssertFalse(cafePoses.isEmpty, "Cafe should have pose recommendations")

        let unknownPoses = PoseTemplate.recommendations(for: .unknown)
        XCTAssertFalse(unknownPoses.isEmpty, "Unknown scene should return general poses")
    }

    func testCameraParametersDisplay() {
        var params = CameraParameters()
        params.exposureBias = 0.5
        params.hdrEnabled = true
        params.usePortraitMode = true

        let items = params.displayItems
        XCTAssertTrue(items.contains(where: { $0.name == "HDR" }))
        XCTAssertTrue(items.contains(where: { $0.name == "模式" }))
        XCTAssertTrue(items.contains(where: { $0.name == "曝光" }))
    }

    func testLightConditionClassification() {
        // Verifying the light condition types are properly defined
        let veryDark = LightAnalyzer.LightCondition.veryDark
        let normal = LightAnalyzer.LightCondition.normal
        XCTAssertNotEqual(veryDark, normal)
    }

    func testSceneCreativeTips() {
        for scene in SceneType.allCases {
            let tips = scene.creativeTips
            XCTAssertFalse(tips.isEmpty, "\(scene.displayName) should have creative tips")
        }
    }
}
