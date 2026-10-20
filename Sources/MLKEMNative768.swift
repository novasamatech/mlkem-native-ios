import CMLKEMNative
import Foundation
import Security

public enum MLKEMNative768 {
    public static let publicKeyLength = Int(MLKEM768_PUBLICKEYBYTES)
    public static let secretKeyLength = Int(MLKEM768_SECRETKEYBYTES)
    public static let ciphertextLength = Int(MLKEM768_CIPHERTEXTBYTES)
    public static let sharedSecretLength = Int(MLKEM_BYTES)
    public static let randomnessLength = Int(MLKEM_SYMBYTES)
    public static let keyPairSeedLength = 2 * Int(MLKEM_SYMBYTES)

    public struct Encapsulation: Sendable {
        public let ciphertext: Data
        public let sharedSecret: Data
    }

    public static func keyPair(seed: Data) throws -> (publicKey: Data, secretKey: Data) {
        try requireLength(of: seed, keyPairSeedLength, for: .seed)

        var publicKey = Data(count: publicKeyLength)
        var secretKey = Data(count: secretKeyLength)

        let status = publicKey.withUnsafeMutableBytes { publicKeyBytes in
            secretKey.withUnsafeMutableBytes { secretKeyBytes in
                seed.withUnsafeBytes { seedBytes in
                    NOVA_MLKEM768_keypair_derand(
                        publicKeyBytes.uint8Pointer,
                        secretKeyBytes.uint8Pointer,
                        seedBytes.uint8Pointer
                    )
                }
            }
        }

        try check(status)

        return (publicKey, secretKey)
    }

    public static func encapsulate(publicKey: Data) throws -> Encapsulation {
        var randomness = try secureRandomBytes(count: randomnessLength)
        defer { randomness.resetBytes(in: 0 ..< randomness.count) }

        return try encapsulate(publicKey: publicKey, randomness: randomness)
    }

    /// `randomness` must be 32 fresh uniformly random bytes: reusing or predicting it reveals the shared secret.
    public static func encapsulate(publicKey: Data, randomness: Data) throws -> Encapsulation {
        try requireLength(of: publicKey, publicKeyLength, for: .publicKey)
        try requireLength(of: randomness, randomnessLength, for: .randomness)

        var ciphertext = Data(count: ciphertextLength)
        var sharedSecret = Data(count: sharedSecretLength)

        let status = ciphertext.withUnsafeMutableBytes { ciphertextBytes in
            sharedSecret.withUnsafeMutableBytes { sharedSecretBytes in
                publicKey.withUnsafeBytes { publicKeyBytes in
                    randomness.withUnsafeBytes { randomnessBytes in
                        NOVA_MLKEM768_enc_derand(
                            ciphertextBytes.uint8Pointer,
                            sharedSecretBytes.uint8Pointer,
                            publicKeyBytes.uint8Pointer,
                            randomnessBytes.uint8Pointer
                        )
                    }
                }
            }
        }

        try check(status)

        return Encapsulation(ciphertext: ciphertext, sharedSecret: sharedSecret)
    }

    /// A ciphertext that does not belong to `secretKey` does not throw: ML-KEM implicit rejection returns a pseudorandom secret instead.
    public static func decapsulate(ciphertext: Data, secretKey: Data) throws -> Data {
        try requireLength(of: ciphertext, ciphertextLength, for: .ciphertext)
        try requireLength(of: secretKey, secretKeyLength, for: .secretKey)

        var sharedSecret = Data(count: sharedSecretLength)

        let status = sharedSecret.withUnsafeMutableBytes { sharedSecretBytes in
            ciphertext.withUnsafeBytes { ciphertextBytes in
                secretKey.withUnsafeBytes { secretKeyBytes in
                    NOVA_MLKEM768_dec(
                        sharedSecretBytes.uint8Pointer,
                        ciphertextBytes.uint8Pointer,
                        secretKeyBytes.uint8Pointer
                    )
                }
            }
        }

        try check(status)

        return sharedSecret
    }
}

private extension MLKEMNative768 {
    static func requireLength(of data: Data, _ expected: Int, for input: MLKEMError.Input) throws {
        guard data.count == expected else {
            throw MLKEMError.invalidLength(input, expected: expected, actual: data.count)
        }
    }

    static func check(_ status: Int32) throws {
        switch status {
        case 0:
            return
        case MLK_ERR_INVALID_PK:
            throw MLKEMError.invalidPublicKey
        case MLK_ERR_INVALID_SK:
            throw MLKEMError.invalidSecretKey
        default:
            throw MLKEMError.libraryFailure(status)
        }
    }

    static func secureRandomBytes(count: Int) throws -> Data {
        var bytes = Data(count: count)

        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }

        guard status == errSecSuccess else {
            throw MLKEMError.randomnessUnavailable(status)
        }

        return bytes
    }
}

private extension UnsafeRawBufferPointer {
    var uint8Pointer: UnsafePointer<UInt8> {
        bindMemory(to: UInt8.self).baseAddress!
    }
}

private extension UnsafeMutableRawBufferPointer {
    var uint8Pointer: UnsafeMutablePointer<UInt8> {
        bindMemory(to: UInt8.self).baseAddress!
    }
}
