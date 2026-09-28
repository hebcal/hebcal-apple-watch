//
//  LocationManager.swift
//  HebcalHDate WatchKit App
//
//  Gets a one-off location fix for sunset and candle times when the user
//  has turned on "Use Location". Only the app asks: the widget extension
//  can't prompt, so it reads the fix the app saved in the App Group suite.
//

import CoreLocation
import HebcalWatchCore
import os

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    /// Called on the main thread with each new fix.
    var onLocation: ((GeoPoint) -> Void)?
    /// Called on the main thread when the user declines, or has turned
    /// location off for the app in the watch's Settings.
    var onDenied: (() -> Void)?

    private let manager = CLLocationManager()
    private var wantsFix = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        // Sunset moves about 4 seconds per km east–west; a few km is plenty.
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Asks for permission the first time, then for a single fix.
    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            wantsFix = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            onDenied?()
        default:
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        Logger.model.debug("location authorization \(manager.authorizationStatus.rawValue)")
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if wantsFix {
                wantsFix = false
                manager.requestLocation()
            }
        case .denied, .restricted:
            wantsFix = false
            onDenied?()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let point = GeoPoint(latitude: location.coordinate.latitude,
                             longitude: location.coordinate.longitude,
                             timeZoneIdentifier: TimeZone.current.identifier)
        Logger.model.debug("location fix \(point.latitude), \(point.longitude) \(point.timeZoneIdentifier)")
        onLocation?(point)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep using the last fix, if any; we'll try again next time the
        // app becomes active.
        Logger.model.error("location failed: \(error.localizedDescription)")
    }
}
