#if compiler(>=6.2) && canImport(CryptoKit)
import CryptoKit
import MLKEMNative
import XCTest

final class CryptoKitCrossCheckTests: XCTestCase {
    func testCryptoKitDerivesVectorPublicKeyFromSeed() throws {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            throw XCTSkip("CryptoKit ML-KEM requires iOS 26 or macOS 26")
        }

        let privateKey = try MLKEM768.PrivateKey(
            seedRepresentation: BittensorVector.keyPairSeed,
            publicKey: nil
        )

        XCTAssertEqual(privateKey.publicKey.rawRepresentation, BittensorVector.publicKey)
    }

    func testCryptoKitDecapsulatesOurSignedExtrinsicCiphertext() throws {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            throw XCTSkip("CryptoKit ML-KEM requires iOS 26 or macOS 26")
        }

        let encapsulation = try MLKEMNative768.encapsulate(
            publicKey: BittensorVector.publicKey,
            randomness: BittensorVector.signedExtrinsicSized150.randomness
        )
        let privateKey = try MLKEM768.PrivateKey(
            seedRepresentation: BittensorVector.keyPairSeed,
            publicKey: nil
        )

        let sharedSecret = try privateKey.decapsulate(encapsulation.ciphertext)

        XCTAssertEqual(sharedSecret.withUnsafeBytes { Data($0) }, encapsulation.sharedSecret)
    }

    func testCryptoKitDecapsulatesOurOneByteCiphertext() throws {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            throw XCTSkip("CryptoKit ML-KEM requires iOS 26 or macOS 26")
        }

        let encapsulation = try MLKEMNative768.encapsulate(
            publicKey: BittensorVector.publicKey,
            randomness: BittensorVector.oneByte.randomness
        )
        let privateKey = try MLKEM768.PrivateKey(
            seedRepresentation: BittensorVector.keyPairSeed,
            publicKey: nil
        )

        let sharedSecret = try privateKey.decapsulate(encapsulation.ciphertext)

        XCTAssertEqual(sharedSecret.withUnsafeBytes { Data($0) }, encapsulation.sharedSecret)
    }

    func testCryptoKitDecapsulatesOurRandomizedCiphertext() throws {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            throw XCTSkip("CryptoKit ML-KEM requires iOS 26 or macOS 26")
        }

        let encapsulation = try MLKEMNative768.encapsulate(publicKey: BittensorVector.publicKey)
        let privateKey = try MLKEM768.PrivateKey(
            seedRepresentation: BittensorVector.keyPairSeed,
            publicKey: nil
        )

        let sharedSecret = try privateKey.decapsulate(encapsulation.ciphertext)

        XCTAssertEqual(sharedSecret.withUnsafeBytes { Data($0) }, encapsulation.sharedSecret)
    }

    func testCryptoKitImplicitRejectionMatchesOursForTamperedCiphertext() throws {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            throw XCTSkip("CryptoKit ML-KEM requires iOS 26 or macOS 26")
        }

        var ciphertext = BittensorVector.oneByte.ciphertext
        ciphertext[0] ^= 0x01
        let privateKey = try MLKEM768.PrivateKey(
            seedRepresentation: BittensorVector.keyPairSeed,
            publicKey: nil
        )

        let sharedSecret = try MLKEMNative768.decapsulate(
            ciphertext: ciphertext,
            secretKey: BittensorVector.secretKey
        )
        let cryptoKitSharedSecret = try privateKey.decapsulate(ciphertext)

        XCTAssertEqual(sharedSecret, cryptoKitSharedSecret.withUnsafeBytes { Data($0) })
    }

    func testWeDecapsulateCryptoKitCiphertext() throws {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            throw XCTSkip("CryptoKit ML-KEM requires iOS 26 or macOS 26")
        }

        let publicKey = try MLKEM768.PublicKey(rawRepresentation: BittensorVector.publicKey)
        let encapsulation = try publicKey.encapsulate()

        let sharedSecret = try MLKEMNative768.decapsulate(
            ciphertext: encapsulation.encapsulated,
            secretKey: BittensorVector.secretKey
        )

        XCTAssertEqual(sharedSecret, encapsulation.sharedSecret.withUnsafeBytes { Data($0) })
    }
}
#endif
