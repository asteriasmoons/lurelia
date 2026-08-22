//
//  LocationSearchService.swift
//  Lurelia
//
//  Thin wrapper around MapKit's `MKLocalSearchCompleter` (for as-you-type
//  suggestions) and `MKLocalSearch` (to resolve a picked suggestion into
//  a full `MKMapItem` with coordinates + postal address). Used by the
//  event editor's location field so any place a user can type — a
//  business name, an address, a landmark — resolves to something Apple
//  Maps can open directly, without asking the user for location
//  permission (the completer does not need the user's current location).
//

import Combine
import Foundation
import MapKit
import UIKit

/// A single resolved search result the picker hands back to the caller.
struct LureliaLocationResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    /// One-line "address" text stored on the event alongside the name.
    var addressLine: String { subtitle }
}

@MainActor
final class LocationSearchService: NSObject, ObservableObject {

    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    @Published var query: String = ""

    private let completer: MKLocalSearchCompleter
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()

        // Cast a wide net — any place a user can type into Maps should
        // show up (businesses, addresses, points of interest).
        completer.resultTypes = [.pointOfInterest, .address, .query]
        completer.delegate = self

        // Debounce the text field so we don't spam the completer on
        // every keystroke.
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                self?.updateQuery(value)
            }
            .store(in: &cancellables)
    }

    private func updateQuery(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completions = []
            return
        }
        completer.queryFragment = trimmed
    }

    /// Resolves a picked completion into a full `LureliaLocationResult`
    /// (coordinates + a single-line address).
    func resolve(_ completion: MKLocalSearchCompletion) async -> LureliaLocationResult? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let name = item.name ?? completion.title
            let subtitle = formattedAddress(from: item.placemark)
                ?? completion.subtitle
            return LureliaLocationResult(
                name: name,
                subtitle: subtitle,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
        } catch {
            return nil
        }
    }

    private func formattedAddress(from placemark: MKPlacemark) -> String? {
        let parts: [String?] = [
            placemark.subThoroughfare.flatMap { subThoroughfare in
                if let thoroughfare = placemark.thoroughfare {
                    return "\(subThoroughfare) \(thoroughfare)"
                }
                return subThoroughfare
            } ?? placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
            placemark.country
        ]
        let joined = parts.compactMap { $0 }.joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
}

extension LocationSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.completions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        Task { @MainActor in
            self.completions = []
        }
    }
}

// MARK: - Opening in Apple Maps

enum LureliaMapsOpener {
    /// Opens the given coordinate + name in Apple Maps. Falls back to a
    /// URL-string search if MapKit is unavailable.
    static func open(name: String?, address: String?, latitude: Double?, longitude: Double?) {
        if let latitude, let longitude {
            let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let placemark = MKPlacemark(coordinate: coord)
            let item = MKMapItem(placemark: placemark)
            item.name = name?.isEmpty == false ? name : (address ?? "Location")
            item.openInMaps(launchOptions: [
                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coord)
            ])
            return
        }

        let query = [name, address]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?q=\(encoded)")
        else { return }

        UIApplication.shared.open(url)
    }
}
