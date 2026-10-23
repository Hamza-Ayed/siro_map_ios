/**
 * وظيفة الملف: اختبارات محرك التتبع في iOS، تغطي نبضة الوقوف وبوابة الموافقة ومعرّف التثبيت.
 */
import XCTest
@testable import SiroMap

final class SiroTelemetryServiceTests: XCTestCase {

    private let service = SiroTelemetryService.shared
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        service.setEnabled(false)
        service.setInstallId("test-install")
        service.setEnabled(true)
    }

    override func tearDown() {
        service.setEnabled(false)
        super.tearDown()
    }

    func testStationaryDeviceRecordsHeartbeatEvery30SecondsWithoutGpsEvents() {
        XCTAssertTrue(service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 0, heading: 0, now: t0))
        XCTAssertFalse(service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 0, heading: 0,
                                              now: t0.addingTimeInterval(5)))
        XCTAssertTrue(service.isStationary)

        XCTAssertFalse(service.recordHeartbeat(now: t0.addingTimeInterval(10)))
        XCTAssertTrue(service.recordHeartbeat(now: t0.addingTimeInterval(31)))
        XCTAssertEqual(service.bufferedPointCount, 2)
    }

    func testMovingDeviceDoesNotProduceHeartbeats() {
        service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0)
        XCTAssertFalse(service.isStationary)
        XCTAssertFalse(service.recordHeartbeat(now: t0.addingTimeInterval(60)))
        XCTAssertEqual(service.bufferedPointCount, 1)
    }

    func testNothingIsRecordedWhileDisabled() {
        service.setEnabled(false)
        XCTAssertFalse(service.isEnabled)
        XCTAssertFalse(service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0))
        XCTAssertFalse(service.recordHeartbeat(now: t0.addingTimeInterval(60)))
        XCTAssertEqual(service.bufferedPointCount, 0)
    }

    func testDisablingDropsUnsentPoints() {
        service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0)
        XCTAssertEqual(service.bufferedPointCount, 1)
        service.setEnabled(false)
        XCTAssertEqual(service.bufferedPointCount, 0)
    }

    func testGeneratedInstallIdIsUuidV4AndUnique() {
        let first = SiroTelemetryService.generateInstallId()
        let second = SiroTelemetryService.generateInstallId()
        XCTAssertNotEqual(first, second)
        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertEqual(first.count, 36)
    }

    func testLoadOrCreateInstallIdIsStableUntilStorageIsCleared() {
        let suite = "siro.telemetry.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = SiroTelemetryService.loadOrCreateInstallId(defaults: defaults)
        XCTAssertEqual(SiroTelemetryService.loadOrCreateInstallId(defaults: defaults), first)

        defaults.removePersistentDomain(forName: suite)
        XCTAssertNotEqual(SiroTelemetryService.loadOrCreateInstallId(defaults: defaults), first)
    }
}
