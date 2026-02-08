import UIKit

/// Serviço de verificação de identidade HUG-Identity (SDK).
/// Apresenta o fluxo: criar sessão → captura de foto → código por SMS/e-mail → confirmação.
public enum IdentityService {

    /// Inicia o fluxo de verificação de identidade a partir do view controller informado.
    /// Apresenta modalmente a tela de verificação (sessão, foto, código). Ao concluir com sucesso, cancelamento ou falha, o completion é chamado.
    /// - Parameters:
    ///   - from: View controller a partir do qual o fluxo será apresentado (geralmente a tela atual).
    ///   - config: Configuração com URL base, token (opcional), userId, email e phone.
    ///   - completion: Callback com o resultado: .success, .cancelled ou .failure(Error).
    public static func startVerification(
        from viewController: UIViewController,
        config: IdentityServiceConfig,
        completion: @escaping (VerificationResult) -> Void
    ) {
        guard !config.userId.isEmpty, !config.email.isEmpty, !config.phone.isEmpty else {
            completion(.failure(IdentityServiceError.missingUserData("userId, email e phone são obrigatórios.")))
            return
        }
        let verificationVC = VerificationViewController(config: config) { result in
            completion(result)
        }
        let nav = UINavigationController(rootViewController: verificationVC)
        nav.modalPresentationStyle = .fullScreen
        viewController.present(nav, animated: true)
    }
}
