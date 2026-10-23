/**
 * وظيفة الملف: تنفيذ جزء SiroGeocodingService ضمن حزمة العميل أو التطبيق.
 */
import Foundation

public struct SiroGeocodingPlace: Codable {
    public let id: String
    public let name: String
    public let nameAr: String?
    public let nameEn: String?
    public let category: String?
    public let city: String?
    public let neighbourhood: String?
    public let address: String?
    public let position: SiroLatLng
}

/**
 * Commercial Geocoding & Reverse Geocoding Service calling Siro SaaS API on iOS (Swift).
 */
public class SiroGeocodingService {

    public static let shared = SiroGeocodingService()

    private init() {}

    /**
     * Search for places, addresses, and POIs by text query.
     */
    public func search(
        query: String,
        proximity: SiroLatLng? = nil,
        limit: Int = 10,
        completion: @escaping (Result<[SiroGeocodingPlace], Error>) -> Void
    ) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(NSError(domain: "SiroMaps", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid query"])))
            return
        }

        var urlStr = "\(SiroMaps.shared.baseUrl)/api/geocoding/search?q=\(encoded)&limit=\(limit)"
        if let proximity = proximity {
            urlStr += "&lat=\(proximity.latitude)&lng=\(proximity.longitude)"
        }

        guard let url = URL(string: urlStr) else {
            completion(.failure(NSError(domain: "SiroMaps", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(SiroMaps.shared.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.success([]))
                return
            }

            let places = SiroGeocodingService.parsePlaces(from: data)
            completion(.success(places))
        }.resume()
    }

    /**
     * Reverse geocode coordinate to get street and neighborhood name.
     */
    public func reverseGeocode(
        position: SiroLatLng,
        completion: @escaping (Result<SiroGeocodingPlace?, Error>) -> Void
    ) {
        let urlStr = "\(SiroMaps.shared.baseUrl)/api/geocoding/reverse?lat=\(position.latitude)&lng=\(position.longitude)"
        guard let url = URL(string: urlStr) else {
            completion(.failure(NSError(domain: "SiroMaps", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(SiroMaps.shared.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.success(nil))
                return
            }

            let places = SiroGeocodingService.parsePlaces(from: data)
            completion(.success(places.first))
        }.resume()
    }

    // MARK: - Robust Response Parser
    public static func parsePlaces(from data: Data) -> [SiroGeocodingPlace] {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        var items: [[String: Any]] = []

        if let array = jsonObject as? [[String: Any]] {
            items = array
        } else if let dict = jsonObject as? [String: Any] {
            if let features = dict["features"] as? [[String: Any]] {
                items = features
            } else if let results = dict["results"] as? [[String: Any]] {
                items = results
            } else if let dataArray = dict["data"] as? [[String: Any]] {
                items = dataArray
            } else {
                items = [dict]
            }
        }

        return items.compactMap { item in
            // Handle GeoJSON feature format
            let props = (item["properties"] as? [String: Any]) ?? item

            var lat: Double?
            var lng: Double?

            // Format 1: Direct latitude & longitude
            if let itemLat = props["latitude"] as? Double, let itemLng = props["longitude"] as? Double {
                lat = itemLat
                lng = itemLng
            } else if let locDict = props["location"] as? [String: Any],
                      let itemLat = locDict["lat"] as? Double,
                      let itemLng = locDict["lng"] as? Double {
                // Format 2: location { lat, lng }
                lat = itemLat
                lng = itemLng
            } else if let geom = item["geometry"] as? [String: Any],
                      let coords = geom["coordinates"] as? [Double],
                      coords.count >= 2 {
                // Format 3: GeoJSON geometry [lng, lat]
                lat = coords[1]
                lng = coords[0]
            }

            guard let latitude = lat, let longitude = lng else { return nil }

            let idStr: String
            if let rawId = item["id"] ?? props["id"] {
                idStr = String(describing: rawId)
            } else {
                idStr = UUID().uuidString
            }

            let nameStr = (props["name"] as? String)
                ?? (props["name_ar"] as? String)
                ?? (props["human_readable_address"] as? String)
                ?? (props["full_address"] as? String)
                ?? "موقع محدد"

            let nameAr = props["name_ar"] as? String
            let nameEn = props["name_en"] as? String
            let category = props["category"] as? String
            let city = props["city"] as? String ?? props["governorate"] as? String
            let neighbourhood = props["neighbourhood"] as? String ?? props["district"] as? String
            let address = (props["full_address"] as? String) ?? (props["address"] as? String) ?? (props["human_readable_address"] as? String)

            return SiroGeocodingPlace(
                id: idStr,
                name: nameStr,
                nameAr: nameAr,
                nameEn: nameEn,
                category: category,
                city: city,
                neighbourhood: neighbourhood,
                address: address,
                position: SiroLatLng(latitude: latitude, longitude: longitude)
            )
        }
    }
}
