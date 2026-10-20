# mlkem-native-ios

ML-KEM-768 (FIPS 203) for iOS and macOS as a Swift package, built from
[mlkem-native](https://github.com/pq-code-package/mlkem-native).

## Why

Nova Wallet submits Bittensor transactions through the MEV shield
(`MevShield.submit_encrypted`). The wallet encapsulates to the chain's
ML-KEM-768 key and encrypts the signed extrinsic with the resulting shared
secret, so the transaction stays private until it is included.

CryptoKit ships `MLKEM768` only from iOS 26, and its encapsulation takes no
caller randomness, so its ciphertexts can't be checked against fixed vectors.
This package works from iOS 16, exposes the derandomized encapsulation, and
reproduces the Bittensor SDK vector byte for byte.

## Provenance

| | |
|---|---|
| Upstream | [pq-code-package/mlkem-native](https://github.com/pq-code-package/mlkem-native) `v2.0.0` |
| Fork | [novasamatech/mlkem-native](https://github.com/novasamatech/mlkem-native) `v2.0.0`, unchanged |
| Commit | `d1b2fe782888bdb761a50336012923180be7f502` |
| Source | Fetched by `bindings/build.sh` at that commit into `bindings/build/mlkem-native` (git-ignored) |

The source is not a submodule, so resolving the package doesn't download
mlkem-native. `bindings/build.sh` fetches only the pinned commit, and stops if
the existing checkout is at another commit or has local changes.

## Layout

| Path | Contents |
|---|---|
| `Package.swift` | Product `MLKEMNative`; binary target `CMLKEMNative` |
| `Sources/` | Swift interface |
| `Tests/` | XCTest suite |
| `bindings/build.sh` | Fetches the pinned mlkem-native commit and rebuilds the xcframework |
| `bindings/include/` | Config file, umbrella header and module map |
| `bindings/xcframework/CMLKEMNative.xcframework` | Built static libraries and headers |
| `bindings/xcframework/LICENSE-mlkem-native` | Upstream licence, copied by the build |

## Build configuration

The library is upstream's single compilation unit `mlkem/mlkem_native.c`. It
is configured through `MLK_CONFIG_FILE`, which points at
`bindings/include/mlkem_native_ios_config.h`. That file changes four options
from upstream's default `mlkem_native_config.h`:

| Option | Value | Effect |
|---|---|---|
| `MLK_CONFIG_PARAMETER_SET` | `768` | ML-KEM-768 only |
| `MLK_CONFIG_NAMESPACE_PREFIX` | `NOVA_MLKEM768` | Every exported symbol starts with `NOVA_MLKEM768_` |
| `MLK_CONFIG_NO_RANDOMIZED_API` | set | Only `keypair_derand` and `enc_derand`, so the library needs no `randombytes()`; Swift supplies the randomness |
| `MLK_CONFIG_INTERNAL_API_QUALIFIER` | `static` | Internal functions stay private to the single compilation unit |

Everything else keeps the upstream default. No native backend is enabled and
`mlkem_native_asm.S` is not compiled, so every slice runs the same portable C
code. The default empty inline-asm compiler barriers (value barrier,
zeroization) stay on, as in upstream's default C build.

The object files are byte-identical to a build with upstream's default config
file and the four options passed as `-D` flags.

**One config for the library and for Swift.** The xcframework ships the same
config file next to an unmodified copy of upstream `mlkem_native.h`. The
umbrella header `CMLKEMNative.h` defines `MLK_CONFIG_FILE` and includes
`mlkem_native.h`. The library is compiled against that same header directory
with `-DMLK_CHECK_APIS`, so the compiler checks the shipped public declarations
against the implementation.

**Compiler flags.** Apple clang from Xcode, through `xcrun`:

```
-std=c99 -O3 -fomit-frame-pointer
-Wall -Wextra -Wpedantic -Werror -Werror=unused-result -Wmissing-prototypes
-Wshadow -Wpointer-arith -Wconversion -Wsign-conversion -Wno-long-long
-Wno-unknown-pragmas
-ffile-prefix-map=<bindings>=.
-DMLK_CONFIG_FILE="mlkem_native_ios_config.h" -DMLK_CHECK_APIS
-I <staged headers>
```

**Targets and slices:**

| Slice | Targets |
|---|---|
| `ios-arm64` | `arm64-apple-ios16.0` |
| `ios-arm64_x86_64-simulator` | `arm64-apple-ios16.0-simulator`, `x86_64-apple-ios16.0-simulator` |
| `macos-arm64_x86_64` | `arm64-apple-macos12.0`, `x86_64-apple-macos12.0` (for `swift test`) |

**Archiving.** Each slice is built with `libtool -static -D` and
`ZERO_AR_DATE=1`, merged with `lipo` and packaged with
`xcodebuild -create-xcframework`. The library list in the xcframework's
`Info.plist` is sorted so the file is stable. Headers sit in
`Headers/CMLKEMNative/` so the module map can't collide with other static
xcframeworks.

The build fails in any of these cases:
- a slice exports a symbol without the `NOVA_MLKEM768_` prefix;
- a slice is missing `keypair_derand`, `enc_derand`, `dec`, `check_pk` or `check_sk`;
- a slice exports the randomized `keypair` or `enc`;
- a slice references `randombytes`.

## Rebuild and verify

```sh
./bindings/build.sh
git status --porcelain bindings/xcframework
shasum -a 256 bindings/xcframework/CMLKEMNative.xcframework/*/libCMLKEMNative.a
```

`git status` prints nothing when the rebuilt files match the committed ones.
The libraries' hashes are:

| Slice | SHA-256 of `libCMLKEMNative.a` |
|---|---|
| `ios-arm64` | `2e2a652d246401b196dda2ddf272d57214ac1e03ef82c1ed46cf18c15bdd7ece` |
| `ios-arm64_x86_64-simulator` | `9f51f00b73fe81ca6a90dc588132b9fb4230c49561e9943ee49508b48ddfe00d` |
| `macos-arm64_x86_64` | `54b02604dcc9adea12e1114b549b6a0c604e0212ab6b7738a37c80edb4e95a36` |

These hashes come from Xcode 26.5 (17F42) with Apple clang 21.0.0
(clang-2100.1.1.101). Consecutive builds and builds from a different checkout
path give the same bytes for the whole xcframework. Another Xcode version can
produce different bytes; check those against the tests rather than the hashes.

## Installation

Swift Package Manager only:

```swift
.package(url: "https://github.com/novasamatech/mlkem-native-ios.git", exact: "<version>")
```

Then depend on the `MLKEMNative` product.

## Usage

```swift
import MLKEMNative

let encapsulation = try MLKEMNative768.encapsulate(publicKey: publicKey)
encapsulation.ciphertext
encapsulation.sharedSecret
```

| API | Notes |
|---|---|
| `MLKEMNative768.encapsulate(publicKey:)` | Draws 32 bytes from `SecRandomCopyBytes`; throws `randomnessUnavailable` if that fails |
| `MLKEMNative768.encapsulate(publicKey:randomness:)` | Deterministic. `randomness` must be fresh and secret in production; fixed values are for tests |
| `MLKEMNative768.keyPair(seed:)` | `(publicKey, secretKey)` from the 64-byte `d ‖ z` seed |
| `MLKEMNative768.decapsulate(ciphertext:secretKey:)` | A ciphertext from another key does not throw: implicit rejection returns an unrelated secret |

Lengths in bytes:

| Constant | Bytes |
|---|---|
| `publicKeyLength` | 1184 |
| `secretKeyLength` | 2400 |
| `ciphertextLength` | 1088 |
| `sharedSecretLength` | 32 |
| `randomnessLength` | 32 |
| `keyPairSeedLength` | 64 |

All values are `Data`. A `Data` slice with a non-zero start index works.

`MLKEMError` cases:

| Case | Cause |
|---|---|
| `invalidLength(input, expected:, actual:)` | An input of the wrong length; nothing reaches C |
| `randomnessUnavailable(OSStatus)` | `SecRandomCopyBytes` failed |
| `invalidPublicKey` | `MLK_ERR_INVALID_PK`: the FIPS 203 §7.2 modulus check failed |
| `invalidSecretKey` | `MLK_ERR_INVALID_SK`: the FIPS 203 §7.3 hash check failed |
| `libraryFailure(Int32)` | Any other non-zero status. It can't occur in this configuration |

The API is stateless with no shared mutable state, so it is safe to call from
any thread. The type is `MLKEMNative768` rather than `MLKEM768`, so a file can
import both this package and CryptoKit, which has its own `MLKEM768` from
iOS 26.

## Testing

```sh
swift test
xcodebuild test -scheme MLKEMNative -destination 'platform=iOS Simulator,id=<udid>'
```

- **`BittensorVectorTests`** use the vector produced by the Bittensor SDK's
  `mlkem` module (subtensor `6a972693`, ml-kem 0.2.2):
  - `keyPair(seed:)` reproduces `ek` and `dk`;
  - in both cases, `encapsulate(publicKey:randomness:)` reproduces `kem_ct` and `shared_secret` byte for byte;
  - `decapsulate` recovers `shared_secret`.
- **`MLKEMNative768Tests`** cover:
  - the length constants;
  - a public key with a coefficient equal to q = 3329, rejected by both encapsulate variants;
  - a secret key with a broken public-key hash;
  - implicit rejection of a tampered ciphertext;
  - every wrong-length input;
  - a random round trip;
  - fresh randomness per call;
  - `Data` slices.
- **`CryptoKitCrossCheckTests`** run on iOS 26 and macOS 26, and are skipped on
  earlier systems:
  - CryptoKit derives `ek` from the same seed;
  - CryptoKit decapsulates our ciphertexts to our shared secrets;
  - for a tampered ciphertext, CryptoKit's implicit-rejection secret equals ours;
  - we decapsulate a CryptoKit ciphertext to CryptoKit's shared secret.

Upstream's own test drivers were also run against the shipped
`macos-arm64_x86_64` library. They were compiled from the pinned commit's
`test/` sources with the same config file and passed:
- `test_mlkem`: the derandomized smoke vectors;
- `gen_KAT` against the ML-KEM-768 `kat-sha256` in `META.yml`;
- the ACVP client on the NIST `v1.1.0.43` ML-KEM-768 groups: keyGen 25, encapDecap 55, encapDecap-tr1 65.

## Licence

This package is MIT licensed (see `LICENSE`). mlkem-native is
`Apache-2.0 OR ISC OR MIT`. Its licence ships with the binary as
`bindings/xcframework/LICENSE-mlkem-native`.
