/**
 * وظيفة الملف: توفير واجهة عرض الخريطة SiroMapView لنظام iOS تدعم العرض ثنائي وثلاثي الأبعاد (2D & 3D).
 */
import Foundation
import WebKit
import SwiftUI

#if canImport(UIKit)
import UIKit
public typealias SiroBaseView = UIView
#elseif canImport(AppKit)
import AppKit
public typealias SiroBaseView = NSView
#endif

public protocol SiroMapViewDelegate: AnyObject {
    func mapView(_ mapView: SiroMapView, didTapAt coordinate: SiroLatLng)
    func mapView(_ mapView: SiroMapView, didChangeCameraPosition position: SiroCameraPosition)
    func mapViewDidFinishLoading(_ mapView: SiroMapView)
}

/**
 * High-performance iOS Map View displaying Siro 2D & 3D vector maps.
 * Compatible with Google Maps SDK GMSMapView conventions.
 */
public class SiroMapView: SiroBaseView, WKScriptMessageHandler, WKNavigationDelegate {

    public weak var delegate: SiroMapViewDelegate?
    public private(set) var controller: SiroMapController
    private var webView: WKWebView!
    private var isMapLoaded: Bool = false
    private var pendingAsyncCallbacks: [(SiroMapController) -> Void] = []
    
    public var is3DEnabled: Bool = false {
        didSet {
            set3DMode(is3DEnabled)
        }
    }

    public init(frame: CGRect, camera: SiroCameraPosition = SiroCameraPosition(target: SiroLatLng(latitude: 31.9539, longitude: 35.9106), zoom: 12.0)) {
        self.controller = SiroMapController()
        super.init(frame: frame)
        setupWebView(initialCamera: camera)
    }

    required init?(coder: NSCoder) {
        self.controller = SiroMapController()
        super.init(coder: coder)
        setupWebView(initialCamera: SiroCameraPosition(target: SiroLatLng(latitude: 31.9539, longitude: 35.9106), zoom: 12.0))
    }

    private func setupWebView(initialCamera: SiroCameraPosition) {
        let contentController = WKUserContentController()
        contentController.add(self, name: "siroMapBridge")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: bounds, configuration: config)
        #if canImport(UIKit)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        webView.scrollView.isScrollEnabled = false
        #elseif canImport(AppKit)
        webView.autoresizingMask = [.width, .height]
        #endif
        webView.navigationDelegate = self
        addSubview(webView)

