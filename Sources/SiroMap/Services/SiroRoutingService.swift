/**
 * وظيفة الملف: تنفيذ جزء SiroRoutingService ضمن حزمة العميل أو التطبيق.
 */
import Foundation

public struct SiroRouteStep: Codable {
    public let instructionAr: String
    public let distanceMeters: Double
    public let durationSeconds: Double
    public let maneuverSign: Int
    public let inclinePercentage: Double
}

public struct SiroCommercialRoute: Codable {
    public let coordinates: [SiroLatLng]
    public let steps: [SiroRouteStep]
    public let totalDistanceMeters: Double
    public let totalDurationSeconds: Double
    public let elevationGainMeters: Double
    public let elevationLossMeters: Double
    public let averageInclinePercentage: Double
    public let maxInclinePercentage: Double
}

/**
 * Commercial Routing Service calling Siro SaaS Routing API on iOS (Swift).
 */
public class SiroRoutingService {

    public static let shared = SiroRoutingService()

    private init() {}

    public func calculateRoute(
        origin: SiroLatLng,
        destination: SiroLatLng,
        profile: String = "car",
        locale: String = "ar",
        completion: @escaping (Result<SiroCommercialRoute, Error>) -> Void
    ) {
        let urlStr = "\(SiroMaps.shared.baseUrl)/api/maps/route?" +
            "fromLat=\(origin.latitude)&fromLng=\(origin.longitude)&" +
            "toLat=\(destination.latitude)&toLng=\(destination.longitude)&" +
            "profile=\(profile)&steps=true&locale=\(locale)"

        guard let url = URL(string: urlStr) else {
            completion(.failure(NSError(domain: "SiroMaps", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(SiroMaps.shared.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "SiroMaps", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let paths = json["paths"] as? [[String: Any]], let firstPath = paths.first {

                    let distance = firstPath["distance"] as? Double ?? 0.0
                    let timeMs = firstPath["time"] as? Double ?? 0.0

                    var coords: [SiroLatLng] = []
                    if let points = firstPath["points"] as? [String: Any],
                       let list = points["coordinates"] as? [[Double]] {
                        coords = list.map { SiroLatLng(latitude: $0[1], longitude: $0[0]) }
                    }

                    var steps: [SiroRouteStep] = []
                    if let instructions = firstPath["instructions"] as? [[String: Any]] {
                        steps = instructions.map {
                            SiroRouteStep(
                                instructionAr: $0["text"] as? String ?? "",
                                distanceMeters: $0["distance"] as? Double ?? 0.0,
                                durationSeconds: ($0["time"] as? Double ?? 0.0) / 1000.0,
                                maneuverSign: $0["sign"] as? Int ?? 0,
                                inclinePercentage: 0.0
                            )
                        }
                    }

                    let route = SiroCommercialRoute(
                        coordinates: coords,
                        steps: steps,
                        totalDistanceMeters: distance,
                        totalDurationSeconds: timeMs / 1000.0,
                        elevationGainMeters: 0.0,
                        elevationLossMeters: 0.0,
                        averageInclinePercentage: 0.0,
                        maxInclinePercentage: 0.0
                    )

                    completion(.success(route))
                } else {
                    completion(.failure(NSError(domain: "SiroMaps", code: -3, userInfo: [NSLocalizedDescriptionKey: "Malformed route response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
