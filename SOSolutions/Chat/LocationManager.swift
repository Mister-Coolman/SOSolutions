import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    private var completion: ((String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation(completion: @escaping (String) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            deliver("Unknown location")
        }
    }

    private func deliver(_ result: String) {
        completion?(result)
        completion = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            deliver("Unknown location")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let p = placemarks?.first
            let parts = [p?.subThoroughfare, p?.thoroughfare, p?.locality, p?.administrativeArea, p?.postalCode]
                .compactMap { $0 }
            let address = parts.isEmpty
                ? "\(location.coordinate.latitude), \(location.coordinate.longitude)"
                : parts.joined(separator: " ")
            DispatchQueue.main.async { self?.deliver(address) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        deliver("Unknown location")
    }
}
