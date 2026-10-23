/**
 * وظيفة الملف: خدمة التتبع اللحظي والتجميع الدوري للبيانات في iOS Swift SDK (Telemetry & Fleet Batching).
 */
import Foundation
import CoreLocation

public struct SiroTelemetryPoint: Codable {
    public let driverId: String
    public let latitude: Double
    public let longitude: Double
    public let speed: Double
    public let heading: Double
    public let elevation: Double
    public let distance: Double
    public let timestamp: String

    enum CodingKeys: String, CodingKey {
        case driverId = "driver_id"
        case latitude, longitude, speed, heading, elevation, distance, timestamp
    }

    public init(
        driverId: String,
        latitude: Double,
        longitude: Double,
        speed: Double,
        heading: Double,
        elevation: Double = 0.0,
        distance: Double = 0.0,
        timestamp: Date = Date()
    ) {
        self.driverId = driverId
        self.latitude = latitude
        self.longitude = longitude
        self.speed = max(0.0, speed)
        self.heading = max(0.0, heading)
        self.elevation = elevation
        self.distance = distance

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.timestamp = formatter.string(from: timestamp)
    }
}

/**
 * Commercial Telemetry & Periodic Sync Engine for iOS Swift SDK.
 * 1. Samples GPS location every 3 seconds with a stationary filter to protect battery.
 * 2. Batches and flushes points to MapSaaS backend every 2 minutes (or 40 points).
 * 3. Offline buffer retains up to 400 points when disconnected (~20 minutes offline).
 */
public class SiroTelemetryService {

    public static let shared = SiroTelemetryService()

    public static let samplingIntervalSeconds: TimeInterval = 3
    public static let defaultUploadIntervalSeconds: TimeInterval = 120 // دقيقتان
    public static let maxBatchSize: Int = 40 // 40 نقطة * 3 ثوان = 120 ثانية
    public static let maxBufferSize: Int = 400 // حفظ حتى 400 نقطة دون اتصال

    private var defaultDriverId: String = "anonymous_driver"
    private var buffer: [SiroTelemetryPoint] = []
    private var lastSampleDate: Date?
    private var lastRecordedPoint: SiroTelemetryPoint?
    private var flushTimer: Timer?
    private var isFlushing = false

    private let syncQueue = DispatchQueue(label: "com.siro.maps.telemetry.queue")

    public var bufferedPointCount: Int {
        return syncQueue.sync { buffer.count }
    }

    private init() {}

    /**
     * Initializes periodic flush timer for an active navigation/tracking session.
     */
    public func startTracking(
        driverId: String,
        uploadIntervalSeconds: TimeInterval = defaultUploadIntervalSeconds
    ) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.defaultDriverId = driverId

