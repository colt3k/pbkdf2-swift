# pbkdf2-swift

A small Swift package that implements **PBKDF2** (Password-Based Key Derivation Function 2) using **HMAC-SHA256** as the pseudo-random function, as defined in [RFC 2898](https://www.rfc-editor.org/rfc/rfc2898) / PKCS #5 v2.0.

It relies only on Apple's first-party `CryptoKit` and `Foundation` — no third-party dependencies.

## Requirements

- Swift 6.0+
- macOS 13+ (the package's minimum platform)

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/colt3k/pbkdf2-swift.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "PBKDF2Swift", package: "pbkdf2-swift")
        ]
    )
]
```

## Usage

```swift
import PBKDF2Swift

// Generic PBKDF2-HMAC-SHA256
let key = try PBKDF2.deriveKey(
    password: "password",
    salt: Data("salt".utf8),
    iterations: 10_000,
    keyLength: 32
)

// Convenience: UTF-8 string password
let key2 = try PBKDF2.deriveKey(
    password: "password",
    salt: Data("salt".utf8),
    iterations: 10_000,
    keyLength: 32
)

// Convenience: 2FAS backup format (10,000 iterations, 32-byte key, base64 salt)
let backupKey = try PBKDF2.deriveKey(
    password: "mysupersecretpassword&^%$123",
    saltB64: "qhebZTd7PVqGBCH0rTyl0w=="
)
```

### API

| Symbol | Description |
| --- | --- |
| `PBKDF2.deriveKey(password:salt:iterations:keyLength:)` | Core derivation. `password` and `salt` are `Data`. |
| `PBKDF2.deriveKey(password:salt:iterations:keyLength:)` | Same, with a `String` password (encoded as UTF-8). |
| `PBKDF2.deriveKey(password:saltB64:)` | 2FAS backup format: 10,000 iterations, 32-byte key, base64-encoded salt. |
| `PBKDF2.hashLength` | Length of the SHA-256 digest (32 bytes). |
| `PBKDF2.iterations2FAS` | Iteration count used by the 2FAS backup format (10,000). |
| `PBKDF2.keyLength2FAS` | Key length used by the 2FAS backup format (32 bytes). |

### Errors

`PBKDF2.deriveKey` throws a `PBKDF2Error`:

| Case | Thrown when |
| --- | --- |
| `.invalidIterations(Int)` | `iterations` is less than 1. |
| `.invalidKeyLength(Int)` | `keyLength` is less than 1. |
| `.invalidBase64Salt` | The base64 salt cannot be decoded. |

## Building

```sh
swift build
```

## Running tests

The tests use [swift-testing](https://developer.apple.com/documentation/testing) and are validated against known PBKDF2-HMAC-SHA256 vectors, cross-checked with Go and Python/OpenSSL).

Use the provided helper script:

```sh
./run_tests.sh                 # release build, all tests
./run_tests.sh -c debug        # debug build
./run_tests.sh -f 'oneIteration'          # run a single test
./run_tests.sh -f 'multiBlock|truncation' # run a set of tests
./run_tests.sh -l              # list available tests
```

You can also run them directly with SwiftPM:

```sh
swift test
```

## Project layout

```
Package.swift
Sources/PBKDF2Swift/PBKDF2.swift   # The implementation
Tests/PBKDF2SwiftTests/PBKDF2Tests.swift  # swift-testing test suite
run_tests.sh                       # Test runner helper
```

## License

See the repository for licensing details.
