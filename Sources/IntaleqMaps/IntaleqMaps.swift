/**
 * وظيفة الملف: واجهة الدخول أو نقطة تشغيل حزمة IntaleqMaps.
 */
import Foundation

/**
 * Main entry point for Intaleq Commercial Maps SDK for iOS (Swift).
 * Fully compatible with Google Maps SDK API conventions.
 */
public class IntaleqMaps {

    public static let shared = IntaleqMaps()

    public private(set) var apiKey: String = ""
    public private(set) var baseUrl: String = "https://map-saas.intaleqapp.com"
    public private(set) var isInitialized: Bool = false

    private init() {}

    /**
     * Initializes the Intaleq Maps SDK with your SaaS API Key.
     */
    public static func initialize(apiKey: String, baseUrl: String = "https://map-saas.intaleqapp.com") {
        shared.apiKey = apiKey
        shared.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        shared.isInitialized = true

        #if canImport(UIKit)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let deviceId = UUID().uuidString
        #endif
        IntaleqTelemetryService.shared.startTracking(driverId: deviceId)
    }
}

// ─────────────────────────────────────────────────────────────
// Compatibility Typealiases (matching Google Maps iOS SDK GMS*)
// ─────────────────────────────────────────────────────────────

public typealias GMSMapView = IntaleqMapView
public typealias GMSCameraPosition = InlqCameraPosition
public typealias GMSCameraUpdate = InlqCameraUpdate
public typealias GMSCoordinateBounds = InlqLatLngBounds
public typealias GMSMarker = InlqMarker
public typealias GMSPolyline = InlqPolyline
public typealias GMSPolygon = InlqPolygon
public typealias GMSCircle = InlqCircle

// ─────────────────────────────────────────────────────────────
// Primary Siro Brand Typealiases
// ─────────────────────────────────────────────────────────────

public typealias SiroMap = IntaleqMaps
public typealias SiroMaps = IntaleqMaps
public typealias SiroMapView = IntaleqMapView
public typealias SiroMapController = IntaleqMapController
public typealias SiroMapViewDelegate = IntaleqMapViewDelegate
public typealias SiroCameraPosition = InlqCameraPosition
public typealias SiroCameraUpdate = InlqCameraUpdate
public typealias SiroLatLng = InlqLatLng
public typealias SiroLatLngBounds = InlqLatLngBounds
public typealias SiroMarker = InlqMarker
public typealias SiroPolyline = InlqPolyline
public typealias SiroPolygon = InlqPolygon
public typealias SiroCircle = InlqCircle
public typealias SiroBitmap = InlqBitmap
public typealias SiroInfoWindow = InlqInfoWindow
public typealias SiroMapType = IntaleqMapType
public typealias SiroStyles = IntaleqStyles

#if canImport(SwiftUI)
public typealias SiroMapViewRepresentable = IntaleqMapViewRepresentable
#endif


