//
//  LocationClient.swift
//  Training
//
//  Created by David Croy on 3/19/2025
//

import CoreLocation
import ComposableArchitecture
import Foundation

@DependencyClient
struct LocationClient {
  var requestPermission: @Sendable () async -> Bool = { false }
  var getCurrentLocation: @Sendable () async throws -> CLLocation = { throw LocationError.notAuthorized }
  var startLocationUpdates: @Sendable () async -> AsyncStream<CLLocation> = { AsyncStream { _ in } }
  var stopLocationUpdates: @Sendable () async -> Void
  var geocodeAddress: @Sendable (_ address: String) async throws -> CLLocation = { _ in throw LocationError.geocodingFailed }
  var reverseGeocode: @Sendable (_ location: CLLocation) async throws -> CLPlacemark = { _ in throw LocationError.reverseGeocodingFailed }
}

enum LocationError: Error, Equatable {
  case notAuthorized
  case locationUnavailable
  case geocodingFailed
  case reverseGeocodingFailed
  case timeout
  
  var localizedDescription: String {
    switch self {
    case .notAuthorized:
      return "Location permission not granted"
    case .locationUnavailable:
      return "Unable to get current location"
    case .geocodingFailed:
      return "Unable to find address location"
    case .reverseGeocodingFailed:
      return "Unable to convert location to address"
    case .timeout:
      return "Location request timed out"
    }
  }
}

extension DependencyValues {
  var locationClient: LocationClient {
    get { self[LocationClient.self] }
    set { self[LocationClient.self] = newValue }
  }
}

extension LocationClient: DependencyKey {
  static let liveValue = LocationClient(
    requestPermission: {
      await LocationManager.shared.requestPermission()
    },
    getCurrentLocation: {
      try await LocationManager.shared.getCurrentLocation()
    },
    startLocationUpdates: {
      await LocationManager.shared.startLocationUpdates()
    },
    stopLocationUpdates: {
      await LocationManager.shared.stopLocationUpdates()
    },
    geocodeAddress: { address in
      try await LocationManager.shared.geocodeAddress(address)
    },
    reverseGeocode: { location in
      try await LocationManager.shared.reverseGeocode(location)
    }
  )
  
  static let testValue = LocationClient()
}

// MARK: - Location Manager Implementation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
  static let shared = LocationManager()
  
  private let manager = CLLocationManager()
  private var permissionContinuation: CheckedContinuation<Bool, Never>?
  private var locationContinuation: CheckedContinuation<CLLocation, Error>?
  private var locationStream: AsyncStream<CLLocation>.Continuation?
  
  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
  }
  
  func requestPermission() async -> Bool {
    let status = manager.authorizationStatus
    
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      return true
    case .denied, .restricted:
      return false
    case .notDetermined:
      return await withCheckedContinuation { continuation in
        self.permissionContinuation = continuation
        manager.requestWhenInUseAuthorization()
      }
    @unknown default:
      return false
    }
  }
  
  func getCurrentLocation() async throws -> CLLocation {
    let status = manager.authorizationStatus
    guard status == .authorizedAlways || status == .authorizedWhenInUse else {
      throw LocationError.notAuthorized
    }
    
    return try await withCheckedThrowingContinuation { continuation in
      self.locationContinuation = continuation
      manager.requestLocation()
    }
  }
  
  func startLocationUpdates() async -> AsyncStream<CLLocation> {
    return AsyncStream { continuation in
      self.locationStream = continuation
      manager.startUpdatingLocation()
      
      continuation.onTermination = { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.manager.stopUpdatingLocation()
          self?.locationStream = nil
        }
      }
    }
  }
  
  func stopLocationUpdates() async {
    manager.stopUpdatingLocation()
    locationStream?.finish()
    locationStream = nil
  }
  
  func geocodeAddress(_ address: String) async throws -> CLLocation {
    let geocoder = CLGeocoder()
    let placemarks = try await geocoder.geocodeAddressString(address)
    
    guard let location = placemarks.first?.location else {
      throw LocationError.geocodingFailed
    }
    
    return location
  }
  
  func reverseGeocode(_ location: CLLocation) async throws -> CLPlacemark {
    let geocoder = CLGeocoder()
    let placemarks = try await geocoder.reverseGeocodeLocation(location)
    
    guard let placemark = placemarks.first else {
      throw LocationError.reverseGeocodingFailed
    }
    
    return placemark
  }
  
  // MARK: - CLLocationManagerDelegate
  
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    Task { @MainActor in
      let granted = status == .authorizedAlways || status == .authorizedWhenInUse
      permissionContinuation?.resume(returning: granted)
      permissionContinuation = nil
    }
  }
  
  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let location = locations.last
    Task { @MainActor in
      guard let location = location else { return }
      
      // Handle one-time location request
      if let continuation = locationContinuation {
        continuation.resume(returning: location)
        locationContinuation = nil
      }
      
      // Handle streaming location updates
      locationStream?.yield(location)
    }
  }
  
  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      if let continuation = locationContinuation {
        continuation.resume(throwing: LocationError.locationUnavailable)
        locationContinuation = nil
      }
      
      locationStream?.finish()
    }
  }
}
