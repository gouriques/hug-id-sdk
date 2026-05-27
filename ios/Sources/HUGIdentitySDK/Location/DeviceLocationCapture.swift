import CoreLocation
import UIKit

/// Amostra de localização capturada no dispositivo.
public struct DeviceLocationSample {
    public let latitude: Double
    public let longitude: Double
    public let accuracyMeters: Double?
    public let source: String
    public let capturedAt: Date

    public init(
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double? = nil,
        source: String = "gps",
        capturedAt: Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracyMeters = accuracyMeters
        self.source = source
        self.capturedAt = capturedAt
    }
}

/// Captura localização com permissão When In Use (fluxo da verificação HUG-ID).
final class DeviceLocationCapture: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<DeviceLocationSample?, Never>?
    private var authContinuation: CheckedContinuation<Bool, Never>?
    private weak var presentingViewController: UIViewController?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Solicita permissão (se necessário) e retorna a melhor localização disponível, ou `nil` se negada/indisponível.
    func capture(from viewController: UIViewController) async -> DeviceLocationSample? {
        presentingViewController = viewController
        guard await ensureAuthorization() else { return nil }
        return await requestSingleLocation()
    }

    private func ensureAuthorization() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                authContinuation = cont
                manager.requestWhenInUseAuthorization()
            }
        case .denied, .restricted:
            await MainActor.run {
                if let vc = presentingViewController {
                    showSettingsAlert(on: vc)
                }
            }
            return false
        @unknown default:
            return false
        }
    }

    private func requestSingleLocation() async -> DeviceLocationSample? {
        await withCheckedContinuation { cont in
            locationContinuation = cont
            manager.requestLocation()
        }
    }

    private func showSettingsAlert(on viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Localização",
            message: "Para reforçar a segurança da verificação, permita o acesso à localização nas configurações do app.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Configurações", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        viewController.present(alert, animated: true)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let cont = authContinuation else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authContinuation = nil
            cont.resume(returning: true)
        case .denied, .restricted:
            authContinuation = nil
            if let vc = presentingViewController {
                Task { @MainActor in self.showSettingsAlert(on: vc) }
            }
            cont.resume(returning: false)
        case .notDetermined:
            break
        @unknown default:
            authContinuation = nil
            cont.resume(returning: false)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        guard let loc = locations.last else {
            cont.resume(returning: nil)
            return
        }
        cont.resume(returning: DeviceLocationSample(
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            accuracyMeters: loc.horizontalAccuracy >= 0 ? loc.horizontalAccuracy : nil,
            source: "gps",
            capturedAt: loc.timestamp
        ))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
