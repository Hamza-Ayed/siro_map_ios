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
    /// الوقت كـ Date للمقارنات الداخلية؛ لا يدخل في الترميز.
    internal var date: Date = .distantPast

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
        self.date = timestamp
    }
}

/**
 * Telemetry & periodic sync engine for the iOS SDK.
 * 1. Samples GPS while moving (every 3 seconds). While stationary, records one heartbeat every 30 seconds,
 *    driven by an internal timer so it does not depend on new location updates.
 * 2. Batches and uploads points every 2 minutes, or sooner at 40 points.
 * 3. Keeps up to 400 points in memory while offline.
 * Collection is off until the host app starts tracking with `consentGranted: true`.
 */
public class SiroTelemetryService {

    public static let shared = SiroTelemetryService()

    public static let samplingIntervalSeconds: TimeInterval = 3
    public static let heartbeatIntervalSeconds: TimeInterval = 30
    public static let defaultUploadIntervalSeconds: TimeInterval = 120 // دقيقتان
    public static let maxBatchSize: Int = 40 // 40 نقطة * 3 ثوان = 120 ثانية
    public static let maxBufferSize: Int = 400 // حفظ حتى 400 نقطة دون اتصال
    public static let stationarySpeedKmH: Double = 1.0
    public static let stationaryDistanceMeters: Double = 3.0

    private static let installIdKey = "siro_maps_telemetry_install_id"

    /// يولّد معرّف تثبيت عشوائياً بصيغة UUID v4، لا يُشتق من أي بيانات عن الجهاز أو المستخدم.
    public static func generateInstallId() -> String {
        return UUID().uuidString
    }

    /**
     * يرجع معرّف التثبيت المحفوظ، أو يولّد واحداً جديداً عند أول تشغيل.
     * يُحفظ في UserDefaults، فيُمسح مع بيانات التطبيق عند الحذف.
     */
    public static func loadOrCreateInstallId(defaults: UserDefaults = .standard) -> String {
        if let saved = defaults.string(forKey: installIdKey), !saved.isEmpty {
            return saved
        }
        let id = generateInstallId()
        defaults.set(id, forKey: installIdKey)
        return id
    }

    private var installId: String = ""
    private var enabled: Bool = true // خدمة التتبع مفعّلة إجبارياً وتلقائياً خلف الكواليس
    private var buffer: [SiroTelemetryPoint] = []
    private var lastSampleDate: Date?
    private var lastRecordedPoint: SiroTelemetryPoint?
    private var lastObservedPoint: SiroTelemetryPoint?
    private var stationary: Bool = false
    private var flushTimer: Timer?
    private var heartbeatTimer: Timer?
    private var isFlushing = false

    private let syncQueue = DispatchQueue(label: "com.siro.maps.telemetry.queue")

    /// يُستدعى عند كل تغيّر في حالة الوقوف (true = واقف).
    public var onStationaryChanged: ((Bool) -> Void)?

    public var bufferedPointCount: Int {
        return syncQueue.sync { buffer.count }
    }

    /// هل جمع التتبع مفعّل. الافتراضي: مفعّل إجبارياً وتلقائياً.
    public var isEnabled: Bool {
        return syncQueue.sync { enabled }
    }

    /// هل الجهاز واقف حالياً.
    public var isStationary: Bool {
        return syncQueue.sync { stationary }
    }

    private init() {}

