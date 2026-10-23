/**
 * وظيفة الملف: واجهة الدخول أو نقطة تشغيل حزمة SiroMaps.
 */
import Foundation

/**
 * Main entry point for Siro Commercial Maps SDK for iOS (Swift).
 * Fully compatible with Google Maps SDK API conventions.
 */
public class SiroMaps {

    public static let shared = SiroMaps()

    public private(set) var apiKey: String = ""
    public private(set) var baseUrl: String = "https://map-saas.intaleqapp.com"
    public private(set) var isInitialized: Bool = false

    private init() {}

    /**
     * Initializes the Siro Maps SDK with your SaaS API Key.
     */
    public static func initialize(apiKey: String, baseUrl: String = "https://map-saas.intaleqapp.com") {
        shared.apiKey = apiKey
        shared.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        shared.isInitialized = true
        // التتبع لا يبدأ هنا: التطبيق المضيف يستدعي SiroTelemetryService.shared.startTracking
        // بعد الإفصاح وأخذ الموافقة من المستخدم.
    }
}

// ─────────────────────────────────────────────────────────────
// Compatibility Typealiases (matching Google Maps iOS SDK GMS*)
// ─────────────────────────────────────────────────────────────

public typealias GMSMapView = SiroMapView
public typealias GMSCameraPosition = SiroCameraPosition
public typealias GMSCameraUpdate = SiroCameraUpdate
public typealias GMSCoordinateBounds = SiroLatLngBounds
public typealias GMSMarker = SiroMarker
public typealias GMSPolyline = SiroPolyline
public typealias GMSPolygon = SiroPolygon
public typealias GMSCircle = SiroCircle