        loadMapHTML(initialCamera: initialCamera)
    }

    private func loadMapHTML(initialCamera: SiroCameraPosition) {
        let styleUrl = SiroStyles.terrain
        let initialLat = initialCamera.target.latitude
        let initialLng = initialCamera.target.longitude
        let initialZoom = initialCamera.zoom
        let initialPitch = initialCamera.viewingAngle
        let initialBearing = initialCamera.bearing

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
            <title>Siro Maps</title>
            <script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
            <link href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css" rel="stylesheet" />
            <style>
                html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; background: #101014; }
                .marker-pin {
                    width: 32px;
                    height: 32px;
                    border-radius: 50% 50% 50% 0;
                    background: #0071E3;
                    position: absolute;
                    transform: rotate(-45deg);
                    left: 50%;
                    top: 50%;
                    margin: -16px 0 0 -16px;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.4);
                    border: 2px solid #ffffff;
                }
            </style>
        </head>
        <body>
            <div id="map"></div>
            <script>
                var map = new maplibregl.Map({
                    container: 'map',
                    style: '\(styleUrl)',
                    center: [\(initialLng), \(initialLat)],
                    zoom: \(initialZoom),
                    pitch: \(initialPitch),
                    bearing: \(initialBearing),
                    attributionControl: false
                });

                var activeMarkers = {};

                map.on('load', function() {
                    window.webkit.messageHandlers.siroMapBridge.postMessage({ type: 'onMapReady' });
                });

                map.on('click', function(e) {
                    window.webkit.messageHandlers.siroMapBridge.postMessage({
                        type: 'onMapClick',
                        lat: e.lngLat.lat,
                        lng: e.lngLat.lng
                    });
                });

                map.on('moveend', function() {
                    var c = map.getCenter();
                    window.webkit.messageHandlers.siroMapBridge.postMessage({
                        type: 'onCameraMove',
                        lat: c.lat,
                        lng: c.lng,
                        zoom: map.getZoom(),
                        pitch: map.getPitch(),
                        bearing: map.getBearing()
                    });
                });

                function setMapStyle(styleUrl) {
                    map.setStyle(styleUrl);
                }

                function set3D(enabled) {
                    if (enabled) {
                        map.easeTo({ pitch: 65, bearing: -35, duration: 1200 });
                    } else {
                        map.easeTo({ pitch: 0, bearing: 0, duration: 1000 });
                    }
                }

                function animateTo(lat, lng, zoom, pitch, bearing) {
                    var opt = { center: [lng, lat], duration: 1200 };
                    if (zoom !== undefined && zoom !== null) opt.zoom = zoom;
                    if (pitch !== undefined && pitch !== null) opt.pitch = pitch;
                    if (bearing !== undefined && bearing !== null) opt.bearing = bearing;
                    map.flyTo(opt);
                }

                function addMarker(id, lat, lng, title) {
                    if (activeMarkers[id]) {
                        activeMarkers[id].remove();
                    }
                    var el = document.createElement('div');
                    el.className = 'marker-pin';
                    var m = new maplibregl.Marker({ element: el })
                        .setLngLat([lng, lat])
                        .addTo(map);
                    if (title) {
                        var popup = new maplibregl.Popup({ offset: 25 }).setText(title);
                        m.setPopup(popup);
                    }
                    activeMarkers[id] = m;
                }

                function clearMarkers() {
                    for (var k in activeMarkers) {
                        activeMarkers[k].remove();
                    }
                    activeMarkers = {};
                }
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: URL(string: SiroMaps.shared.baseUrl))
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "siroMapBridge",
              let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }

        switch type {
        case "onMapReady":
            isMapLoaded = true
            delegate?.mapViewDidFinishLoading(self)
            for cb in pendingAsyncCallbacks {
                cb(controller)
            }
            pendingAsyncCallbacks.removeAll()

        case "onMapClick":
            if let lat = dict["lat"] as? Double, let lng = dict["lng"] as? Double {
                let coord = SiroLatLng(latitude: lat, longitude: lng)
                delegate?.mapView(self, didTapAt: coord)
            }

        case "onCameraMove":
            if let lat = dict["lat"] as? Double,
               let lng = dict["lng"] as? Double,
               let zoom = dict["zoom"] as? Double,
               let pitch = dict["pitch"] as? Double,
               let bearing = dict["bearing"] as? Double {
                SiroTelemetryService.shared.recordPosition(
                    latitude: lat,
                    longitude: lng,
                    speedKmH: 0.0,
                    heading: bearing
                )
                let pos = SiroCameraPosition(
                    target: SiroLatLng(latitude: lat, longitude: lng),
                    zoom: Float(zoom),
                    viewingAngle: pitch,
                    bearing: bearing
                )
                delegate?.mapView(self, didChangeCameraPosition: pos)
            }

        default:
            break
        }
    }

    // MARK: - Public API

    public func getMapAsync(completion: @escaping (SiroMapController) -> Void) {
        if isMapLoaded {
            completion(controller)
        } else {
            pendingAsyncCallbacks.append(completion)
        }
    }

    public func set3DMode(_ enabled: Bool) {
        self.is3DEnabled = enabled
        let js = "set3D(\(enabled ? "true" : "false"));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    public func setStyle(styleUrl: String) {
        let js = "setMapStyle('\(styleUrl)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    public func setMapType(_ mapType: SiroMapType) {
        switch mapType {
        case .terrain:
            setStyle(styleUrl: SiroStyles.terrain)
        case .dark:
            setStyle(styleUrl: SiroStyles.dark)
        case .satellite:
            setStyle(styleUrl: SiroStyles.satellite)
        case .normal, .light:
            setStyle(styleUrl: SiroStyles.normal)
        case .none:
            break
        }
    }

    public func animateCamera(to coordinate: SiroLatLng, zoom: Float? = nil, pitch: Double? = nil, bearing: Double? = nil) {
        let zoomStr = zoom != nil ? "\(zoom!)" : "null"
        let pitchStr = pitch != nil ? "\(pitch!)" : "null"
        let bearingStr = bearing != nil ? "\(bearing!)" : "null"
        let js = "animateTo(\(coordinate.latitude), \(coordinate.longitude), \(zoomStr), \(pitchStr), \(bearingStr));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    public func addMarker(id: String, coordinate: SiroLatLng, title: String? = nil) {
        let titleEscaped = title?.replacingOccurrences(of: "'", with: "\\'") ?? ""
        let js = "addMarker('\(id)', \(coordinate.latitude), \(coordinate.longitude), '\(titleEscaped)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    public func clearMarkers() {
        webView.evaluateJavaScript("clearMarkers();", completionHandler: nil)
    }
}