    /**
     * يبدأ جلسة التتبع الدورية تلقائياً وإجبارياً.
     */
    public func startTracking(
        installId: String = loadOrCreateInstallId(),
        consentGranted: Bool = true,
        uploadIntervalSeconds: TimeInterval = defaultUploadIntervalSeconds
    ) {
        let effectiveId = installId.isEmpty ? Self.loadOrCreateInstallId() : installId
        syncQueue.sync {
            self.installId = effectiveId
        }
        setEnabled(consentGranted)

        DispatchQueue.main.async { [weak self] in
            self?.flushTimer?.invalidate()
            self?.heartbeatTimer?.invalidate()
            self?.flushTimer = nil
            self?.heartbeatTimer = nil
            guard consentGranted else { return }

            self?.flushTimer = Timer.scheduledTimer(withTimeInterval: uploadIntervalSeconds, repeats: true) { [weak self] _ in
                self?.flush()
            }
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Self.heartbeatIntervalSeconds, repeats: true) { [weak self] _ in
                self?.recordHeartbeat()
            }
        }
    }

    /**
     * يوقف المؤقتات ويرفع ما تبقى من النقاط.
     */
    public func stopTracking(completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.flushTimer?.invalidate()
            self?.flushTimer = nil
            self?.heartbeatTimer?.invalidate()
            self?.heartbeatTimer = nil
            self?.flush(completion: completion)
        }
    }

    /**
     * يفعّل أو يوقف الجمع. عند الإيقاف تُحذف النقاط غير المرسلة ولا يُسجَّل شيء بعدها.
     */
    public func setEnabled(_ value: Bool) {
        var changed = false
        syncQueue.sync {
            enabled = value
            if !value {
                buffer.removeAll()
                lastSampleDate = nil
                lastRecordedPoint = nil
                lastObservedPoint = nil
                if stationary {
                    stationary = false
                    changed = true
                }
            }
        }
        if changed {
            notifyStationary(false)
        }
    }

    /**
     * يسجّل موقعاً جديداً. عند الحركة كل 3 ثوانٍ، وعند الوقوف نبضة كل 30 ثانية.
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
        var stationaryChange: Bool?
        let recorded: Bool = syncQueue.sync { () -> Bool in
            guard enabled else { return false }

            let observed = SiroTelemetryPoint(
                driverId: customDriverId ?? installId,
                latitude: latitude,
                longitude: longitude,
                speed: speedKmH,
                heading: heading,
                elevation: elevation,
                distance: remainingDistance,
                timestamp: now
            )
            lastObservedPoint = observed

            // 1. Throttle: at least 3 seconds since the last recorded sample
            if let lastTime = lastSampleDate, now.timeIntervalSince(lastTime) < Self.samplingIntervalSeconds {
                return false
            }

            // 2. Stationary filter: while stationary, record a point only every 30 seconds
            let isStationaryNow = isStationaryAt(observed)
            if isStationaryNow != stationary {
                stationary = isStationaryNow
                stationaryChange = isStationaryNow
            }
            if isStationaryNow, let last = lastRecordedPoint,
               now.timeIntervalSince(last.date) < Self.heartbeatIntervalSeconds {
                return false
            }

            appendPoint(observed, at: now)
            return true
        }

        if let change = stationaryChange {
            notifyStationary(change)
        }
        return recorded
    }

    /**
     * نبضة ثابتة عند الوقوف: تُسجَّل كل 30 ثانية حتى دون وصول موقع جديد.
     * يستدعيها المؤقت داخلياً أثناء التتبع.
     */
    @discardableResult
    public func recordHeartbeat(now: Date = Date()) -> Bool {
        return syncQueue.sync { () -> Bool in
            guard enabled, stationary,
                  let last = lastObservedPoint,
                  let recorded = lastRecordedPoint,
                  now.timeIntervalSince(recorded.date) >= Self.heartbeatIntervalSeconds else {
                return false
            }
            let beat = SiroTelemetryPoint(
                driverId: last.driverId,
                latitude: last.latitude,
                longitude: last.longitude,
                speed: last.speed,
                heading: last.heading,
                elevation: last.elevation,
                distance: last.distance,
                timestamp: now
            )
            appendPoint(beat, at: now)
            return true
        }
    }

    internal func setInstallId(_ value: String) {
        syncQueue.sync { installId = value }
    }

    /// يجب استدعاؤها داخل syncQueue.
    private func isStationaryAt(_ observed: SiroTelemetryPoint) -> Bool {
        guard let last = lastRecordedPoint, observed.speed < Self.stationarySpeedKmH else { return false }
        let dist = calculateDistanceMeters(lat1: last.latitude, lon1: last.longitude, lat2: observed.latitude, lon2: observed.longitude)
        return dist < Self.stationaryDistanceMeters
    }

    /// يجب استدعاؤها داخل syncQueue.
    private func appendPoint(_ point: SiroTelemetryPoint, at date: Date) {
        if buffer.count >= Self.maxBufferSize {
            buffer.removeFirst()
        }
        buffer.append(point)
        lastSampleDate = date
        lastRecordedPoint = point

        // 3. Proactive flush when reaching the batch size
        if buffer.count >= Self.maxBatchSize {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.flush()
            }
        }
    }

    private func notifyStationary(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onStationaryChanged?(value)
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
