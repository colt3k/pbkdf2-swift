import CryptoKit
import Foundation

/// Errors thrown by `PBKDF2.deriveKey`.
public enum PBKDF2Error: Equatable, Error {
    case invalidIterations(Int)
    case invalidKeyLength(Int)
    case invalidBase64Salt
}

/// PBKDF2 key derivation using HMAC-SHA256 as the pseudo-random function,
/// as defined in RFC 2898 / PKCS #5 v2.0.
public enum PBKDF2 {

    /// Length of the SHA-256 digest in bytes.
    public static let hashLength = SHA256.byteCount

    /// Iteration count used by the 2FAS backup format.
    public static let iterations2FAS = 10_000

    /// Key length in bytes used by the 2FAS backup format.
    public static let keyLength2FAS = 32

    /// Derives a key of `keyLength` bytes using PBKDF2-HMAC-SHA256.
    ///
    /// - Parameters:
    ///   - password: The password material.
    ///   - salt: The salt.
    ///   - iterations: The iteration count; must be at least 1.
    ///   - keyLength: The derived key length in bytes; must be at least 1.
    public static func deriveKey(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        guard iterations >= 1 else {
            throw PBKDF2Error.invalidIterations(iterations)
        }
        guard keyLength >= 1 else {
            throw PBKDF2Error.invalidKeyLength(keyLength)
        }

        let blockCount = (keyLength + hashLength - 1) / hashLength
        var derivedKey = Data()
        derivedKey.reserveCapacity(keyLength)

        for blockIndex in 1...blockCount {
            var blockInput = salt
            blockInput.append(int32BigEndian(blockIndex))

            var previous = prf(password, blockInput)
            var block = previous
            if iterations > 1 {
                for _ in 2...iterations {
                    previous = prf(password, previous)
                    block = xor(block, previous)
                }
            }

            derivedKey.append(block)
        }

        return derivedKey.prefix(keyLength)
    }

    /// Derives a key using a UTF-8 string password.
    public static func deriveKey(
        password: String,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        try deriveKey(
            password: Data(password.utf8),
            salt: salt,
            iterations: iterations,
            keyLength: keyLength
        )
    }

    /// Derives the 2FAS backup key: PBKDF2-HMAC-SHA256 with 10,000 iterations
    /// and a 32-byte key, from a base64-encoded salt.
    public static func deriveKey(password: String, saltB64: String) throws -> Data {
        guard let salt = Data(base64Encoded: saltB64) else {
            throw PBKDF2Error.invalidBase64Salt
        }
        return try deriveKey(
            password: password,
            salt: salt,
            iterations: iterations2FAS,
            keyLength: keyLength2FAS
        )
    }

    private static func prf(_ key: Data, _ message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return Data(HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey))
    }

    private static func int32BigEndian(_ value: Int) -> Data {
        var bigEndian = UInt32(truncatingIfNeeded: value).bigEndian
        return withUnsafeBytes(of: &bigEndian) { Data($0) }
    }

    private static func xor(_ lhs: Data, _ rhs: Data) -> Data {
        var result = Data(capacity: lhs.count)
        for (left, right) in zip(lhs, rhs) {
            result.append(left ^ right)
        }
        return result
    }
}