            DispatchQueue.main.async {
                self.flushTimer?.invalidate()
                self.flushTimer = Timer.scheduledTimer(withTimeInterval: uploadIntervalSeconds, repeats: true) { [weak self] _ in
                    self?.flush()
                }
            }
        }
    }

    /**
     * Stops tracking timer and flushes any pending points.
     */
    public func stopTracking(completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.flushTimer?.invalidate()
            self?.flushTimer = nil
            self?.flush(completion: completion)
        }
    }

    /**
     * Records a new GPS position snapshot every 3 seconds.
     * Applies stationary filtering when vehicle is parked (<1 km/h) to minimize bandwidth.
     */
    @discardableResult
    public func recordPosition(
        latitude: Double,
        longitude: Double,
        speedKmH: Double,
        heading: Double,
        elevation: Double = 0.0,
        remainingDistance: Double = 0.0,
        customDriverId: String? = nil,
        now: Date = Date()
    ) -> Bool {
        return syncQueue.sync {
            // 1. Throttle: Must be at least 3 seconds since last sample
            if let lastTime = lastSampleDate {
                let elapsed = now.timeIntervalSince(lastTime)
                if elapsed < Self.samplingIntervalSeconds {
                    return false
                }
            }

            // 2. Smart stationary filter:
            // If speed < 1 km/h and vehicle moved < 3 meters, only record a heartbeat every 30 seconds
            if let last = lastRecordedPoint {
                let isNearZero = speedKmH < 1.0
                let dist = calculateDistanceMeters(lat1: last.latitude, lon1: last.longitude, lat2: latitude, lon2: longitude)
                if isNearZero && dist < 3.0 {
                    if let lastDate = lastSampleDate, now.timeIntervalSince(lastDate) < 30.0 {
                        return false
                    }
                }
            }

            let driverId = customDriverId ?? defaultDriverId
            let point = SiroTelemetryPoint(
                driverId: driverId,
                latitude: latitude,
                longitude: longitude,
                speed: speedKmH,
                heading: heading,
                elevation: elevation,
                distance: remainingDistance,
                timestamp: now
            )

            if buffer.count >= Self.maxBufferSize {
                buffer.removeFirst()
            }
            buffer.append(point)

            lastSampleDate = now
            lastRecordedPoint = point

            // 3. Proactive flush if batch threshold reached
            if buffer.count >= Self.maxBatchSize {
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    self?.flush()
                }
            }

            return true
        }
    }

    /**
     * Flushes all buffered telemetry points to MapSaaS backend in a single request (POST /api/telemetry/batch).
     */
    public func flush(completion: ((Bool) -> Void)? = nil) {
        syncQueue.async { [weak self] in
            guard let self = self else {
                completion?(false)
                return
            }

            if self.buffer.isEmpty {
                completion?(true)
                return
            }

            if self.isFlushing {
                completion?(false)
                return
            }

            self.isFlushing = true
            let pointsToSend = Array(self.buffer)

            guard let url = URL(string: "\(SiroMaps.shared.baseUrl)/api/telemetry/batch") else {
                self.isFlushing = false
                completion?(false)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if !SiroMaps.shared.apiKey.isEmpty {
                request.setValue(SiroMaps.shared.apiKey, forHTTPHeaderField: "x-api-key")
            }

            let payload: [String: Any] = [
                "points": pointsToSend.map { pt -> [String: Any] in
                    return [
                        "driver_id": pt.driverId,
                        "latitude": pt.latitude,
                        "longitude": pt.longitude,
                        "speed": pt.speed,
                        "heading": pt.heading,
                        "elevation": pt.elevation,
                        "distance": pt.distance,
                        "timestamp": pt.timestamp
                    ]
                }
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                self.isFlushing = false
                completion?(false)
                return
            }

            URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                guard let self = self else { return }

                var success = false
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    success = true
                    self.syncQueue.async {
                        self.buffer.removeFirst(min(pointsToSend.count, self.buffer.count))
                    }
                }

                self.syncQueue.async {
                    self.isFlushing = false
                }

                completion?(success)
            }.resume()
        }
    }

    /**
     * Real-time live telemetry push for a single point (POST /api/telemetry).
     */
    public func sendInstantTelemetry(
        point: SiroTelemetryPoint,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let url = URL(string: "\(SiroMaps.shared.baseUrl)/api/telemetry") else {
            completion?(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !SiroMaps.shared.apiKey.isEmpty {
            request.setValue(SiroMaps.shared.apiKey, forHTTPHeaderField: "x-api-key")
        }

        let dict: [String: Any] = [
            "driver_id": point.driverId,
            "latitude": point.latitude,
            "longitude": point.longitude,
            "speed": point.speed,
            "heading": point.heading,
            "elevation": point.elevation,
            "distance": point.distance,
            "timestamp": point.timestamp
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: dict) else {
            completion?(false)
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion?((200...299).contains(ok))
        }.resume()
    }

    private func calculateDistanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371000.0
        let phi1 = lat1 * .pi / 180.0
        let phi2 = lat2 * .pi / 180.0
        let deltaPhi = (lat2 - lat1) * .pi / 180.0
        let deltaLambda = (lon2 - lon1) * .pi / 180.0

        let a = sin(deltaPhi / 2.0) * sin(deltaPhi / 2.0) +
                cos(phi1) * cos(phi2) *
                sin(deltaLambda / 2.0) * sin(deltaLambda / 2.0)
        let c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
        return r * c
    }
}
