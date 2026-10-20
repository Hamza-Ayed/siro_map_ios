# Siro Maps SDK for iOS (Swift)
### خريطة سيرو لنظام آي أو إس (سويفت)

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-14.0%2B-blue.svg)](https://apple.com)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-Compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-Compatible-red.svg)](https://cocoapods.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Commercial 2D & 3D sovereign vector map SDK for iOS supporting 3D terrain elevation, architectural extrusions, routing, forward and reverse geocoding in Arabic and English. 100% Google Maps iOS SDK (GMS*) compatible with backward compatibility for `IntaleqMaps`.

---

## Installation / التثبيت

### 1. Swift Package Manager (Recommended / الطريقة الرسمية في Xcode)
1. Open your Xcode project.
2. Select **File** > **Add Package Dependencies...**
3. Enter repository URL:
   ```
   https://github.com/Hamza-Ayed/siro_map_ios.git
   ```
4. Select version `1.0.0` or `Up to Next Major Version` and click **Add Package**.

Or in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Hamza-Ayed/siro_map_ios.git", from: "1.0.0")
]
```

### 2. CocoaPods (Alternative)
Add to your `Podfile`:

```ruby
pod 'SiroMap', '~> 1.0.0'
```

---

## Quickstart / دليل البدء السريع

### 1. Initialize SDK (في App أو AppDelegate)

```swift
import SwiftUI
import SiroMap

@main
struct MyApp: App {
    init() {
        SiroMap.initialize(
            apiKey: "YOUR_API_KEY",
            baseUrl: "https://map-saas.intaleqapp.com"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Add Map in SwiftUI

```swift
import SwiftUI
import SiroMap

struct ContentView: View {
    @State private var is3D: Bool = true

    var body: some View {
        SiroMapViewRepresentable(
            camera: SiroCameraPosition(
                target: SiroLatLng(latitude: 31.9539, longitude: 35.9106),
                zoom: 14.0,
                viewingAngle: 65.0,
                bearing: -35.0
            ),
            is3D: is3D,
            mapType: .terrain
        )
        .edgesIgnoringSafeArea(.all)
    }
}
```

### 3. Add Map in UIKit (with 100% GMS compatibility)

```swift
import UIKit
import SiroMap

class ViewController: UIViewController {
    var mapView: SiroMapView! // Also GMSMapView compatible

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView = SiroMapView(
            frame: view.bounds,
            camera: SiroCameraPosition(
                target: SiroLatLng(latitude: 31.9539, longitude: 35.9106),
                zoom: 13.0
            )
        )
        view.addSubview(mapView)

        mapView.getMapAsync { [weak self] controller in
            self?.mapView.set3DMode(true)
            self?.mapView.setMapType(.terrain)
            self?.mapView.addMarker(
                id: "amman_center",
                coordinate: SiroLatLng(latitude: 31.9539, longitude: 35.9106),
                title: "عمان - وسط البلد"
            )
        }
    }
}
```

### 4. Forward & Reverse Geocoding (البحث والاستعلام العكسي)

```swift
// 1. Forward Search (البحث عن معلم)
IntaleqGeocodingService.shared.search(query: "البتراء", limit: 5) { result in
    switch result {
    case .success(let places):
        if let place = places.first {
            print("Found: \(place.nameAr ?? place.name) at \(place.position)")
        }
    case .failure(let error):
        print("Error: \(error)")
    }
}

// 2. Reverse Geocoding (تحويل الإحداثيات إلى اسم حي وشارع)
let pos = InlqLatLng(latitude: 31.9539, longitude: 35.9106)
IntaleqGeocodingService.shared.reverseGeocode(position: pos) { result in
    if case .success(let place) = result, let place = place {
        print("Street: \(place.address ?? "")")
    }
}
```

---

## License
MIT License. © 2026 Intaleq Platform.
