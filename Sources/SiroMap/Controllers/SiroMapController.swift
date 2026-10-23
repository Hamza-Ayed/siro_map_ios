/**
 * وظيفة الملف: تنفيذ جزء SiroMapController ضمن حزمة العميل أو التطبيق.
 */
import Foundation

/**
 * Controller for an SiroMapView instance on iOS.
 * Mirrors SiroMapController from Flutter SDK and GMSMapView from Google Maps iOS SDK.
 */
public class SiroMapController {

    private var markers: [SiroMarkerId: SiroMarker] = [:]
    private var polylines: [SiroPolylineId: SiroPolyline] = [:]
    private var polygons: [SiroPolygonId: SiroPolygon] = [:]
    private var circles: [SiroCircleId: SiroCircle] = [:]

    public private(set) var cameraPosition: SiroCameraPosition = SiroCameraPosition(
        target: SiroLatLng(latitude: 31.9539, longitude: 35.9106),
        zoom: 12.0
    )

    public var onCameraMove: ((SiroCameraPosition) -> Void)?
    public var onCameraIdle: (() -> Void)?
    public var onMapTap: ((SiroLatLng) -> Void)?
    public var onMapLongPress: ((SiroLatLng) -> Void)?

    public init() {}

    /**
     * Animates camera movement to the new position defined in the update.
     */
    public func animateCamera(with update: SiroCameraUpdate, duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        applyCameraUpdate(update)
        completion?()
    }

    /**
     * Instantly repositions camera to the new position defined in the update.
     */
    public func moveCamera(with update: SiroCameraUpdate) {
        applyCameraUpdate(update)
    }

    private func applyCameraUpdate(_ update: SiroCameraUpdate) {
        switch update {
        case .newLatLng(let latLng):
            cameraPosition = SiroCameraPosition(target: latLng, zoom: cameraPosition.zoom, viewingAngle: cameraPosition.viewingAngle, bearing: cameraPosition.bearing)
        case .newLatLngZoom(let latLng, let zoom):
            cameraPosition = SiroCameraPosition(target: latLng, zoom: zoom, viewingAngle: cameraPosition.viewingAngle, bearing: cameraPosition.bearing)
        case .newCameraPosition(let pos):
            cameraPosition = pos
        case .zoomIn:
            cameraPosition = SiroCameraPosition(target: cameraPosition.target, zoom: cameraPosition.zoom + 1.0, viewingAngle: cameraPosition.viewingAngle, bearing: cameraPosition.bearing)
        case .zoomOut:
            cameraPosition = SiroCameraPosition(target: cameraPosition.target, zoom: max(0.0, cameraPosition.zoom - 1.0), viewingAngle: cameraPosition.viewingAngle, bearing: cameraPosition.bearing)
        }
        onCameraMove?(cameraPosition)
        onCameraIdle?()
    }

    // ── Markers ─────────────────────────────────────────────────────────────

    @discardableResult
    public func addMarker(_ marker: SiroMarker) -> SiroMarker {
        markers[marker.markerId] = marker
        return marker
    }

    public func removeMarker(withId id: SiroMarkerId) {
        markers.removeValue(forKey: id)
    }

    public func clearMarkers() {
        markers.removeAll()
    }

    public func getMarkers() -> [SiroMarker] {
        return Array(markers.values)
    }

    // ── Polylines ───────────────────────────────────────────────────────────

    @discardableResult
    public func addPolyline(_ polyline: SiroPolyline) -> SiroPolyline {
        polylines[polyline.polylineId] = polyline
        return polyline
    }

    public func removePolyline(withId id: SiroPolylineId) {
        polylines.removeValue(forKey: id)
    }

    public func clearPolylines() {
        polylines.removeAll()
    }

    public func getPolylines() -> [SiroPolyline] {
        return Array(polylines.values)
    }

    // ── Polygons ────────────────────────────────────────────────────────────

    @discardableResult
    public func addPolygon(_ polygon: SiroPolygon) -> SiroPolygon {
        polygons[polygon.polygonId] = polygon
        return polygon
    }

    public func removePolygon(withId id: SiroPolygonId) {
        polygons.removeValue(forKey: id)
    }

    public func clearPolygons() {
        polygons.removeAll()
    }

    public func getPolygons() -> [SiroPolygon] {
        return Array(polygons.values)
    }

    // ── Circles ─────────────────────────────────────────────────────────────

    @discardableResult
    public func addCircle(_ circle: SiroCircle) -> SiroCircle {
        circles[circle.circleId] = circle
        return circle
    }

    public func removeCircle(withId id: SiroCircleId) {
        circles.removeValue(forKey: id)
    }

    public func clearCircles() {
        circles.removeAll()
    }

    public func getCircles() -> [SiroCircle] {
        return Array(circles.values)
    }

    /**
     * Clears all overlays from the map.
     */
    public func clear() {
        clearMarkers()
        clearPolylines()
        clearPolygons()
        clearCircles()
    }
}
