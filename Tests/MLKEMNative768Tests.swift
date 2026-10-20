import MLKEMNative
import XCTest

final class MLKEMNative768Tests: XCTestCase {
    func testLengthConstantsMatchFIPS203() {
        XCTAssertEqual(MLKEMNative768.publicKeyLength, 1184)
        XCTAssertEqual(MLKEMNative768.secretKeyLength, 2400)
        XCTAssertEqual(MLKEMNative768.ciphertextLength, 1088)
        XCTAssertEqual(MLKEMNative768.sharedSecretLength, 32)
        XCTAssertEqual(MLKEMNative768.randomnessLength, 32)
        XCTAssertEqual(MLKEMNative768.keyPairSeedLength, 64)
    }

    func testEncapsulateRejectsPublicKeyWithCoefficientEqualToModulus() {
        let publicKey = Self.publicKeyWithFirstCoefficientEqualToModulus()

        XCTAssertThrowsError(
            try MLKEMNative768.encapsulate(publicKey: publicKey, randomness: BittensorVector.oneByte.randomness)
        ) { error in
            XCTAssertEqual(error as? MLKEMError, .invalidPublicKey)
        }
    }

    func testRandomizedEncapsulateRejectsPublicKeyWithCoefficientEqualToModulus() {
        let publicKey = Self.publicKeyWithFirstCoefficientEqualToModulus()

        XCTAssertThrowsError(try MLKEMNative768.encapsulate(publicKey: publicKey)) { error in
            XCTAssertEqual(error as? MLKEMError, .invalidPublicKey)
        }
    }

    func testDecapsulateRejectsSecretKeyWithInconsistentPublicKeyHash() {
        let pkeSecretKeyLength = 1152
        let publicKeyHashOffset = pkeSecretKeyLength + MLKEMNative768.publicKeyLength
        var secretKey = BittensorVector.secretKey
        secretKey[publicKeyHashOffset] ^= 0x01

        XCTAssertThrowsError(
            try MLKEMNative768.decapsulate(ciphertext: BittensorVector.oneByte.ciphertext, secretKey: secretKey)
        ) { error in
            XCTAssertEqual(error as? MLKEMError, .invalidSecretKey)
        }
    }

    func testDecapsulateOfTamperedCiphertextReturnsUnrelatedSecret() throws {
        var ciphertext = BittensorVector.oneByte.ciphertext
        ciphertext[0] ^= 0x01

        let sharedSecret = try MLKEMNative768.decapsulate(ciphertext: ciphertext, secretKey: BittensorVector.secretKey)

        XCTAssertEqual(sharedSecret.count, MLKEMNative768.sharedSecretLength)
        XCTAssertNotEqual(sharedSecret, BittensorVector.oneByte.sharedSecret)
    }

    func testKeyPairRejectsWrongSeedLength() {
        XCTAssertThrowsError(try MLKEMNative768.keyPair(seed: Data(count: 63))) { error in
            XCTAssertEqual(error as? MLKEMError, .invalidLength(.seed, expected: 64, actual: 63))
        }
    }

    func testEncapsulateRejectsWrongPublicKeyLength() {
        let publicKey = BittensorVector.publicKey.dropLast()

        XCTAssertThrowsError(try MLKEMNative768.encapsulate(publicKey: publicKey)) { error in
            XCTAssertEqual(error as? MLKEMError, .invalidLength(.publicKey, expected: 1184, actual: 1183))
        }
    }

    func testEncapsulateRejectsWrongRandomnessLength() {
        XCTAssertThrowsError(
            try MLKEMNative768.encapsulate(publicKey: BittensorVector.publicKey, randomness: Data(count: 33))
        ) { error in
            XCTAssertEqual(error as? MLKEMError, .invalidLength(.randomness, expected: 32, actual: 33))
        }
    }

    func testDecapsulateRejectsWrongCiphertextLength() {
        XCTAssertThrowsError(
            try MLKEMNative768.decapsulate(ciphertext: Data(count: 1087), secretKey: BittensorVector.secretKey)
        ) { error in
            XCTAssertEqual(error as? MLKEMError, .invalidLength(.ciphertext, expected: 1088, actual: 1087))
        }
    }

    func testDecapsulateRejectsWrongSecretKeyLength() {
        XCTAssertThrowsError(
            try MLKEMNative768.decapsulate(ciphertext: BittensorVector.oneByte.ciphertext, secretKey: Data())
        ) { error in
            XCTAssertEqual(error as? MLKEMError, .invalidLength(.secretKey, expected: 2400, actual: 0))
        }
    }

    func testRandomizedEncapsulationRoundTripsThroughDecapsulation() throws {
        let keyPair = try MLKEMNative768.keyPair(seed: .random(count: MLKEMNative768.keyPairSeedLength))

        let encapsulation = try MLKEMNative768.encapsulate(publicKey: keyPair.publicKey)
        let sharedSecret = try MLKEMNative768.decapsulate(
            ciphertext: encapsulation.ciphertext,
            secretKey: keyPair.secretKey
        )

        XCTAssertEqual(encapsulation.ciphertext.count, MLKEMNative768.ciphertextLength)
        XCTAssertEqual(sharedSecret, encapsulation.sharedSecret)
    }

    func testRandomizedEncapsulationsOfSamePublicKeyDiffer() throws {
        let first = try MLKEMNative768.encapsulate(publicKey: BittensorVector.publicKey)
        let second = try MLKEMNative768.encapsulate(publicKey: BittensorVector.publicKey)

        XCTAssertNotEqual(first.ciphertext, second.ciphertext)
        XCTAssertNotEqual(first.sharedSecret, second.sharedSecret)
    }

    func testPublicKeySliceWithNonZeroStartIndexIsAccepted() throws {
        let padded = Data([0xAA]) + BittensorVector.publicKey
        let publicKey = padded.dropFirst()

        let encapsulation = try MLKEMNative768.encapsulate(
            publicKey: publicKey,
            randomness: BittensorVector.oneByte.randomness
        )

        XCTAssertEqual(encapsulation.ciphertext, BittensorVector.oneByte.ciphertext)
    }

    private static func publicKeyWithFirstCoefficientEqualToModulus() -> Data {
        let modulus = 3329
        var publicKey = BittensorVector.publicKey
        publicKey[0] = UInt8(modulus & 0xFF)
        publicKey[1] = (publicKey[1] & 0xF0) | UInt8(modulus >> 8)
        return publicKey
    }
}
