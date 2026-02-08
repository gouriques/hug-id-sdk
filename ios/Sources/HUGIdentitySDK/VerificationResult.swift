import Foundation

/// Resultado do fluxo de verificação de identidade.
public enum VerificationResult {
    case success
    case cancelled
    case failure(Error)
}
