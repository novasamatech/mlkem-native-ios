import MLKEMNative
import XCTest

final class BittensorVectorTests: XCTestCase {
    func testKeyPairFromSeedReproducesVectorKeys() throws {
        let keyPair = try MLKEMNative768.keyPair(seed: BittensorVector.keyPairSeed)

        XCTAssertEqual(keyPair.publicKey, BittensorVector.publicKey)
        XCTAssertEqual(keyPair.secretKey, BittensorVector.secretKey)
    }

    func testEncapsulateReproducesSignedExtrinsicCase() throws {
        let vector = BittensorVector.signedExtrinsicSized150

        let encapsulation = try MLKEMNative768.encapsulate(
            publicKey: BittensorVector.publicKey,
            randomness: vector.randomness
        )

        XCTAssertEqual(encapsulation.ciphertext, vector.ciphertext)
        XCTAssertEqual(encapsulation.sharedSecret, vector.sharedSecret)
    }

    func testEncapsulateReproducesOneByteCase() throws {
        let vector = BittensorVector.oneByte

        let encapsulation = try MLKEMNative768.encapsulate(
            publicKey: BittensorVector.publicKey,
            randomness: vector.randomness
        )

        XCTAssertEqual(encapsulation.ciphertext, vector.ciphertext)
        XCTAssertEqual(encapsulation.sharedSecret, vector.sharedSecret)
    }

    func testDecapsulateRecoversSignedExtrinsicSharedSecret() throws {
        let vector = BittensorVector.signedExtrinsicSized150

        let sharedSecret = try MLKEMNative768.decapsulate(
            ciphertext: vector.ciphertext,
            secretKey: BittensorVector.secretKey
        )

        XCTAssertEqual(sharedSecret, vector.sharedSecret)
    }

    func testDecapsulateRecoversOneByteSharedSecret() throws {
        let vector = BittensorVector.oneByte

        let sharedSecret = try MLKEMNative768.decapsulate(
            ciphertext: vector.ciphertext,
            secretKey: BittensorVector.secretKey
        )

        XCTAssertEqual(sharedSecret, vector.sharedSecret)
    }
}