// MARK: - SwiftUI Support
#if canImport(UIKit)
public struct SiroMapViewRepresentable: UIViewRepresentable {
    public var camera: SiroCameraPosition
    public var is3D: Bool
    public var mapType: SiroMapType
    public var onMapReady: ((SiroMapView) -> Void)?

    public init(
        camera: SiroCameraPosition = SiroCameraPosition(target: SiroLatLng(latitude: 31.9539, longitude: 35.9106), zoom: 12.0),
        is3D: Bool = false,
        mapType: SiroMapType = .terrain,
        onMapReady: ((SiroMapView) -> Void)? = nil
    ) {
        self.camera = camera
        self.is3D = is3D
        self.mapType = mapType
        self.onMapReady = onMapReady
    }

    public func makeUIView(context: Context) -> SiroMapView {
        let mapView = SiroMapView(frame: .zero, camera: camera)
        mapView.getMapAsync { _ in
            mapView.setMapType(mapType)
            if is3D {
                mapView.set3DMode(true)
            }
            onMapReady?(mapView)
        }
        return mapView
    }

    public func updateUIView(_ uiView: SiroMapView, context: Context) {
        uiView.set3DMode(is3D)
        uiView.setMapType(mapType)
    }
}
#elseif canImport(AppKit)
public struct SiroMapViewRepresentable: NSViewRepresentable {
    public var camera: SiroCameraPosition
    public var is3D: Bool
    public var mapType: SiroMapType
    public var onMapReady: ((SiroMapView) -> Void)?

    public init(
        camera: SiroCameraPosition = SiroCameraPosition(target: SiroLatLng(latitude: 31.9539, longitude: 35.9106), zoom: 12.0),
        is3D: Bool = false,
        mapType: SiroMapType = .terrain,
        onMapReady: ((SiroMapView) -> Void)? = nil
    ) {
        self.camera = camera
        self.is3D = is3D
        self.mapType = mapType
        self.onMapReady = onMapReady
    }

    public func makeNSView(context: Context) -> SiroMapView {
        let mapView = SiroMapView(frame: .zero, camera: camera)
        mapView.getMapAsync { _ in
            mapView.setMapType(mapType)
            if is3D {
                mapView.set3DMode(true)
            }
            onMapReady?(mapView)
        }
        return mapView
    }

    public func updateNSView(_ nsView: SiroMapView, context: Context) {
        nsView.set3DMode(is3D)
        nsView.setMapType(mapType)
    }
}
#endif
