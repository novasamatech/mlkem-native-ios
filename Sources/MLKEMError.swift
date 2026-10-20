import Foundation

public enum MLKEMError: Error, Equatable, Sendable {
    public enum Input: Equatable, Sendable {
        case publicKey
        case secretKey
        case ciphertext
        case randomness
        case seed
    }

    case invalidLength(Input, expected: Int, actual: Int)
    case randomnessUnavailable(OSStatus)
    case invalidPublicKey
    case invalidSecretKey
    case libraryFailure(Int32)
}
