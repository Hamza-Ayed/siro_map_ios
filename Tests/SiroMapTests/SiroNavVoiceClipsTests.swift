import XCTest
@testable import SiroMap

final class SiroNavVoiceClipsTests: XCTestCase {
    func testTunnelAndBridgeAtTheManeuver() {
        XCTAssertEqual(SiroNavVoiceClips.envClipId(envNext: "tunnel", maneuverSign: -7, distanceMeters: 20), "enter_tunnel_keep_left")
        XCTAssertEqual(SiroNavVoiceClips.envClipId(envNext: "bridge", maneuverSign: 1, distanceMeters: 20), "take_bridge_slight_right")
        XCTAssertEqual(SiroNavVoiceClips.envClipId(envNext: "bridge", maneuverSign: 2, distanceMeters: 20), "take_bridge_now")
    }

    func testKobriInEgyptAndSaudi() {
        XCTAssertEqual(SiroNavVoiceClips.envClipId(envNext: "bridge", envVariant: "kobri", maneuverSign: 7, distanceMeters: 10), "take_kobri_keep_right")
        XCTAssertEqual(SiroNavVoiceClips.envClipId(envNext: "tunnel", envVariant: "kobri", maneuverSign: 7, distanceMeters: 10), "enter_tunnel_keep_right")
        XCTAssertEqual(SiroNavVoiceClips.thenEnvClipId(envNext: "bridge", envVariant: "kobri"), "then_take_kobri")
    }

    func testDistanceBins() {
        XCTAssertEqual(SiroNavVoiceClips.envClipId(envNext: "tunnel", maneuverSign: -7, distanceMeters: 200), "after_200m_enter_tunnel")
        XCTAssertEqual(SiroNavVoiceClips.envClipId(envNext: "bridge", envVariant: "kobri", maneuverSign: -7, distanceMeters: 500), "after_500m_take_kobri")
        XCTAssertNil(SiroNavVoiceClips.envClipId(envNext: "tunnel", maneuverSign: -7, distanceMeters: 900))
    }

    func testStepParsesEnvFields() throws {
        let json = #"{"instructionAr":"x","distanceMeters":1,"durationSeconds":1,"maneuverSign":-7,"inclinePercentage":0,"envNext":"bridge","envVariant":"kobri"}"#
        let step = try JSONDecoder().decode(SiroRouteStep.self, from: Data(json.utf8))
        XCTAssertEqual(step.envNext, "bridge")
        XCTAssertEqual(step.envVariant, "kobri")
    }
}

final class SiroNavVoicePackTests: XCTestCase {
    func testResolvesLikeTheFlutterEngine() {
        XCTAssertEqual(SiroNavVoiceClips.resolveClipId(maneuverSign: 2, distanceMeters: 20), "turn_right_now")
        XCTAssertEqual(SiroNavVoiceClips.resolveClipId(maneuverSign: -2, distanceMeters: 100), "after_100m_turn_left")
        XCTAssertEqual(SiroNavVoiceClips.resolveClipId(maneuverSign: 6, distanceMeters: 320), "after_300m_roundabout")
        XCTAssertEqual(SiroNavVoiceClips.resolveClipId(maneuverSign: 8, distanceMeters: 110), "after_100m_u_turn")
        XCTAssertNil(SiroNavVoiceClips.resolveClipId(maneuverSign: 2, distanceMeters: 5000))
        XCTAssertEqual(SiroNavVoiceClips.resolveClipId(maneuverSign: -7, distanceMeters: 20, priority: 0, envNext: "tunnel"), "enter_tunnel_keep_left")
    }

    func testChainFallsBackToNowClip() {
        XCTAssertEqual(SiroNavVoiceClips.chainClipId(maneuverSign: -2, hasClip: { _ in true }), "then_turn_left")
        XCTAssertEqual(SiroNavVoiceClips.chainClipId(maneuverSign: -2, hasClip: { _ in false }), "turn_left_now")
    }

    func testEveryResolvedClipExistsInBothBundledPacks() {
        for gender in [SiroNavVoiceGender.male, .female] {
            let catalog = SiroNavVoiceCatalog(gender: gender)
            XCTAssertGreaterThan(catalog.count, 200, "manifest not bundled for \(gender)")
            let ids = ["turn_right_now", "after_200m_enter_tunnel", "take_kobri_keep_left", "then_take_kobri", "enter_tunnel_keep_right", "after_500m_take_bridge"]
            for id in ids {
                XCTAssertNotNil(catalog.url(for: id), "\(id) missing in \(gender)")
                if let u = catalog.url(for: id) { XCTAssertTrue(FileManager.default.fileExists(atPath: u.path)) }
            }
        }
    }
}
