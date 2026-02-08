import Foundation

/// Erros do SDK HUG-Identity.
public enum IdentityServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String?)
    case photoRejected(String)
    case codeInvalid(String)
    case missingUserData(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL do serviço de verificação inválida."
        case .invalidResponse: return "Resposta inválida."
        case .apiError(let code, let msg): return msg ?? "Erro da API (\(code))."
        case .photoRejected(let msg): return msg
        case .codeInvalid(let msg): return msg
        case .missingUserData(let msg): return msg
        }
    }
}
