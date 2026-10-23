import XCTest
@testable import SiroMap

final class SiroMapsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SiroMaps.initialize(apiKey: "in_pub_test_key_12345", baseUrl: "https://map-saas.intaleqapp.com")
    }

    func testInitialization() {
        XCTAssertTrue(SiroMaps.shared.isInitialized)
        XCTAssertEqual(SiroMaps.shared.apiKey, "in_pub_test_key_12345")
        XCTAssertEqual(SiroMaps.shared.baseUrl, "https://map-saas.intaleqapp.com")
    }

    func testStyleUrls() {
        XCTAssertTrue(SiroStyles.terrain.contains("style-3d-terrain.json"))
        XCTAssertTrue(SiroStyles.dark.contains("style-dark.json"))
        XCTAssertTrue(SiroStyles.normal.contains("style.json"))
        XCTAssertTrue(SiroStyles.satellite.contains("style-satellite.json"))
        XCTAssertTrue(SiroStyles.outdoors.contains("style-tourism.json"))
    }

    func testLatLngDistanceAndBearing() {
        let amman = SiroLatLng(latitude: 31.9539, longitude: 35.9106)
        let zarqa = SiroLatLng(latitude: 32.0608, longitude: 36.0941)

        let distanceMeters = amman.distance(to: zarqa)
        XCTAssertGreaterThan(distanceMeters, 15000)
        XCTAssertLessThan(distanceMeters, 30000)

        let bearing = amman.bearing(to: zarqa)
        XCTAssertGreaterThan(bearing, 30)
        XCTAssertLessThan(bearing, 90)
    }

    func testGeocodingArrayParsing() {
        let sampleJsonArray = """
        [
            {
                "id": "places_jordan_72778",
                "name": "Amman City Hall",
                "name_ar": "أمانة عمان الكبرى",
                "category": "government",
                "city": "Amman",
                "latitude": 31.94514,
                "longitude": 35.92433,
                "full_address": "Amman City Hall, Ali Bin Abi Taleb Street, Medina, Amman"
            }
        ]
        """.data(using: .utf8)!

        let places = SiroGeocodingService.parsePlaces(from: sampleJsonArray)
        XCTAssertEqual(places.count, 1)
        let place = places[0]
        XCTAssertEqual(place.id, "places_jordan_72778")
        XCTAssertEqual(place.name, "Amman City Hall")
        XCTAssertEqual(place.nameAr, "أمانة عمان الكبرى")
        XCTAssertEqual(place.position.latitude, 31.94514, accuracy: 0.0001)
        XCTAssertEqual(place.position.longitude, 35.92433, accuracy: 0.0001)
    }

    func testGeocodingGeoJSONParsing() {
        let sampleGeoJson = """
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "id": "place_petra_001",
                    "properties": {
                        "name": "Petra Treasury",
                        "name_ar": "خزنة البتراء",
                        "category": "tourism",
                        "city": "Wadi Musa"
                    },
                    "geometry": {
                        "type": "Point",
                        "coordinates": [35.4444, 30.3222]
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let places = SiroGeocodingService.parsePlaces(from: sampleGeoJson)
        XCTAssertEqual(places.count, 1)
        let place = places[0]
        XCTAssertEqual(place.name, "Petra Treasury")
        XCTAssertEqual(place.position.latitude, 30.3222, accuracy: 0.0001)
        XCTAssertEqual(place.position.longitude, 35.4444, accuracy: 0.0001)
    }

    func testCameraPositionAndUpdates() {
        let ctrl = SiroMapController()
        XCTAssertEqual(ctrl.cameraPosition.target.latitude, 31.9539, accuracy: 0.0001)

        let target = SiroLatLng(latitude: 30.3222, longitude: 35.4444)
        ctrl.animateCamera(with: .newLatLngZoom(target, 16.0))

        XCTAssertEqual(ctrl.cameraPosition.target.latitude, 30.3222, accuracy: 0.0001)
        XCTAssertEqual(ctrl.cameraPosition.zoom, 16.0)
    }
}
