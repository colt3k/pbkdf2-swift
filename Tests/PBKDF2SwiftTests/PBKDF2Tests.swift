import Foundation
import Testing
@testable import PBKDF2Swift

private func hexToData(_ hex: String) -> Data {
    var data = Data(capacity: hex.count / 2)
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        data.append(UInt8(hex[index..<next], radix: 16)!)
        index = next
    }
    return data
}

/// Known PBKDF2-HMAC-SHA256 vectors. The 20-byte prefixes come from the
/// golang.org/x/crypto/pbkdf2 test suite; the 32/64-byte extensions and the
/// 1,000,000-iteration vector were cross-checked against Go (x/crypto
/// v0.54.0) and Python (hashlib/OpenSSL). Note: RFC 6070 only publishes
/// SHA-1 vectors, so it is not a source here.
struct KnownVectorTests {

    @Test("c=1")
    func oneIteration() throws {
        let key = try PBKDF2.deriveKey(
            password: "password",
            salt: Data("salt".utf8),
            iterations: 1,
            keyLength: 32
        )
        #expect(
            key == hexToData("120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
        )
    }

    @Test("c=2")
    func twoIterations() throws {
        let key = try PBKDF2.deriveKey(
            password: "password",
            salt: Data("salt".utf8),
            iterations: 2,
            keyLength: 32
        )
        #expect(
            key == hexToData("ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43")
        )
    }

    @Test("c=4096")
    func fourThousandNinetySixIterations() throws {
        let key = try PBKDF2.deriveKey(
            password: "password",
            salt: Data("salt".utf8),
            iterations: 4096,
            keyLength: 32
        )
        #expect(
            key == hexToData("c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
        )
    }

    @Test("c=1000000, 64-byte key")
    func oneMillionIterationsMultiBlock() throws {
        let key = try PBKDF2.deriveKey(
            password: "passwordPASSWORDpassword",
            salt: Data("saltSALTsaltSALTsaltSALTsaltSALTsalt".utf8),
            iterations: 1_000_000,
            keyLength: 64
        )
        #expect(
            key == hexToData(
                "e3ded20c896b588f06af403425f721662363a67908d035d2934af663c4d8a123"
                + "6dbc8b879ccb469ddb94195d1aee337867a27968970d1c9e06db79f79ba70598"
            )
        )
    }

    /// 25-byte key from the x/crypto test suite: truncation to a length that
    /// is not a multiple of the hash length.
    @Test("c=4096, 25-byte key")
    func twentyFiveByteKey() throws {
        let key = try PBKDF2.deriveKey(
            password: "passwordPASSWORDpassword",
            salt: Data("saltSALTsaltSALTsaltSALTsaltSALTsalt".utf8),
            iterations: 4096,
            keyLength: 25
        )
        #expect(
            key == hexToData("348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c")
        )
    }
}

struct GoCrossLanguageTests {

    /// Vector derived with golang.org/x/crypto/pbkdf2 v0.54.0 (the library
    /// 2fasdec uses): password "mysupersecretpassword&^%$123", base64 salt
    /// "qhebZTd7PVqGBCH0rTyl0w==", 10,000 iterations, 32-byte key.
    @Test("2fasdec-style DeriveKey")
    func twoFASConvenience() throws {
        let key = try PBKDF2.deriveKey(
            password: "mysupersecretpassword&^%$123",
            saltB64: "qhebZTd7PVqGBCH0rTyl0w=="
        )
        #expect(key.count == 32)
        #expect(
            key == hexToData("df74f1fb426d125d2533527c546a834c9c2de3a65657036eb05492aa96df8c8c")
        )
    }

    /// 64-byte key (two blocks), 4,096 iterations. The first 32 bytes also
    /// match the x/crypto SHA-256 c=4096 vector.
    @Test("multi-block key length")
    func multiBlock() throws {
        let key = try PBKDF2.deriveKey(
            password: "password",
            salt: Data("salt".utf8),
            iterations: 4096,
            keyLength: 64
        )
        #expect(
            key == hexToData(
                "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a"
                + "f7ad98c1b458ce3fd74ca35beba3cda7b8d1038d6a87071b918f837405f3fe77"
            )
        )
    }

    /// 48-byte key (1.5 blocks) exercises final-block truncation,
    /// 123,456 iterations.
    @Test("key length truncation")
    func truncation() throws {
        let key = try PBKDF2.deriveKey(
            password: "test",
            salt: Data("0123456789abcdef".utf8),
            iterations: 123_456,
            keyLength: 48
        )
        #expect(
            key == hexToData("7c502cf212a35253ca3675cedc0fd040cc8827d61f4253c50332d5e36bbe38ec"
                + "9d3661806114c0684501f22479305bc0")
        )
    }
}

struct ErrorTests {

    @Test("zero iterations rejected")
    func zeroIterations() {
        #expect(
            throws: PBKDF2Error.invalidIterations(0)
        ) {
            try PBKDF2.deriveKey(
                password: Data("password".utf8),
                salt: Data("salt".utf8),
                iterations: 0,
                keyLength: 32
            )
        }
    }

    @Test("negative iterations rejected")
    func negativeIterations() {
        #expect(
            throws: PBKDF2Error.invalidIterations(-5)
        ) {
            try PBKDF2.deriveKey(
                password: Data("password".utf8),
                salt: Data("salt".utf8),
                iterations: -5,
                keyLength: 32
            )
        }
    }

    @Test("zero key length rejected")
    func zeroKeyLength() {
        #expect(
            throws: PBKDF2Error.invalidKeyLength(0)
        ) {
            try PBKDF2.deriveKey(
                password: Data("password".utf8),
                salt: Data("salt".utf8),
                iterations: 1000,
                keyLength: 0
            )
        }
    }

    @Test("invalid base64 salt rejected")
    func invalidBase64Salt() {
        #expect(
            throws: PBKDF2Error.invalidBase64Salt
        ) {
            try PBKDF2.deriveKey(password: "password", saltB64: "not-valid-base64!!!")
        }
    }
}